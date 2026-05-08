-- ============================================================
-- SkillCoins — Complete Supabase Database Setup
-- Run this ENTIRE file in Supabase SQL Editor (supabase.com)
-- Project → SQL Editor → New Query → Paste → Run
-- ============================================================

-- ── 1. USERS TABLE ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id                    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username              TEXT UNIQUE NOT NULL,
  avatar_url            TEXT,
  total_coins           INTEGER NOT NULL DEFAULT 0 CHECK (total_coins >= 0),
  lifetime_coins_earned INTEGER NOT NULL DEFAULT 0,
  referral_code         TEXT UNIQUE NOT NULL DEFAULT upper(substring(gen_random_uuid()::text, 1, 8)),
  referred_by           UUID REFERENCES public.users(id),
  login_streak          INTEGER NOT NULL DEFAULT 0,
  last_login_date       DATE,
  account_level         INTEGER NOT NULL DEFAULT 1 CHECK (account_level BETWEEN 1 AND 10),
  is_premium            BOOLEAN NOT NULL DEFAULT false,
  is_banned             BOOLEAN NOT NULL DEFAULT false,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON public.users FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.users FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Public leaderboard view"
  ON public.users FOR SELECT
  USING (true);  -- usernames/avatars visible for leaderboard

-- ── 2. GAME SESSIONS TABLE ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.game_sessions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  game_type        TEXT NOT NULL CHECK (game_type IN ('typing','math','reaction','memory','trivia','word')),
  score            NUMERIC NOT NULL,
  coins_earned     INTEGER NOT NULL DEFAULT 0 CHECK (coins_earned >= 0),
  duration_seconds INTEGER NOT NULL CHECK (duration_seconds > 0),
  ip_address       TEXT, -- hashed before storage
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.game_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own sessions"
  ON public.game_sessions FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sessions"
  ON public.game_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Index for fraud detection queries
CREATE INDEX idx_sessions_user_time ON public.game_sessions(user_id, created_at DESC);
CREATE INDEX idx_sessions_ip       ON public.game_sessions(ip_address, created_at DESC);

-- ── 3. COIN LEDGER TABLE ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.coin_ledger (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  amount        INTEGER NOT NULL,  -- positive = earn, negative = spend
  type          TEXT NOT NULL CHECK (type IN ('game_earn','bonus','referral','redemption','premium','admin_adjust')),
  reference_id  UUID,  -- FK to game_sessions or redemption_requests
  balance_after INTEGER NOT NULL CHECK (balance_after >= 0),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.coin_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own ledger"
  ON public.coin_ledger FOR SELECT USING (auth.uid() = user_id);

CREATE INDEX idx_ledger_user ON public.coin_ledger(user_id, created_at DESC);

-- ── 4. LEADERBOARDS TABLE ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.leaderboards (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  game_type   TEXT NOT NULL,
  score       NUMERIC NOT NULL,
  period      TEXT NOT NULL CHECK (period IN ('daily','weekly','alltime')),
  period_date DATE NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, game_type, period, period_date)
);

ALTER TABLE public.leaderboards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Leaderboard is public read"
  ON public.leaderboards FOR SELECT USING (true);

CREATE INDEX idx_lb_game_period ON public.leaderboards(game_type, period, period_date, score DESC);

-- ── 5. REDEMPTION REQUESTS TABLE ────────────────────────────
CREATE TABLE IF NOT EXISTS public.redemption_requests (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  coins_spent    INTEGER NOT NULL CHECK (coins_spent > 0),
  reward_type    TEXT NOT NULL CHECK (reward_type IN ('upi','amazon_gc','recharge')),
  reward_value   NUMERIC NOT NULL,
  payout_details JSONB NOT NULL,  -- encrypt UPI ID before storing
  status         TEXT NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending','approved','paid','rejected','fraud_hold')),
  admin_note     TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at   TIMESTAMPTZ
);

ALTER TABLE public.redemption_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own redemptions"
  ON public.redemption_requests FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create redemption requests"
  ON public.redemption_requests FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ── 6. FRAUD FLAGS TABLE ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.fraud_flags (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  flag_type  TEXT NOT NULL CHECK (flag_type IN ('ip_duplicate','speed_anomaly','session_frequency','referral_abuse','score_anomaly')),
  details    JSONB NOT NULL DEFAULT '{}',
  resolved   BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.fraud_flags ENABLE ROW LEVEL SECURITY;
-- Admin only — no user policies (service role key accesses this)

-- ── 7. TRIGGER: Auto-create user profile on signup ──────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, username, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data->>'username',
      split_part(NEW.email, '@', 1) || '_' || floor(random() * 9000 + 1000)::text
    ),
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ── 8. FUNCTION: Award coins (server-side safe) ─────────────
CREATE OR REPLACE FUNCTION public.award_coins(
  p_user_id    UUID,
  p_amount     INTEGER,
  p_type       TEXT,
  p_ref_id     UUID DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  v_new_balance INTEGER;
BEGIN
  -- Update user balance
  UPDATE public.users
  SET total_coins           = total_coins + p_amount,
      lifetime_coins_earned = lifetime_coins_earned + GREATEST(p_amount, 0)
  WHERE id = p_user_id AND NOT is_banned
  RETURNING total_coins INTO v_new_balance;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found or banned';
  END IF;

  -- Write ledger entry
  INSERT INTO public.coin_ledger (user_id, amount, type, reference_id, balance_after)
  VALUES (p_user_id, p_amount, p_type, p_ref_id, v_new_balance);

  RETURN v_new_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 9. FUNCTION: Update login streak ────────────────────────
CREATE OR REPLACE FUNCTION public.update_login_streak(p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_last_date DATE;
  v_streak    INTEGER;
  v_today     DATE := CURRENT_DATE;
  v_bonus     INTEGER := 0;
BEGIN
  SELECT last_login_date, login_streak INTO v_last_date, v_streak
  FROM public.users WHERE id = p_user_id;

  -- Same day — no change
  IF v_last_date = v_today THEN RETURN v_streak; END IF;

  -- Consecutive day — increment streak
  IF v_last_date = v_today - INTERVAL '1 day' THEN
    v_streak := v_streak + 1;
  ELSE
    v_streak := 1;  -- reset
  END IF;

  UPDATE public.users
  SET login_streak = v_streak, last_login_date = v_today
  WHERE id = p_user_id;

  -- Streak bonuses
  IF    v_streak = 7  THEN v_bonus := 50;
  ELSIF v_streak = 30 THEN v_bonus := 200;
  ELSIF v_streak % 5 = 0 THEN v_bonus := 20;
  ELSE v_bonus := 5;
  END IF;

  -- Award bonus coins
  PERFORM public.award_coins(p_user_id, v_bonus, 'bonus');

  RETURN v_streak;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── DONE ────────────────────────────────────────────────────
-- All tables, policies, triggers and functions are ready.
-- Next: Set up Google OAuth in Supabase Auth → Providers → Google

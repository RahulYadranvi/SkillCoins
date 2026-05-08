# SkillCoins — Week 1 Setup Guide
Follow every step in order. Do not skip.

---

## STEP 1: Install Dependencies
```bash
cd skillcoins
npm install
```

---

## STEP 2: Set Up Supabase (Free)
1. Go to **supabase.com** → Sign up → Create new project
2. Name it `skillcoins`, pick a strong password, choose region: **Southeast Asia (Singapore)**
3. Wait 2 minutes for project to provision
4. Go to **Settings → API**
5. Copy:
   - `Project URL` → paste into `.env.local` as `NEXT_PUBLIC_SUPABASE_URL`
   - `anon public key` → paste as `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `service_role key` → paste as `SUPABASE_SERVICE_ROLE_KEY` (⚠️ never expose this publicly)

6. Go to **SQL Editor → New Query**
7. Paste the ENTIRE contents of `supabase_setup.sql`
8. Click **Run** — you should see "Success" for all statements

---

## STEP 3: Enable Google OAuth in Supabase
1. Supabase Dashboard → **Authentication → Providers → Google**
2. Toggle Google ON
3. You need a Google OAuth Client ID and Secret:
   - Go to console.cloud.google.com
   - New project → APIs & Services → Credentials → Create OAuth 2.0 Client
   - Application type: Web application
   - Authorized redirect URIs: `https://[your-supabase-ref].supabase.co/auth/v1/callback`
   - Copy Client ID + Secret into Supabase Google provider settings
4. Save

---

## STEP 4: Set Up Upstash Redis (Rate Limiting)
1. Go to **upstash.com** → Sign up → Create Database
2. Type: **Redis**, Region: **Asia Pacific (Mumbai)**, Plan: Free
3. Copy **REST URL** and **REST Token** into `.env.local`

---

## STEP 5: Set Up Resend (Email)
1. Go to **resend.com** → Sign up → API Keys → Create Key
2. Paste into `.env.local` as `RESEND_API_KEY`

---

## STEP 6: Run Locally
```bash
npm run dev
```
Open http://localhost:3000 — you should see the SkillCoins homepage.

---

## STEP 7: Deploy to Vercel
```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel

# Follow prompts — link to your GitHub repo
# Add all .env.local variables in Vercel Dashboard → Project → Settings → Environment Variables
```

---

## STEP 8: Buy Domain (only real cost)
1. Go to **namecheap.com**
2. Search for your domain name (e.g. `skillcoins.in` — ₹700/year)
3. Buy it
4. In Vercel Dashboard → Project → Settings → Domains → Add domain
5. Follow Namecheap DNS setup instructions

---

## WEEK 1 DONE ✓
Your site is live with:
- Auth (Google + Email)
- Full database schema
- Home page
- Legal pages (required for AdSense)
- SEO metadata

**Next: Week 2 — Build the Typing Speed Test game + coin earning system**

---

## Files In This Project
```
skillcoins/
├── app/
│   ├── (marketing)/        ← Public pages with Navbar + Footer
│   │   ├── page.tsx        ← Homepage
│   │   ├── privacy-policy/ ← Required for AdSense
│   │   ├── terms/          ← Required for AdSense
│   │   ├── about/          ← Required for AdSense
│   │   ├── contact/        ← Required for AdSense
│   │   └── how-it-works/   ← SEO + user education (build Week 2)
│   ├── auth/
│   │   ├── login/          ← Login page
│   │   ├── signup/         ← Signup page
│   │   └── callback/       ← OAuth callback handler
│   ├── games/              ← Game pages (build Week 2-4)
│   ├── dashboard/          ← User dashboard (build Week 2)
│   ├── leaderboard/        ← Leaderboard (build Week 3)
│   └── redeem/             ← Redemption page (build Week 4)
├── components/
│   ├── layout/             ← Navbar, Footer
│   ├── ui/                 ← Reusable UI components
│   └── games/              ← Game components (build Week 2-4)
├── lib/
│   ├── supabase/           ← client.ts, server.ts, middleware.ts
│   └── utils.ts            ← Helper functions
├── types/index.ts          ← All TypeScript types + game configs
├── middleware.ts            ← Route protection
├── supabase_setup.sql      ← Run in Supabase SQL Editor
├── .env.local              ← Your secrets (never commit this)
└── SETUP_GUIDE.md          ← This file
```

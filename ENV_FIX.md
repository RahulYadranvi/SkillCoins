# Fix for "No API key found" Error

The error happens because Next.js isn't loading your .env.local properly.

## Steps to fix:

1. Open `.env.local` in VS Code
2. Make sure it looks EXACTLY like this (no quotes around values, no extra spaces):

```
NEXT_PUBLIC_SUPABASE_URL=https://xyzabc.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxxxx
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxxxx
NEXT_PUBLIC_APP_URL=http://localhost:3000
NEXT_PUBLIC_APP_NAME=SkillCoins
```

3. STOP the dev server (Ctrl+C in terminal)
4. Run: npm run dev again
5. Try login again

## Common mistakes:
- Quotes around values: WRONG → NEXT_PUBLIC_SUPABASE_URL="https://..."
- Extra spaces: WRONG → NEXT_PUBLIC_SUPABASE_URL = https://...
- Copy-pasting with line breaks inside the value

## If Google OAuth gives "No API key":
Your Supabase Google OAuth setup is incomplete.
Go to: Supabase Dashboard → Authentication → Providers → Google
Make sure both Client ID and Client Secret are filled in and SAVED.

# IMPORTANT: Rename the "marketing" folder

In the ZIP you downloaded, there is a folder called "marketing" inside "app/".

You need to rename it to "(marketing)" — with parentheses.

In VS Code:
1. Right-click the "marketing" folder inside "app/"
2. Click "Rename"
3. Type: (marketing)
4. Press Enter

This is a Next.js route group — the parentheses tell Next.js NOT to include 
"marketing" in the URL. Without this rename, your pages won't be found at the 
right URLs.

After renaming, your app/ folder should look like:
app/
  (marketing)/      ← with parentheses
    page.tsx        ← homepage at /
    games/          ← at /games
    how-it-works/   ← at /how-it-works
    leaderboard/    ← at /leaderboard
    privacy-policy/ ← at /privacy-policy
    terms/          ← at /terms
    about/          ← at /about
    contact/        ← at /contact
  auth/
    login/
    signup/
    callback/
  dashboard/

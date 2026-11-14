# Daily Shop Ledger (free-tier deployment)

A mobile-friendly daily balance and approval website based on the sheet screenshots. It captures SBI, MP Online, Fino and Cash balances, calculates the total, stores transaction notes, and supports owner review / correction / approval.

## Free deployment stack
- GitHub Pages: static website hosting (free).
- Supabase Free: authentication and database (free within current plan limits).
- No custom domain required; use the free `*.github.io` address.

Free tiers have quotas and can change. Supabase Free projects may pause after inactivity; check the current plan terms before relying on it for business-critical records. Keep periodic exports/backups of your data.

## 1. Create Supabase project
1. Create a free project at https://supabase.com/.
2. In **SQL Editor**, paste and run all of `schema.sql`.
3. In **Project Settings → API**, copy the Project URL and `anon` / publishable key.
4. Put those values in `config.js` as `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
5. In **Authentication → Providers → Email**, keep email/password enabled. Turn off public sign-ups after creating the accounts you need.
6. Create your owner and worker users in **Authentication → Users → Add user**.
7. In **Table Editor → profiles**, add one row for each user. Set `id` to the matching Auth user UUID, `display_name` to their name, and `role` to `owner` for you or `worker` for staff. Do not share the owner login.

The anon key is intended to be public in a browser app; database access is restricted by Row Level Security. Never put a Supabase `service_role` key in this website.

## 2. Deploy free on GitHub Pages
1. Create a GitHub repository, e.g. `daily-shop-ledger`.
2. Upload `index.html`, `app.js`, and `config.js` (do not upload secrets other than the public anon key; it is designed to be public). Keep `schema.sql` and this README for your records.
3. In the repository, open **Settings → Pages**.
4. Choose **Deploy from a branch**, select `main` and `/ (root)`, then Save.
5. Wait for GitHub Pages to publish. Your URL will look like `https://YOUR-USERNAME.github.io/daily-shop-ledger/`.

## 3. How it works
- Worker signs in, enters account balances and optional transaction details, then submits.
- Owner sees submitted entries and can approve (locks the entry) or request correction with a remark.
- Worker sees the remark and can edit/resubmit the same entry.
- Owner can reopen an approved entry for correction.
- `entry_history` records status transitions.

## Important notes before live use
- The UI is a starter implementation, not an audited accounting product. Test it with sample data and compare totals against your current sheet before relying on it.
- The total is the sum of SBI + MP Online + Fino + Cash. Confirm this matches your accounting method.
- The screenshots show transaction text/details but do not fully establish the exact meaning of every transaction field. The website stores transaction details as notes rather than attempting to parse individual transfers.
- Test worker and owner accounts separately. Verify that workers cannot see another worker's entries and cannot edit approved entries.
- Keep a regular CSV export from Supabase as a backup. Free plans do not mean unlimited storage or guaranteed uptime.
- The website requires internet access to sign in and save; offline entry/sync is not included in this first version.

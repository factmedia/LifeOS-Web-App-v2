# LifeOS Web App v2 — Cloud & Team Edition

Responsive task manager with dashboard, list, Kanban, monthly calendar, 14 category labels from the supplied build, task recurrence, priority, activity history, recycle bin, JSON/CSV/Excel import/export, and Supabase cloud workspaces.

## Included account and collaboration features

- Email + password account registration and login (Supabase Auth)
- Password reset email and password update
- Persistent auth session across devices (sign in with the same account on each device)
- Private personal workspace (one per account; cannot be joined by invite code)
- Shared workspace creation and invite-code joining
- Workspace switching for all workspaces the signed-in user belongs to
- Owner / Admin / Member roles; Owner/Admin can promote members to Admin, demote Admin to Member, or remove non-owner members
- Cloud save after task changes and Supabase Realtime updates for other members/devices
- Logout

## 1. Deploy the website

Upload the contents of this folder to the root of your GitHub Pages repository. `index.html` must be at repository root. Commit changes and wait for GitHub Pages to publish.

## 2. Configure Supabase (required)

1. Open your Supabase project → SQL Editor.
2. Run the complete `supabase-setup.sql` included in this ZIP. It is written to be re-runnable against the earlier LifeOS schema and adds the personal-workspace and role-management functions.
3. In Supabase → Authentication → URL Configuration, set **Site URL** to your exact GitHub Pages URL, e.g. `https://YOUR-USERNAME.github.io/LifeOS-Web-App-v2/`.
4. Add that exact URL to **Redirect URLs**. If your app uses a separate reset route, add that exact route too; this build uses the current page URL.
5. In Authentication → Providers → Email, enable Email provider. For email confirmation, configure SMTP for reliable delivery; Supabase's default mail service is rate-limited. For testing, you may disable Confirm email, but enable it for real use.
6. In LifeOS → Backup & Settings, enter Project URL and the **publishable** key (or legacy anon key). Never paste a `service_role` or secret key into the browser app.

## 3. First-time use

1. On your main device, open the published site → Backup & Settings.
2. Enter Supabase Project URL and publishable/anon key, your email, and a password of at least 8 characters.
3. Choose **Create account**. If email confirmation is enabled, open the confirmation email on the same device/browser, then return and log in.
4. Choose **Create private workspace** for your personal tasks. This workspace is private to your account and is not joinable by invite code.
5. To collaborate, enter a name and choose **Create shared workspace**. Share its invite code only with intended collaborators.
6. On each other device, open the same website, enter the same Supabase URL/key, and sign in using the same account to see your own workspace. For a teammate, they create their own account and join the shared workspace with the invite code.
7. Use **Switch workspace** to move between your personal and shared workspaces.

## 4. Roles

- **Owner:** creator; cannot be demoted or removed by the UI.
- **Admin:** can promote/demote non-owner members and remove non-owner members.
- **Member:** can use and edit workspace tasks, but cannot manage membership/roles.

Role and membership changes are performed by protected Supabase RPC functions. Do not expose a service-role key.

## 5. Existing data and important notes

- Existing cloud workspace data is not deleted by this update. After running the SQL, log in and use **Switch workspace** to access workspaces associated with your account.
- Creating a new personal workspace starts it empty; it does not automatically copy tasks from an existing shared workspace. Export a JSON backup first if you want to copy/merge tasks manually.
- Local browser data is not automatically uploaded until a workspace is selected and cloud sync is active. Export a backup before changing accounts/workspaces.
- Automatic cloud writes are debounced briefly after changes; Realtime sends other members' updates to connected sessions. Use **Sync now** after login if needed.
- Anyone with a shared-workspace invite code can join that shared workspace. Rotate/restrict invite handling outside the app if the code is exposed; never share personal workspace codes.
- GitHub Pages is static hosting; Supabase provides auth and database services.

## Troubleshooting

- `Invalid login credentials`: create the account first or reset its password.
- Confirmation/reset email not received: check spam, verify the email provider settings and SMTP/rate limits in Supabase.
- `function ... does not exist`: rerun the complete `supabase-setup.sql` in SQL Editor.
- `permission denied` / RLS errors: confirm the signed-in user is a workspace member and the full SQL setup completed successfully.
- Tasks not visible on another device: use the same login for personal data; for team data, each teammate must sign in and join the same shared workspace.

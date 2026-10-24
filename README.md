# LifeOS — Personal Task Manager

Responsive, Light Minimal task manager with local-first storage and optional Supabase cloud sync/shared workspaces.

## Included
- 14 categories, including **Family Tasks** and **Future Tasks**
- Create, edit, complete/reopen, and soft-delete tasks
- Inbox, List, Kanban drag-and-drop, and monthly calendar views
- Status, priority, due date, estimate, notes, tags, recurring tasks
- Completion records and activity history
- Recycle Bin with restore and permanent deletion
- JSON backup/import, CSV import/export, Excel `.xlsx` import/export, and an Excel import template
- Optional Supabase email magic-link login, persistent cloud database, shared workspaces and invite codes
- Local browser copy remains available if cloud is not configured

## Run / host
Open `index.html` in a modern browser, or host the folder on GitHub Pages (Settings → Pages → deploy from `main` / root). External Supabase and SheetJS libraries are loaded from CDNs, so internet is needed for those features.

## Enable permanent cross-device cloud storage (free-tier setup)
GitHub Pages hosts the frontend; it does **not** store task data by itself. Configure Supabase as the database:

1. Create a Supabase project at https://supabase.com/ and open **SQL Editor**.
2. Run the full contents of `supabase-setup.sql`.
3. In Supabase **Project Settings → API**, copy the Project URL and the **anon/publishable** key. Never paste a service-role/secret key into this web app.
4. In Supabase **Authentication → URL Configuration**, add your deployed GitHub Pages URL to the allowed Redirect URLs. If testing locally, allow the local URL you use as well.
5. Open LifeOS → **Cloud, Import & Settings**. Enter Project URL, anon/publishable key and your email, then click **Save config & sign in**.
6. Open the emailed magic link. Return to LifeOS. Create a workspace; the invite code will appear in the status area and input. Share that code only with people you want to access the tasks.
7. Each collaborator opens the same hosted app, enters the same Supabase URL/key, signs in with their own email, and joins using the invite code.

Members who join a workspace can read and edit its shared tasks, Recycle Bin and activity history. Use a separate workspace for private tasks. Invite codes act like access credentials—share carefully. If a code leaks, create a new workspace and move the work rather than treating the old code as private.

## Data and sync notes
- Local browser storage is retained as a convenience/offline copy, but clearing browser data can remove that local copy.
- Cloud data persists in your Supabase database under your project and is shared across devices/workspace members. A free hosting/database provider can change its quotas, inactivity rules or pricing; check the provider's current terms and export regular backups.
- Cloud saves are automatic after changes, with a manual **Sync now** option. Changes from other members update live while the connection is active. For simultaneous edits to the exact same task, the most recent workspace snapshot may win; export backups for important data.
- JSON import restores a LifeOS backup. CSV/XLSX imports look for a `title` or `task` column and can map `category`, `status`, `priority`, `dueDate`, `estimate`, `recurrence`, `tags`, and `notes`. The importer offers merge or replace.
- Excel export creates `Tasks`, `Recycle Bin`, and `History` sheets. The Excel library is loaded from a CDN.

## Excel column template
Required: `title` (or `task`). Optional: `category`, `status`, `priority`, `dueDate` (YYYY-MM-DD recommended), `estimate`, `recurrence`, `tags`, `notes`.

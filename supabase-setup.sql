-- LifeOS cloud database setup for Supabase (run once in Supabase Dashboard > SQL Editor)
-- This schema supports private workspaces shared only with users who join using an invite code.

create extension if not exists pgcrypto;

create table if not exists public.lifeos_workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'LifeOS Workspace',
  invite_code text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)),
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.lifeos_workspace_members (
  workspace_id uuid not null references public.lifeos_workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  joined_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

create table if not exists public.lifeos_workspace_data (
  workspace_id uuid primary key references public.lifeos_workspaces(id) on delete cascade,
  payload jsonb not null default '{"tasks":[],"trash":[],"history":[],"month":null,"version":2}'::jsonb,
  updated_at timestamptz not null default now()
);

create or replace function public.lifeos_is_member(target_workspace uuid)
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.lifeos_workspace_members m where m.workspace_id = target_workspace and m.user_id = auth.uid()); $$;

alter table public.lifeos_workspaces enable row level security;
alter table public.lifeos_workspace_members enable row level security;
alter table public.lifeos_workspace_data enable row level security;

drop policy if exists "Members can view their workspaces" on public.lifeos_workspaces;
create policy "Members can view their workspaces" on public.lifeos_workspaces for select to authenticated using (public.lifeos_is_member(id));

drop policy if exists "Members can view workspace membership" on public.lifeos_workspace_members;
create policy "Members can view workspace membership" on public.lifeos_workspace_members for select to authenticated using (public.lifeos_is_member(workspace_id));

drop policy if exists "Members can read workspace data" on public.lifeos_workspace_data;
create policy "Members can read workspace data" on public.lifeos_workspace_data for select to authenticated using (public.lifeos_is_member(workspace_id));
drop policy if exists "Members can create workspace data" on public.lifeos_workspace_data;
create policy "Members can create workspace data" on public.lifeos_workspace_data for insert to authenticated with check (public.lifeos_is_member(workspace_id));
drop policy if exists "Members can update workspace data" on public.lifeos_workspace_data;
create policy "Members can update workspace data" on public.lifeos_workspace_data for update to authenticated using (public.lifeos_is_member(workspace_id)) with check (public.lifeos_is_member(workspace_id));

create or replace function public.lifeos_create_workspace(workspace_name text)
returns table(workspace_id uuid, invite_code text)
language plpgsql security definer set search_path = public
as $$
declare new_workspace public.lifeos_workspaces%rowtype;
begin
  if auth.uid() is null then raise exception 'Please sign in first'; end if;
  insert into public.lifeos_workspaces(name, owner_id) values (coalesce(nullif(trim(workspace_name), ''), 'My LifeOS Workspace'), auth.uid()) returning * into new_workspace;
  insert into public.lifeos_workspace_members(workspace_id, user_id, role) values (new_workspace.id, auth.uid(), 'owner');
  insert into public.lifeos_workspace_data(workspace_id) values (new_workspace.id);
  return query select new_workspace.id, new_workspace.invite_code;
end; $$;

create or replace function public.lifeos_join_workspace(invite_code_input text)
returns table(workspace_id uuid, invite_code text)
language plpgsql security definer set search_path = public
as $$
declare found_workspace public.lifeos_workspaces%rowtype;
begin
  if auth.uid() is null then raise exception 'Please sign in first'; end if;
  select * into found_workspace from public.lifeos_workspaces w where upper(w.invite_code) = upper(trim(invite_code_input)) limit 1;
  if found_workspace.id is null then raise exception 'Invite code not found'; end if;
  insert into public.lifeos_workspace_members(workspace_id, user_id, role) values (found_workspace.id, auth.uid(), 'member') on conflict do nothing;
  return query select found_workspace.id, found_workspace.invite_code;
end; $$;

revoke all on function public.lifeos_create_workspace(text) from public;
grant execute on function public.lifeos_create_workspace(text) to authenticated;
revoke all on function public.lifeos_join_workspace(text) from public;
grant execute on function public.lifeos_join_workspace(text) to authenticated;
revoke all on function public.lifeos_is_member(uuid) from public;
grant execute on function public.lifeos_is_member(uuid) to authenticated;

-- Optional: enable live updates. If this errors because the table is already in the publication, ignore it.
alter publication supabase_realtime add table public.lifeos_workspace_data;

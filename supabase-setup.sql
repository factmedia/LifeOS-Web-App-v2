-- LifeOS v2 cloud/auth/workspaces setup. Safe to run on an existing LifeOS schema.
-- Run in Supabase Dashboard > SQL Editor as project owner.
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
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (workspace_id,user_id)
);
create table if not exists public.lifeos_workspace_data (
  workspace_id uuid primary key references public.lifeos_workspaces(id) on delete cascade,
  payload jsonb not null default '{"tasks":[],"trash":[],"history":[],"month":null,"version":2}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Upgrade old role constraint (owner/member) to owner/admin/member.
alter table public.lifeos_workspace_members drop constraint if exists lifeos_workspace_members_role_check;
alter table public.lifeos_workspace_members add constraint lifeos_workspace_members_role_check check (role in ('owner','admin','member'));
alter table public.lifeos_workspaces add column if not exists is_personal boolean not null default false;

create or replace function public.lifeos_is_member(target_workspace uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.lifeos_workspace_members m where m.workspace_id=target_workspace and m.user_id=auth.uid()); $$;
create or replace function public.lifeos_is_admin(target_workspace uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.lifeos_workspace_members m where m.workspace_id=target_workspace and m.user_id=auth.uid() and m.role in ('owner','admin')); $$;

alter table public.lifeos_workspaces enable row level security;
alter table public.lifeos_workspace_members enable row level security;
alter table public.lifeos_workspace_data enable row level security;
drop policy if exists "Members can view their workspaces" on public.lifeos_workspaces;
create policy "Members can view their workspaces" on public.lifeos_workspaces for select to authenticated using(public.lifeos_is_member(id));
drop policy if exists "Members can view workspace membership" on public.lifeos_workspace_members;
create policy "Members can view workspace membership" on public.lifeos_workspace_members for select to authenticated using(public.lifeos_is_member(workspace_id));
drop policy if exists "Members can read workspace data" on public.lifeos_workspace_data;
create policy "Members can read workspace data" on public.lifeos_workspace_data for select to authenticated using(public.lifeos_is_member(workspace_id));
drop policy if exists "Members can create workspace data" on public.lifeos_workspace_data;
create policy "Members can create workspace data" on public.lifeos_workspace_data for insert to authenticated with check(public.lifeos_is_member(workspace_id));
drop policy if exists "Members can update workspace data" on public.lifeos_workspace_data;
create policy "Members can update workspace data" on public.lifeos_workspace_data for update to authenticated using(public.lifeos_is_member(workspace_id)) with check(public.lifeos_is_member(workspace_id));

create or replace function public.lifeos_create_workspace(workspace_name text)
returns table(workspace_id uuid,invite_code text) language plpgsql security definer set search_path=public
as $$ declare w public.lifeos_workspaces%rowtype; begin
 if auth.uid() is null then raise exception 'Please sign in first'; end if;
 insert into public.lifeos_workspaces(name,owner_id,is_personal) values(coalesce(nullif(trim(workspace_name),''),'My LifeOS Team'),auth.uid(),false) returning * into w;
 insert into public.lifeos_workspace_members(workspace_id,user_id,role) values(w.id,auth.uid(),'owner');
 insert into public.lifeos_workspace_data(workspace_id) values(w.id);
 return query select w.id,w.invite_code;
end $$;

create or replace function public.lifeos_create_personal_workspace(workspace_name text default 'My Private LifeOS')
returns table(workspace_id uuid,invite_code text) language plpgsql security definer set search_path=public
as $$ declare w public.lifeos_workspaces%rowtype; begin
 if auth.uid() is null then raise exception 'Please sign in first'; end if;
 select * into w from public.lifeos_workspaces where owner_id=auth.uid() and is_personal=true order by created_at limit 1;
 if w.id is null then
  insert into public.lifeos_workspaces(name,owner_id,is_personal) values(coalesce(nullif(trim(workspace_name),''),'My Private LifeOS'),auth.uid(),true) returning * into w;
  insert into public.lifeos_workspace_members(workspace_id,user_id,role) values(w.id,auth.uid(),'owner');
  insert into public.lifeos_workspace_data(workspace_id) values(w.id);
 end if;
 return query select w.id,w.invite_code;
end $$;

create or replace function public.lifeos_join_workspace(invite_code_input text)
returns table(workspace_id uuid,invite_code text) language plpgsql security definer set search_path=public
as $$ declare w public.lifeos_workspaces%rowtype; begin
 if auth.uid() is null then raise exception 'Please sign in first'; end if;
 select * into w from public.lifeos_workspaces where upper(invite_code)=upper(trim(invite_code_input)) and is_personal=false limit 1;
 if w.id is null then raise exception 'Invite code not found or this is a private personal workspace'; end if;
 insert into public.lifeos_workspace_members(workspace_id,user_id,role) values(w.id,auth.uid(),'member') on conflict do nothing;
 return query select w.id,w.invite_code;
end $$;

create or replace function public.lifeos_my_workspaces()
returns table(workspace_id uuid,name text,role text,is_personal boolean,invite_code text) language sql security definer set search_path=public
as $$ select w.id,w.name,m.role,w.is_personal,w.invite_code from public.lifeos_workspaces w join public.lifeos_workspace_members m on m.workspace_id=w.id where m.user_id=auth.uid() order by w.is_personal desc,w.created_at; $$;

create or replace function public.lifeos_list_members(target_workspace uuid)
returns table(user_id uuid,email text,role text,joined_at timestamptz) language plpgsql security definer set search_path=public,auth
as $$ begin
 if not public.lifeos_is_member(target_workspace) then raise exception 'Not a workspace member'; end if;
 return query select m.user_id,u.email::text,m.role,m.joined_at from public.lifeos_workspace_members m join auth.users u on u.id=m.user_id where m.workspace_id=target_workspace order by m.joined_at;
end $$;
create or replace function public.lifeos_set_member_role(target_workspace uuid,target_user uuid,new_role text)
returns void language plpgsql security definer set search_path=public
as $$ begin
 if not public.lifeos_is_admin(target_workspace) then raise exception 'Only owner/admin can manage roles'; end if;
 if new_role not in ('admin','member') then raise exception 'Invalid role'; end if;
 if exists(select 1 from public.lifeos_workspace_members where workspace_id=target_workspace and user_id=target_user and role='owner') then raise exception 'Owner role cannot be changed'; end if;
 update public.lifeos_workspace_members set role=new_role where workspace_id=target_workspace and user_id=target_user;
end $$;
create or replace function public.lifeos_remove_member(target_workspace uuid,target_user uuid)
returns void language plpgsql security definer set search_path=public
as $$ begin
 if not public.lifeos_is_admin(target_workspace) then raise exception 'Only owner/admin can remove members'; end if;
 if target_user=auth.uid() then raise exception 'Use leave workspace separately'; end if;
 if exists(select 1 from public.lifeos_workspace_members where workspace_id=target_workspace and user_id=target_user and role='owner') then raise exception 'Owner cannot be removed'; end if;
 delete from public.lifeos_workspace_members where workspace_id=target_workspace and user_id=target_user;
end $$;

revoke all on function public.lifeos_is_member(uuid) from public;
revoke all on function public.lifeos_is_admin(uuid) from public;
revoke all on function public.lifeos_create_workspace(text) from public;
revoke all on function public.lifeos_create_personal_workspace(text) from public;
revoke all on function public.lifeos_join_workspace(text) from public;
revoke all on function public.lifeos_list_members(uuid) from public;
revoke all on function public.lifeos_my_workspaces() from public;
revoke all on function public.lifeos_set_member_role(uuid,uuid,text) from public;
revoke all on function public.lifeos_remove_member(uuid,uuid) from public;
grant execute on function public.lifeos_is_member(uuid) to authenticated;
grant execute on function public.lifeos_is_admin(uuid) to authenticated;
grant execute on function public.lifeos_create_workspace(text) to authenticated;
grant execute on function public.lifeos_create_personal_workspace(text) to authenticated;
grant execute on function public.lifeos_join_workspace(text) to authenticated;
grant execute on function public.lifeos_list_members(uuid) to authenticated;
grant execute on function public.lifeos_my_workspaces() to authenticated;
grant execute on function public.lifeos_set_member_role(uuid,uuid,text) to authenticated;
grant execute on function public.lifeos_remove_member(uuid,uuid) to authenticated;

-- Enable realtime only if not already published.
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='lifeos_workspace_data') then
  alter publication supabase_realtime add table public.lifeos_workspace_data;
 end if;
exception when undefined_object then null; end $$;

-- Explicit API privileges; RLS still decides which rows each signed-in user can access.
grant select on public.lifeos_workspaces to authenticated;
grant select on public.lifeos_workspace_members to authenticated;
grant select,insert,update on public.lifeos_workspace_data to authenticated;

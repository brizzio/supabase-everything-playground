-- Auto-generated REST API through PostgREST.
-- In Supabase, tables, views, functions, grants, and RLS policies become the
-- REST surface exposed under /rest/v1.

create extension if not exists pgcrypto;

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  slug text not null unique,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.projects enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'projects'
      and policyname = 'projects_select_own'
  ) then
    create policy projects_select_own
      on public.projects
      for select
      to authenticated
      using (auth.uid() = owner_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'projects'
      and policyname = 'projects_write_own'
  ) then
    create policy projects_write_own
      on public.projects
      for all
      to authenticated
      using (auth.uid() = owner_id)
      with check (auth.uid() = owner_id);
  end if;
end;
$$;

create or replace view public.project_summaries as
select
  id,
  owner_id,
  name,
  slug,
  settings ->> 'plan' as plan,
  created_at
from public.projects;

create or replace function public.find_project_by_slug(p_slug text)
returns public.project_summaries
language sql
stable
as $$
  select *
  from public.project_summaries
  where slug = p_slug
  limit 1;
$$;

grant select, insert, update, delete on public.projects to authenticated;
grant select on public.project_summaries to authenticated;
grant execute on function public.find_project_by_slug(text) to authenticated;

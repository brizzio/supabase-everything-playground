-- Native GraphQL via pg_graphql.
-- In Supabase, installing this extension exposes database objects through
-- the /graphql/v1 endpoint according to schema permissions and RLS.

create extension if not exists pg_graphql;
create extension if not exists pgcrypto;

create table if not exists public.graphql_notes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  title text not null,
  body text,
  is_done boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.graphql_notes enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'graphql_notes'
      and policyname = 'graphql_notes_select_own'
  ) then
    create policy graphql_notes_select_own
      on public.graphql_notes
      for select
      to authenticated
      using (auth.uid() = owner_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'graphql_notes'
      and policyname = 'graphql_notes_insert_own'
  ) then
    create policy graphql_notes_insert_own
      on public.graphql_notes
      for insert
      to authenticated
      with check (auth.uid() = owner_id);
  end if;
end;
$$;

grant select, insert, update, delete on public.graphql_notes to authenticated;

comment on table public.graphql_notes is
  'Example table reflected by pg_graphql and protected by RLS.';

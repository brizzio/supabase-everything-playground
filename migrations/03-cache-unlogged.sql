-- Redis-like cache using an unlogged table.
-- Unlogged tables are faster for transient data because changes are not
-- written to WAL. Data can be truncated after a database crash, so keep only
-- disposable cache/session values here.

create unlogged table if not exists public.cache_entries (
  key text primary key,
  value jsonb not null,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists cache_entries_expires_at_idx
  on public.cache_entries (expires_at);

create or replace function public.cache_set(
  p_key text,
  p_value jsonb,
  p_ttl interval default interval '15 minutes'
)
returns void
language sql
as $$
  insert into public.cache_entries (key, value, expires_at)
  values (p_key, p_value, now() + p_ttl)
  on conflict (key) do update
    set value = excluded.value,
        expires_at = excluded.expires_at,
        created_at = now();
$$;

create or replace function public.cache_get(p_key text)
returns jsonb
language sql
stable
as $$
  select value
  from public.cache_entries
  where key = p_key
    and (expires_at is null or expires_at > now());
$$;

create or replace function public.cache_delete_expired()
returns integer
language plpgsql
as $$
declare
  deleted_count integer;
begin
  delete from public.cache_entries
  where expires_at is not null
    and expires_at <= now();

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

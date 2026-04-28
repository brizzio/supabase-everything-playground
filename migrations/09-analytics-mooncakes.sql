-- High-performance analytics inside Postgres.
-- Raw events are kept append-only, while a materialized view stores daily
-- aggregates for dashboard queries.

create extension if not exists pgcrypto;

create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  event_name text not null,
  properties jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

create index if not exists analytics_events_occurred_at_idx
  on public.analytics_events (occurred_at desc);

create index if not exists analytics_events_event_name_idx
  on public.analytics_events (event_name);

create index if not exists analytics_events_properties_idx
  on public.analytics_events
  using gin (properties jsonb_path_ops);

create materialized view if not exists public.analytics_daily_events as
select
  date_trunc('day', occurred_at)::date as event_date,
  event_name,
  count(*) as total_events,
  count(distinct user_id) as unique_users
from public.analytics_events
group by 1, 2
with no data;

create unique index if not exists analytics_daily_events_unique_idx
  on public.analytics_daily_events (event_date, event_name);

create or replace function public.refresh_analytics_daily_events()
returns void
language sql
security definer
set search_path = public
as $$
  refresh materialized view public.analytics_daily_events;
$$;

-- If pg_cron is enabled, refresh the dashboard aggregate every 10 minutes:
-- select cron.schedule(
--   'refresh-analytics-daily-events',
--   '*/10 * * * *',
--   $$ select public.refresh_analytics_daily_events(); $$
-- );

-- NoSQL-style documents with JSONB.
-- Use this when the schema changes often, but you still want SQL indexes,
-- constraints, RLS, and PostgREST access from Supabase.

create extension if not exists pgcrypto;

create table if not exists public.product_catalog (
  id uuid primary key default gen_random_uuid(),
  sku text not null unique,
  name text not null,
  attributes jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists product_catalog_attributes_gin_idx
  on public.product_catalog
  using gin (attributes jsonb_path_ops);

create index if not exists product_catalog_category_idx
  on public.product_catalog ((attributes ->> 'category'));

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists product_catalog_touch_updated_at on public.product_catalog;

create trigger product_catalog_touch_updated_at
before update on public.product_catalog
for each row
execute function public.touch_updated_at();

-- Example query:
-- select *
-- from public.product_catalog
-- where attributes @> '{"category":"hardware"}';

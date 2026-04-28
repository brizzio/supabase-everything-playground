-- Built-in Postgres full-text search.
-- This gives Algolia/Elasticsearch-style search for common app content
-- without another service.

create extension if not exists pgcrypto;

create table if not exists public.articles (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  summary text,
  body text not null,
  tags text[] not null default '{}',
  published_at timestamptz,
  created_at timestamptz not null default now(),
  search_vector tsvector not null default ''::tsvector
);

create or replace function public.articles_update_search_vector()
returns trigger
language plpgsql
as $$
begin
  new.search_vector :=
    setweight(to_tsvector('portuguese', coalesce(new.title, '')), 'A') ||
    setweight(to_tsvector('portuguese', coalesce(new.summary, '')), 'B') ||
    setweight(to_tsvector('portuguese', coalesce(new.body, '')), 'C') ||
    setweight(to_tsvector('portuguese', array_to_string(new.tags, ' ')), 'B');

  return new;
end;
$$;

drop trigger if exists articles_update_search_vector on public.articles;

create trigger articles_update_search_vector
before insert or update of title, summary, body, tags on public.articles
for each row
execute function public.articles_update_search_vector();

create index if not exists articles_search_vector_idx
  on public.articles
  using gin (search_vector);

create index if not exists articles_tags_idx
  on public.articles
  using gin (tags);

create or replace function public.search_articles(
  p_query text,
  p_limit integer default 20
)
returns table (
  id uuid,
  title text,
  summary text,
  rank real
)
language sql
stable
as $$
  select
    articles.id,
    articles.title,
    articles.summary,
    ts_rank_cd(articles.search_vector, websearch_to_tsquery('portuguese', p_query)) as rank
  from public.articles
  where articles.search_vector @@ websearch_to_tsquery('portuguese', p_query)
  order by rank desc, articles.published_at desc nulls last
  limit p_limit;
$$;

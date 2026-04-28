-- Ativa a extensão de vetores
create extension if not exists vector;

create table documents (
  id uuid primary key default gen_random_uuid(),
  content text,
  embedding vector(1536) -- Tamanho padrão do OpenAI
);

-- Busca por similaridade
create or replace function match_documents (
  query_embedding vector(1536),
  match_threshold float,
  match_count int
)
returns table (id uuid, content text, similarity float)
language sql stable
as $$
  select
    id, content, 1 - (documents.embedding <=> query_embedding) as similarity
  from documents
  where 1 - (documents.embedding <=> query_embedding) > match_threshold
  order by similarity desc
  limit match_count;
$$;
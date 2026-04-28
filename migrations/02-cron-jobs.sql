-- Ativa a extensão
create extension if not exists pg_cron;

-- Exemplo: Deletar logs antigos toda noite às 3 da manhã
select cron.schedule(
  'limpeza-diaria-logs',
  '0 3 * * *',
  $$ delete from system_logs where created_at < now() - interval '30 days' $$
);
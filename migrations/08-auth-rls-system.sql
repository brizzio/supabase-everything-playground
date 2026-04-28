-- Garante que o usuário só veja seus próprios dados
alter table profiles enable row level security;

create policy "Usuários podem ver apenas o próprio perfil"
on profiles for select
to authenticated
using ( auth.uid() = id );
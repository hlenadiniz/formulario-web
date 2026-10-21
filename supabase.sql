-- Rode este arquivo no Supabase: SQL Editor > New query > Run.
create table if not exists public.respostas (
  annotador   int  not null,
  item        int  not null,
  persona     text,
  mensagem    text,
  rotulo      text,
  resposta    text not null check (resposta in ('SIM','NAO')),
  atualizado_em timestamptz not null default now(),
  primary key (annotador, item)
);

alter table public.respostas enable row level security;

-- A página usa a chave anônima: pode ler, inserir e corrigir respostas, nunca apagar.
create policy "ler respostas"      on public.respostas for select to anon using (true);
create policy "inserir respostas"  on public.respostas for insert to anon with check (true);
create policy "corrigir respostas" on public.respostas for update to anon using (true) with check (true);

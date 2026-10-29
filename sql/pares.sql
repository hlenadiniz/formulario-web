-- KIDS · Distribuição em PARES: cada mensagem é respondida por 2 anotadores diferentes.
-- Substitui o sorteio aleatório com cotas (tabela `cotas`, trigger e sortear_itens de sql/distribuicao.sql).
--
-- Regra (determinística, sem sorteio entre pares):
--   1. Cada item tem um "dono" (1ª leitura), sorteado entre os donos até completar a `meta` de cada um.
--      Itens especiais são distribuídos primeiro, então ficam proporcionais às metas.
--   2. A 2ª leitura vai sempre para quem "revisa_de" o dono. Em anel:
--        Bárbara <-> Daniel  |  Murilo <- Sophia <- Alexandre <- Murilo  |  Jean <- Lucas <- Caike <- Jean
--      (Murilo responde os itens da Sophia, Sophia os do Alexandre, Alexandre os do Murilo, etc.)
--   3. Kênia e Helena (validadoras) ficam inativas por enquanto: não aparecem no site e não recebem itens.
--      Quem não está na configuração da seção 3 fica inativo (some dos botões).
--
-- Rode DEPOIS de importar os itens (e do supabase.sql) e ANTES de haver respostas.
-- Pode rodar de novo para mudar a configuração: o arquivo é idempotente.

-- 0. Trava: não mexe se já existem respostas (evita perder trabalho)
do $$ begin
  if exists (select 1 from public.respostas) then
    raise exception 'Já existem respostas: não rode este arquivo. Use sortear_itens(semente, true) para redistribuir só o que não foi respondido.';
  end if;
end $$;

-- 1. Limpeza do desenho anterior
drop trigger  if exists trg_limita_dois_comuns on public.atribuicoes;
drop function if exists public.limita_dois_comuns();
drop table    if exists public.cotas;
delete from public.atribuicoes;                      -- é refeito por sortear_itens()

-- 2. Colunas
alter table public.anotadores  add column if not exists meta int check (meta >= 0);               -- itens de que a pessoa é DONA
alter table public.anotadores  add column if not exists revisa_de int references public.anotadores(id);  -- de quem ela faz a 2ª leitura
create unique index if not exists anotadores_revisa_de_uq on public.anotadores (revisa_de) where revisa_de is not null;

alter table public.atribuicoes add column if not exists lote text;                                  -- semente do sorteio
alter table public.atribuicoes add column if not exists atribuido_em timestamptz not null default now();
alter table public.atribuicoes add column if not exists leitura smallint check (leitura in (1, 2)); -- 1 = dono, 2 = 2ª leitura
-- Garante por construção: no máximo uma 1ª e uma 2ª leitura por item (a PK já impede a mesma pessoa duas vezes).
create unique index if not exists atribuicoes_item_leitura_uq on public.atribuicoes (item, leitura) where leitura is not null;

alter table public.respostas   add column if not exists leitura smallint;                           -- copiado de atribuicoes ao salvar

-- 3. Configuração das pessoas. Soma das metas = nº de itens (3.290).
update public.anotadores set ativo = false;                        -- todos fora da lista; só os 8 abaixo voltam (Kênia, Helena, Maria, João ficam de fora)

with cfg(nome, meta, de) as (values
  ('Bárbara',   950, 'Daniel'),
  ('Daniel',    950, 'Bárbara'),
  ('Murilo',    232, 'Sophia'),
  ('Sophia',    232, 'Alexandre'),
  ('Alexandre', 232, 'Murilo'),
  ('Jean',      231, 'Lucas'),
  ('Lucas',     232, 'Caike'),     -- 232 aqui: é o item que sobra (3.290 = 1.900 + 696 + 694)
  ('Caike',     231, 'Jean'))
update public.anotadores a set meta = c.meta, ativo = true, validador = false
from cfg c where a.nome = c.nome;

with cfg(nome, de) as (values
  ('Bárbara','Daniel'), ('Daniel','Bárbara'),
  ('Murilo','Sophia'), ('Sophia','Alexandre'), ('Alexandre','Murilo'),
  ('Jean','Lucas'), ('Lucas','Caike'), ('Caike','Jean'))
update public.anotadores a set revisa_de = d.id
from cfg c join public.anotadores d on d.nome = c.de
where a.nome = c.nome;

do $$ begin
  if (select count(*) from public.anotadores where ativo and meta is not null and revisa_de is not null) <> 8 then
    raise exception 'Esperava 8 anotadores configurados: confira os nomes em public.anotadores (acentos, Caike/Kayke etc.).';
  end if;
end $$;

-- 4. Funções
-- salvar: igual à anterior, mas grava também a `leitura` (1ª ou 2ª resposta do item).
create or replace function public.salvar(p_anotador int, p_respostas jsonb) returns int
language plpgsql security definer set search_path = public as $$
declare a public.anotadores; n int;
begin
  select * into a from public.anotadores where id = p_anotador and ativo;
  if not found then raise exception 'anotador invalido' using errcode = '28000'; end if;
  with e as (
    select distinct on ((x->>'item')::bigint) (x->>'item')::bigint as item, (x->>'resposta')::smallint as resposta
    from jsonb_array_elements(p_respostas) x
    order by (x->>'item')::bigint
  ), ins as (
    insert into public.respostas (anotador, anotador_nome, validador, item, persona, especial, leitura, mensagem, rotulo, resposta, atualizado_em)
    select a.id, a.nome, a.validador, i.item, i.persona, i.especial, t.leitura, i.message_content, i.rotulo, e.resposta, now()
    from e
    join public.atribuicoes t on t.item = e.item and t.anotador = a.id
    join public.itens i on i.item = e.item
    on conflict (anotador, item) do update set resposta = excluded.resposta, atualizado_em = now()
    returning 1)
  select count(*) into n from ins;
  return n;
end $$;

-- sortear_itens('semente')        : completa o que falta (itens sem dono / sem 2ª leitura); não mexe no que já existe.
-- sortear_itens('semente', true)  : antes, solta os itens em que NINGUÉM respondeu ainda, e refaz.
create or replace function public.sortear_itens(p_semente text, p_redistribuir boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare it record; escolhido int; sem_dono int := 0; novos2 int := 0; sem_par int;
begin
  if not exists (select 1 from public.anotadores where ativo and not validador and meta > 0) then
    raise exception 'nenhum anotador ativo com meta: rode a configuração (seção 3 de sql/pares.sql)';
  end if;

  if p_redistribuir then
    delete from public.atribuicoes t
    where t.leitura is not null
      and not exists (select 1 from public.respostas r
                      join public.atribuicoes x on x.anotador = r.anotador and x.item = r.item and x.leitura is not null
                      where r.item = t.item);
  end if;

  -- 1ª leitura: o dono. Especiais primeiro; cada item vai para quem está mais longe de completar a meta.
  for it in
    select i.item from public.itens i
    where not exists (select 1 from public.atribuicoes t where t.item = i.item and t.leitura = 1)
    order by i.especial desc, md5(i.item::text || p_semente)
  loop
    select a.id into escolhido from public.anotadores a
    where a.ativo and not a.validador and a.meta > 0
      and (select count(*) from public.atribuicoes t where t.anotador = a.id and t.leitura = 1) < a.meta
    order by (select count(*) from public.atribuicoes t where t.anotador = a.id and t.leitura = 1)::numeric / a.meta, a.id
    limit 1;
    if escolhido is null then sem_dono := sem_dono + 1; continue; end if;
    insert into public.atribuicoes (anotador, item, leitura, lote) values (escolhido, it.item, 1, p_semente);
  end loop;

  -- 2ª leitura: sempre a pessoa que revisa_de o dono.
  insert into public.atribuicoes (anotador, item, leitura, lote)
  select b.id, t.item, 2, p_semente
  from public.atribuicoes t
  join public.anotadores b on b.revisa_de = t.anotador and b.ativo
  where t.leitura = 1
    and not exists (select 1 from public.atribuicoes x where x.item = t.item and x.leitura = 2)
  on conflict do nothing;
  get diagnostics novos2 = row_count;

  select count(*) into sem_par from public.atribuicoes t
  where t.leitura = 1 and not exists (select 1 from public.atribuicoes x where x.item = t.item and x.leitura = 2);

  return public.progresso() || jsonb_build_object(
    'segundas_leituras_novas', novos2, 'itens_sem_dono', sem_dono, 'itens_sem_segunda_leitura', sem_par);
end $$;

create or replace function public.progresso() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('anotadores', coalesce(jsonb_agg(x order by x->>'nome'), '[]'::jsonb))
  from (
    select jsonb_build_object(
      'nome', a.nome, 'ativo', a.ativo, 'meta', a.meta,
      'revisa_de', (select d.nome from public.anotadores d where d.id = a.revisa_de),
      'atribuidos',  (select count(*) from public.atribuicoes t where t.anotador = a.id),
      'como_dono',   (select count(*) from public.atribuicoes t where t.anotador = a.id and t.leitura = 1),
      'como_2a_leitura', (select count(*) from public.atribuicoes t where t.anotador = a.id and t.leitura = 2),
      'especiais',   (select count(*) from public.atribuicoes t join public.itens i on i.item = t.item
                      where t.anotador = a.id and i.especial),
      'respondidos', (select count(*) from public.respostas r where r.anotador = a.id),
      'pendentes',   (select count(*) from public.atribuicoes t where t.anotador = a.id
                      and not exists (select 1 from public.respostas r where r.anotador = t.anotador and r.item = t.item))
    ) as x
    from public.anotadores a) q
$$;

revoke all on function public.sortear_itens(text, boolean), public.progresso() from public, anon, authenticated;
revoke all on function public.salvar(int, jsonb) from public;
grant execute on function public.salvar(int, jsonb) to anon;

-- 5. Para baixar: UMA linha por item, com as duas respostas lado a lado (quem e quanto).
create or replace view public.respostas_pares with (security_invoker = true) as
select i.item, i.rotulo, i.message_content as mensagem, i.especial,
       r1.anotador_nome as anotador_1, r1.resposta as resposta_1,
       r2.anotador_nome as anotador_2, r2.resposta as resposta_2,
       abs(r1.resposta - r2.resposta) as diferenca
from public.itens i
left join public.respostas r1 on r1.item = i.item and r1.leitura = 1
left join public.respostas r2 on r2.item = i.item and r2.leitura = 2;
revoke all on public.respostas_pares from anon, authenticated;

-- 6. Executar e conferir
--   select public.sortear_itens('kids-2026');   -- esperado: itens_sem_dono = 0 e itens_sem_segunda_leitura = 0
--   select public.progresso();
--   -- todo item com exatamente 1ª e 2ª leitura, por pessoas diferentes (esperado: nenhuma linha):
--   select item from public.atribuicoes group by item
--   having count(*) <> 2 or count(*) filter (where leitura = 1) <> 1 or count(*) filter (where leitura = 2) <> 1;

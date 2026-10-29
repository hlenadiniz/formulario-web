-- passo 1
-- rastreio: quando e em qual sorteio cada item foi atribuído
alter table public.atribuicoes
  add column if not exists lote text,
  add column if not exists atribuido_em timestamptz not null default now();
create index if not exists atribuicoes_item_idx on public.atribuicoes (item);

-- marcar os 200 especiais (os de msgs_sem_rotulo)
alter table public.itens add column if not exists especial boolean not null default false;

update public.itens i set especial = true
from public.msgs_sem_rotulo s
where i.message_content = s."Examples" and i.rotulo = s."Label";

select count(*) filter (where especial) as especiais, count(*) as total from public.itens;
-- esperado: 200 e 3290

-- cotas por anotador (total = 2 x tabela original, fechando 6.580)
create table if not exists public.cotas (
  anotador  int primary key references public.anotadores(id),
  normais   int not null,
  especiais int not null
);
alter table public.cotas enable row level security;  -- sem policy: não fica exposta pela API

insert into public.cotas (anotador, normais, especiais)
select a.id, v.normais, v.especiais
from (values
  ('Bárbara',1784,116), ('Daniel',1784,116),
  ('Murilo',436,28), ('Sophia',436,28), ('Alexandre',436,28),
  ('Caike',434,28), ('Jean',435,28), ('Lucas',435,28)
) as v(nome, normais, especiais)
join public.anotadores a on a.nome = v.nome
on conflict (anotador) do update
  set normais = excluded.normais, especiais = excluded.especiais;

select count(*), sum(normais), sum(especiais) from public.cotas;
-- esperado: 8, 6180, 400

-- passo 2

-- trava: no máximo 2 anotadores comuns por item
create or replace function public.limita_dois_comuns()
returns trigger language plpgsql as $$
begin
  if not (select validador from public.anotadores where id = new.anotador)
     and (select count(*) from public.atribuicoes t
          join public.anotadores a on a.id = t.anotador
          where t.item = new.item and not a.validador) >= 2 then
    raise exception 'Item % já tem 2 anotadores comuns', new.item;
  end if;
  return new;
end $$;

drop trigger if exists trg_limita_dois_comuns on public.atribuicoes;
create trigger trg_limita_dois_comuns
before insert on public.atribuicoes
for each row execute function public.limita_dois_comuns();

-- progresso: mantém as chaves antigas e acrescenta especiais, cota e pendentes
create or replace function public.progresso()
returns jsonb language sql stable security definer set search_path to 'public'
as $$
  select jsonb_build_object('anotadores', coalesce(jsonb_agg(x order by x->>'nome'), '[]'::jsonb))
  from (
    select jsonb_build_object(
      'nome', a.nome, 'validador', a.validador, 'ativo', a.ativo,
      'atribuidos',  (select count(*) from atribuicoes t where t.anotador = a.id),
      'especiais',   (select count(*) from atribuicoes t join itens i on i.item = t.item
                      where t.anotador = a.id and i.especial),
      'respondidos', (select count(*) from respostas r where r.anotador = a.id),
      'pendentes',   (select count(*) from atribuicoes t where t.anotador = a.id
                      and not exists (select 1 from respostas r
                                      where r.anotador = t.anotador and r.item = t.item)),
      'cota_total',  (select c.normais + c.especiais from cotas c where c.anotador = a.id),
      'cota_especiais', (select c.especiais from cotas c where c.anotador = a.id)
    ) as x
    from anotadores a) q
$$;

-- sorteio: 2 comuns diferentes por item, respeitando as cotas
create or replace function public.sortear_itens(p_semente text, p_redistribuir boolean default false)
returns jsonb language plpgsql security definer set search_path to 'public'
as $function$
declare
  esp boolean; it record; restantes int; escolhidos int[];
  novos int := 0; faltam int := 0; sobra int := 0;
begin
  if (select count(*) from anotadores where ativo and not validador) < 2 then
    raise exception 'precisa de pelo menos 2 anotadores comuns ativos';
  end if;

  -- respostas já dadas por comuns contam como atribuição
  insert into atribuicoes (anotador, item, lote)
  select rp.anotador, rp.item, 'pre-existente'
  from respostas rp join anotadores an on an.id = rp.anotador
  where not an.validador
  on conflict do nothing;

  -- redistribuir: solta só os NÃO respondidos dos comuns (validadores nunca são tocados)
  if p_redistribuir then
    delete from atribuicoes t using anotadores a
    where a.id = t.anotador and not a.validador
      and not exists (select 1 from respostas x where x.anotador = t.anotador and x.item = t.item);
  end if;

  create temp table if not exists _rest (anotador int, rest int) on commit drop;

  foreach esp in array array[false, true] loop
    delete from _rest;
    insert into _rest
    select c.anotador,
           (case when esp then c.especiais else c.normais end)
           - (select count(*) from atribuicoes t join itens i on i.item = t.item
              where t.anotador = c.anotador and i.especial = esp)
    from cotas c join anotadores a on a.id = c.anotador
    where a.ativo and not a.validador;

    select count(*) into restantes from itens i
    where i.especial = esp
      and (select count(*) from atribuicoes t join anotadores a on a.id = t.anotador
           where t.item = i.item and not a.validador) < 2;

    for it in
      select i.item,
             2 - (select count(*) from atribuicoes t join anotadores a on a.id = t.anotador
                  where t.item = i.item and not a.validador) as falta
      from itens i
      where i.especial = esp
        and (select count(*) from atribuicoes t join anotadores a on a.id = t.anotador
             where t.item = i.item and not a.validador) < 2
      order by md5(i.item::text || p_semente)
    loop
      select array_agg(s.anotador) into escolhidos from (
        select q.anotador from _rest q
        where q.rest > 0
          and not exists (select 1 from atribuicoes t
                          where t.item = it.item and t.anotador = q.anotador)
        order by (q.rest >= restantes) desc,
                 ln((('x' || substr(md5(p_semente || it.item::text || q.anotador::text), 1, 8))::bit(32)::bigint + 1)
                    / 4294967297.0) / q.rest desc
        limit it.falta
      ) s;

      if escolhidos is not null then
        insert into atribuicoes (anotador, item, lote)
        select unnest(escolhidos), it.item, p_semente;
        update _rest set rest = rest - 1 where anotador = any(escolhidos);
        novos := novos + array_length(escolhidos, 1);
      end if;
      faltam := faltam + (it.falta - coalesce(array_length(escolhidos, 1), 0));
      restantes := restantes - 1;
    end loop;

    sobra := sobra + coalesce((select sum(rest) from _rest where rest > 0), 0);
  end loop;

  return public.progresso() || jsonb_build_object(
    'atribuicoes_novas', novos, 'vagas_sem_anotador', faltam, 'cota_sobrando', sobra);
end $function$;

select public.sortear_itens('uma-semente');

--- passo 3
select public.sortear_itens('uma-semente');
select public.progresso();

-- passo 4, conferencia
-- todo item com exatamente 2 comuns (esperado: vazio)
select i.item, count(*) filter (where not a.validador) as comuns
from public.itens i
left join public.atribuicoes t on t.item = i.item
left join public.anotadores a on a.id = t.anotador
group by i.item
having count(*) filter (where not a.validador) <> 2;

-- total e especiais por pessoa contra a cota
select a.nome, count(*) as total, count(*) filter (where i.especial) as especiais,
       c.normais + c.especiais as cota_total, c.especiais as cota_esp
from public.atribuicoes t
join public.anotadores a on a.id = t.anotador
join public.itens i on i.item = t.item
join public.cotas c on c.anotador = a.id
group by a.nome, c.normais, c.especiais
order by total desc;

select i.item, count(*) filter (where not a.validador) as comuns
from public.itens i
left join public.atribuicoes t on t.item = i.item
left join public.anotadores a on a.id = t.anotador
group by i.item
having count(*) filter (where not a.validador) <> 2;
-- esperado: nenhuma linha


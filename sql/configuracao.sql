  -- configurar anotadores
  insert into public.anotadores (nome, validador) values
     ('Bárbara', false), ('Daniel', false), ('Caike', false), ('Murilo', false), ('Lucas', false), ('Jean', false);

  update public.anotadores set ativo = false where nome = 'João';
  update public.anotadores set ativo = false where nome = 'Maria';


--- limpar o banco e atualizar tabela itens com as msgs sem rotulo
-- conferencia
select count(*) from public.msgs_sem_rotulo; --200
select count(*) from public.msgs; --3099

begin;

truncate public.itens restart identity cascade;

insert into public.itens (message_content, rotulo)
select "Examples", "Label" from public.msgs
union
select "Examples", "Label" from public.msgs_sem_rotulo;

commit;

-- conferencia final
select count(*) from public.itens;
select rotulo, count(*) from public.itens group by rotulo order by 2 desc;

-- msgs repetidas
select "Label", "Examples", count(*) as vezes
from (
  select "Label", "Examples" from public.msgs
  union all
  select "Label", "Examples" from public.msgs_sem_rotulo
) t
group by 1, 2
having count(*) > 1
order by vezes desc;


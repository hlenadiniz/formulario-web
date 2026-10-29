# KIDS · Rotulação humana

Formulário estático (Vercel ou GitHub Pages) + Supabase para guardar as respostas. Escala Likert de 1 a 5 ("o rótulo descreve corretamente esta mensagem?").

## Como a pessoa usa

1. Abre a página e **clica no próprio nome** (os nomes são botões, abertos a todos).
2. Na primeira vez que entra (por aparelho), vê as **instruções**. Depois pode relê-las em "Ver instruções".
3. Vai para as perguntas dela: na primeira vez, a primeira pergunta; se já respondeu algumas, **a primeira ainda sem resposta**. Pode voltar e mudar respostas; "Trocar de pessoa" volta à lista de nomes.

O progresso fica no Supabase (por anotador), então vale em qualquer aparelho. Como não há senha, quem abre a página pode responder em nome de qualquer um: o desenho assume um grupo de confiança.

## Quem recebe o quê

- **Anotador comum:** cada item da amostra vai para exatamente **um** anotador comum. Quem tem `meta` recebe exatamente essa quantidade (ex.: Barbara e Daniel, 950 cada); os demais dividem o **restante** em partes iguais (±1).
- **Validador (Kênia e Helena):** cada item vai também para exatamente **um** validador, sem `meta`: cada uma recebe **metade** do total (metades disjuntas) e não entra na divisão dos anotadores comuns.
- **Itens especiais** (controle): importados com `--especial`, ficam misturados aos demais, distribuídos proporcionalmente às cotas, e o anotador **não vê** nenhuma marca. A coluna `especial` só aparece na tabela `respostas` exportada.
- A ordem das perguntas é embaralhada e fixa para cada pessoa.

## 1. Supabase (uma vez)

1. Crie um projeto em supabase.com.
2. SQL Editor > New query: cole `supabase.sql` e clique em Run. (Se houver tabelas de uma versão anterior, apague-as antes: o comando está no topo do arquivo. Atenção: apaga as respostas de teste.)
3. Copie para `config.js` a **Project URL** e a **Publishable key** `sb_publishable_...`. Nunca use a Secret key no site.

## 2. Anotadores

No SQL Editor (nomes aparecem como botões; `validador = true` só para Kênia e Helena; `meta` = cota fixa, vazio = divide o restante):

```sql
insert into public.anotadores (nome, validador, meta) values
  ('Kênia', true, null), ('Helena', true, null),
  ('Barbara', false, 950), ('Daniel', false, 950),
  ('Murilo', false, null), ('Sophia', false, null), ('Jean', false, null),
  ('Alexandre', false, null), ('Lucas', false, null), ('Kayke', false, null);
```

Para tirar alguém da lista: `update public.anotadores set ativo = false where nome = 'Jean';`

## 3. Amostra

CSVs em `data/` com rótulo e mensagem (`rotulo`/`Label` e `message_content`/`Examples`; opcional `persona`). **Sem nomes de usuário**: a amostra não vai para o GitHub (`.gitignore`) e fica só no Supabase.

```bash
python3 scripts/importar_amostra.py data/amostra_final.csv --sql                    # gera data/importar_amostra_final.sql
python3 scripts/importar_amostra.py data/amostra_especial.csv --sql --especial      # itens especiais
```

Cole cada `.sql` gerado no SQL Editor. Também dá para enviar direto pela API (`SUPABASE_URL` e `SUPABASE_SECRET_KEY` no ambiente, sem `--sql`). Linhas repetidas (mesmo rótulo e mensagem) são ignoradas, então **dá para reimportar a amostra expandida**: entram só os casos novos.

`data/rotulos.csv` (colunas `Label`, `Description`, `Examples`) é público e vai para o site.

## 4. Distribuir os itens

Cada item é atribuído a **2 anotadores comuns diferentes**. Validadores (Kênia e Helena) ficam fora desta etapa. A distribuição segue cotas por pessoa, com os itens especiais divididos separadamente, e cada atribuição fica registrada em `atribuicoes`.

### 4.1 Importar os itens

As duas fontes (`msgs` e `msgs_sem_rotulo`, ambas com `"Label"` e `"Examples"`) são unidas sem duplicatas:

```sql
begin;
truncate public.itens restart identity cascade;  -- apaga também atribuicoes e respostas

insert into public.itens (message_content, rotulo)
select "Examples", "Label" from public.msgs
union
select "Examples", "Label" from public.msgs_sem_rotulo;
commit;
```

### 4.2 Estrutura de rastreio

```sql
-- quando e em qual sorteio cada item foi atribuído; índice para contar por item
alter table public.atribuicoes
  add column if not exists lote text,
  add column if not exists atribuido_em timestamptz not null default now();
create index if not exists atribuicoes_item_idx on public.atribuicoes (item);

-- itens especiais = os de msgs_sem_rotulo
alter table public.itens add column if not exists especial boolean not null default false;
update public.itens i set especial = true
from public.msgs_sem_rotulo s
where i.message_content = s."Examples" and i.rotulo = s."Label";
```

A PK `(anotador, item)` de `atribuicoes` indica quem recebeu qual item e impede a mesma pessoa duas vezes no mesmo item.

### 4.3 Cotas por anotador

Tabela `cotas (anotador, normais, especiais)`. Os valores abaixo somam 6.580 atribuições (3.290 itens × 2):

| Anotador                  | Normais | Especiais | Total |
| ------------------------- | ------- | --------- | ----- |
| Bárbara, Daniel          | 1.784   | 116       | 1.900 |
| Murilo, Sophia, Alexandre | 436     | 28        | 464   |
| Jean, Lucas               | 435     | 28        | 463   |
| Caike                     | 434     | 28        | 462   |

```sql
create table if not exists public.cotas (
  anotador  int primary key references public.anotadores(id),
  normais   int not null,
  especiais int not null
);
alter table public.cotas enable row level security;  -- sem policy: não exposta pela API
```

Para ajustar uma cota: `update public.cotas set normais = 500 where anotador = <id>;`

### 4.4 Funções e trava

Definidas em `sql/` (ver arquivos):

- `limita_dois_comuns()` + trigger `trg_limita_dois_comuns`: bloqueia um 3º anotador comum no mesmo item.
- `sortear_itens(semente, redistribuir default false)`: completa cada item até ter 2 comuns diferentes, respeitando as cotas. A semente torna o sorteio reproduzível.
- `progresso()`: por pessoa, `atribuidos`, `especiais`, `respondidos`, `pendentes`, `cota_total` e `cota_especiais`.

### 4.5 Executar

```sql
select public.sortear_itens('uma-semente');         -- completa só o que falta (itens com menos de 2 comuns)
select public.sortear_itens('uma-semente', true);   -- solta os NÃO respondidos de todos os comuns e refaz
select public.progresso();                          -- atribuídos, especiais, respondidos e pendentes
```

O retorno deve ter `vagas_sem_anotador: 0` e `cota_sobrando: 0`. Respostas já dadas e atribuições dos validadores nunca são alteradas.

### 4.6 Conferências

```sql
-- todo item com exatamente 2 comuns (esperado: nenhuma linha)
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
```

### 4.7 Anotador que não respondeu

Solta os pendentes da pessoa, desativa e redistribui só o que ficou com menos de 2:

```sql
delete from public.atribuicoes t using public.anotadores a
where a.id = t.anotador and a.nome = 'Jean'
  and not exists (select 1 from public.respostas x
                  where x.anotador = t.anotador and x.item = t.item);

update public.anotadores set ativo = false where nome = 'Jean';

-- aumente a cota de quem vai absorver (as cotas estão cheias)
update public.cotas set normais = normais + 100
where anotador in (select id from public.anotadores where nome in ('Murilo', 'Sophia'));

select public.sortear_itens('seed-2');
```

Se `vagas_sem_anotador` vier maior que 0, faltou cota: aumente e rode de novo.

### 4.8 Rastrear

```sql
select * from public.atribuicoes where item = 123;   -- quem recebeu, em qual lote e quando
```

Pendente = atribuição sem linha correspondente em `respostas`.

> `itens.rotulo` e `itens.especial` são gabarito/controle e não devem ser exibidos ao anotador.

## 5. Publicar

Envie `index.html`, `config.js`, `data/rotulos.csv` (e `scripts/`, `supabase.sql`) ao GitHub e ative Pages (branch `main`, raiz). Mande o link às pessoas.

## 6. Baixar as respostas

Supabase > Table Editor > `respostas` > Export > CSV. Colunas: `anotador, anotador_nome, validador, item, persona, especial, mensagem, rotulo, resposta (1 a 5), atualizado_em`. `especial = true` marca os itens de controle.

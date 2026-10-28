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
No SQL Editor, depois de importar itens ou cadastrar anotadores:

```sql
select public.sortear_itens('uma-semente');         -- distribui só o que ainda não tem responsável
select public.sortear_itens('uma-semente', true);   -- mudou anotadores/cotas? solta os itens NÃO respondidos dos comuns e redistribui
select public.progresso();                          -- atribuídos, especiais e respondidos por pessoa
```
Respostas já dadas e as atribuições dos validadores nunca são alteradas.

## 5. Publicar
Envie `index.html`, `config.js`, `data/rotulos.csv` (e `scripts/`, `supabase.sql`) ao GitHub e ative Pages (branch `main`, raiz). Mande o link às pessoas.

## 6. Baixar as respostas
Supabase > Table Editor > `respostas` > Export > CSV. Colunas: `anotador, anotador_nome, validador, item, persona, especial, mensagem, rotulo, resposta (1 a 5), atualizado_em`. `especial = true` marca os itens de controle.

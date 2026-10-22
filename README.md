# KIDS · Rotulação humana (BR13 e BR15)

Formulário estático (GitHub Pages) + Supabase para guardar as respostas.

## 1. Supabase (uma vez)
1. Crie uma conta em supabase.com e um projeto novo (plano gratuito).
2. SQL Editor > New query: cole o conteúdo de `supabase.sql` e clique em Run.
3. Copie para `config.js` a **Project URL** (Project Settings > Data API) e a **Publishable key** `sb_publishable_...` (Project Settings > API Keys). Nunca use a Secret key.

## 2. Dados
Coloque em `data/`:
- `rotulos.csv`: colunas `Label`, `Description`, `Examples` (e opcional `Idade`). Pode usar o `Ratings - V2.0 - Classind 2025.csv`, ou só as linhas dos rótulos escolhidos.
- `amostra.csv`: uma linha por par mensagem × rótulo, colunas `message_content` (ou `mensagem`) e `rotulo` (ou `label`); opcional `persona`. **Remova nomes de usuário e outras colunas**: o repositório é público.

Cada item `i` (linha da amostra, começando em 0) vai para o anotador `(i mod N) + 1`.

## 3. Publicar
1. Crie um repositório no GitHub e envie estes arquivos (`index.html`, `config.js`, `data/`).
2. Settings > Pages > Source: `Deploy from a branch`, branch `main`, pasta `/ (root)`.
3. O link sai em `https://SEU-USUARIO.github.io/NOME-DO-REPO/`. Mande o link e o número de cada anotador.

## 4. Baixar as respostas
Supabase > Table Editor > `respostas` > Export > CSV. As colunas são `annotador, item, persona, mensagem, rotulo, resposta (SIM/NAO)`.

Se trocar a amostra depois de haver respostas, apague as linhas antigas no Table Editor.

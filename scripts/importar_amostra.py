#!/usr/bin/env python3
"""Importa (ou reimporta) a amostra de mensagens para a tabela `itens` do Supabase.

Linhas repetidas (mesmo rótulo + mesma mensagem) são ignoradas, então pode rodar de novo com a amostra
expandida: só entram os casos novos. Depois de importar, rode no SQL Editor:  select public.sortear_itens('semente');

Dois modos (escolha um):

  A) Gerar SQL para colar no SQL Editor do Supabase (não precisa de chave nenhuma):
       python3 scripts/importar_amostra.py data/amostra.csv --sql
     Cria data/importar_itens.sql (fica fora do Git, ver .gitignore).

  B) Enviar direto pela API, usando a chave SECRET do projeto (nunca coloque em arquivo versionado):
       export SUPABASE_URL="https://xxxx.supabase.co"
       export SUPABASE_SECRET_KEY="sb_secret_..."
       python3 scripts/importar_amostra.py data/amostra.csv

Colunas aceitas no CSV: rotulo (ou label), message_content (ou mensagem), persona (opcional).
"""
import csv, json, os, sys, argparse, urllib.request, urllib.error

def achar(cols, nomes):
    mapa = {c.strip().lower(): c for c in cols}
    for n in nomes:
        if n in mapa:
            return mapa[n]
    return None

def ler(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        amostra = f.read(4096); f.seek(0)
        try:
            dialect = csv.Sniffer().sniff(amostra, delimiters=",;\t")
        except csv.Error:
            dialect = csv.excel
        rd = csv.DictReader(f, dialect=dialect)
        cr = achar(rd.fieldnames, ["rotulo", "rótulo", "label"])
        cm = achar(rd.fieldnames, ["message_content", "mensagem", "message"])
        cp = achar(rd.fieldnames, ["persona"])
        if not cr or not cm:
            sys.exit(f"Não achei as colunas de rótulo e mensagem. Colunas: {rd.fieldnames}")
        vistos, linhas, dup, vazias = set(), [], 0, 0
        for r in rd:
            rot, msg = (r[cr] or "").strip(), (r[cm] or "").strip()
            if not rot or not msg:
                vazias += 1; continue
            chave = (rot, msg)
            if chave in vistos:
                dup += 1; continue
            vistos.add(chave)
            linhas.append({"rotulo": rot, "message_content": msg, "persona": (r[cp].strip() or None) if cp else None})
    print(f"{len(linhas)} itens únicos ({dup} repetidos e {vazias} vazios descartados).")
    return linhas

def lit(s):
    return "null" if s is None else "'" + s.replace("'", "''") + "'"

def gerar_sql(linhas, saida):
    with open(saida, "w", encoding="utf-8") as f:
        f.write("-- Gerado por scripts/importar_amostra.py. Cole no SQL Editor do Supabase. Pode rodar mais de uma vez.\n")
        for i in range(0, len(linhas), 300):
            vals = ",\n".join(f"({lit(l['message_content'])},{lit(l['rotulo'])},{lit(l['persona'])})" for l in linhas[i:i+300])
            f.write(f"insert into public.itens (message_content, rotulo, persona) values\n{vals}\non conflict (rotulo, message_content) do nothing;\n\n")
    print(f"SQL em {saida}. Cole no SQL Editor (se o editor reclamar do tamanho, divida o arquivo em partes).")

def enviar(linhas):
    url, chave = os.environ.get("SUPABASE_URL"), os.environ.get("SUPABASE_SECRET_KEY")
    if not url or not chave:
        sys.exit("Defina SUPABASE_URL e SUPABASE_SECRET_KEY, ou use --sql.")
    api = url.rstrip("/").removesuffix("/rest/v1") + "/rest/v1/itens?on_conflict=rotulo,message_content"
    for i in range(0, len(linhas), 500):
        req = urllib.request.Request(api, data=json.dumps(linhas[i:i+500]).encode(), method="POST", headers={
            "apikey": chave, "Authorization": "Bearer " + chave, "Content-Type": "application/json",
            "Prefer": "resolution=ignore-duplicates,return=minimal"})
        try:
            urllib.request.urlopen(req).read()
        except urllib.error.HTTPError as e:
            sys.exit(f"Erro {e.code}: {e.read().decode()[:400]}")
        print(f"enviados {min(i+500, len(linhas))}/{len(linhas)}")

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("csv"); ap.add_argument("--sql", action="store_true", help="gera data/importar_itens.sql em vez de enviar")
    a = ap.parse_args()
    dados = ler(a.csv)
    if a.sql: gerar_sql(dados, os.path.join(os.path.dirname(os.path.abspath(a.csv)), "importar_itens.sql"))
    else: enviar(dados)

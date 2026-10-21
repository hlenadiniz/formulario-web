// Preencha com os dados do seu projeto Supabase (Project Settings > API).
// A chave "anon public" pode ficar no repositório: o acesso é limitado pelas regras do supabase.sql.
window.KIDS_CONFIG = {
  SUPABASE_URL: "https://mlbngbrjmaqzhpqdvpfg.supabase.co/rest/v1/",
  SUPABASE_ANON_KEY: "sb_publishable_Bz-F003DkN9jSFgu2Eboqg_T3kBm5V8",
  N_ANOTADORES: 7,
  ARQUIVO_ROTULOS: "data/rotulos.csv",   // colunas: Label, Description, Examples (e opcional Idade)
  ARQUIVO_AMOSTRA: "data/amostra.csv"    // colunas: message_content (ou mensagem), rotulo (ou label), opcional persona
};

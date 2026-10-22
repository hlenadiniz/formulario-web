// SUPABASE_URL: Project Settings > Data API > Project URL (ou botão Connect).
// SUPABASE_ANON_KEY: a chave PUBLISHABLE (sb_publishable_...) ou, no painel antigo, a "anon public".
// NUNCA coloque aqui a chave secret (sb_secret_...) ou service_role.
window.KIDS_CONFIG = {
  SUPABASE_URL: "https://SEU-PROJETO.supabase.co",
  SUPABASE_ANON_KEY: "COLE_AQUI_A_CHAVE_ANON_PUBLIC",
  N_ANOTADORES: 7,
  ARQUIVO_ROTULOS: "data/rotulos.csv",   // colunas: Label, Description, Examples (e opcional Idade)
  ARQUIVO_AMOSTRA: "data/amostra.csv"    // colunas: message_content (ou mensagem), rotulo (ou label), opcional persona
};

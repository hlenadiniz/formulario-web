// SUPABASE_URL: Project Settings > Data API > Project URL (ou botão Connect).
// SUPABASE_ANON_KEY: a chave PUBLISHABLE (sb_publishable_...) ou, no painel antigo, a "anon public".
// NUNCA coloque aqui a chave secret (sb_secret_...) ou service_role.
window.KIDS_CONFIG = {
  SUPABASE_URL: "https://SEU-PROJETO.supabase.co",
  SUPABASE_ANON_KEY: "COLE_AQUI_A_CHAVE_ANON_PUBLIC",
  N_ANOTADORES: 7,                       // deve ser igual ao número de códigos abaixo
  SEMENTE: 20261026,                     // define o sorteio dos itens; não mude depois de começar
  // Só os hashes dos códigos ficam aqui. Os códigos em si estão em codigos_anotadores.txt (fora do repositório).
  CODIGOS_SHA256: {
    "5bd78e14a2cffd319550668f4eefb64835f18611f02e56b30cccb15bb2c1dad6": 1,
    "477ac7f599f908b7e6d7f32e96b57be2be1cb3f6923bef225223075738190ab7": 2,
    "a68f844dd801cbf154d7beeb3ebcd949ac338fddc1e8fdcd0a0336eb89d4fcd0": 3,
    "312b1b8363dd62c135ad1bfcba3765349f45ff4cee977818eb9430bb62f100a9": 4,
    "f66f677cd575fce584943a7186c6c5c8420b6fd62653f156b8b1f543358e3dc4": 5,
    "a98229707f8b2bd2821fe07699d3593894ca971856607af6891d835782088e50": 6,
    "88b9dea2cfdef05b5a6c4190fab7ebbb217e5368e6f9ac7e763e06196277fd84": 7
},
  ARQUIVO_ROTULOS: "data/rotulos.csv",   // colunas: Label, Description, Examples (e opcional Idade)
  ARQUIVO_AMOSTRA: "data/amostra.csv"    // colunas: message_content (ou mensagem), rotulo (ou label), opcional persona
};

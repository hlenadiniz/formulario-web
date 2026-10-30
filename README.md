# KIDS · Rotulação humana de mensagens da Twitch

Formulário web para que pessoas avaliem se o rótulo atribuído a uma mensagem de chat da Twitch realmente descreve o que a mensagem diz. O trabalho faz parte da pesquisa **"Crianças e Adolescentes em Plataformas de Mídias Sociais: Perigos, Desafios e Oportunidades"**, do Departamento de Ciência da Computação da UFMG, sob coordenação da profa. Jussara M. Almeida.

## Objetivo

Plataformas de mídias sociais expõem crianças e adolescentes a conteúdos inapropriados, como violência, drogas, discurso de ódio e conteúdo sexual. Para detectar esses riscos automaticamente, é preciso antes saber **o que conta como risco** e **como nomeá-lo**. A pesquisa parte dos rótulos do **ClassInd**, o guia brasileiro de Classificação Indicativa, que foi pensado para obras audiovisuais (filmes, jogos, programas). A pergunta deste projeto é: esses rótulos funcionam quando aplicados a mensagens curtas de texto, escritas de forma informal em chats ao vivo?

Para responder, mensagens reais e públicas da Twitch, em português, foram associadas a rótulos do ClassInd, e pessoas avaliam, uma a uma, se a associação está correta. Essas avaliações servem para adaptar os rótulos ao contexto das redes sociais, construir uma taxonomia de riscos e danos e, depois, treinar e testar métodos de detecção.

## O que a pessoa faz

1. **Lê o TCLE e as instruções** (Termo de Consentimento Livre e Esclarecido) e, concordando, clica em "Concordo com o TCLE e desejo prosseguir".
2. **Escolhe o próprio nome** na lista. Não há senha nem cadastro: o progresso fica guardado e a pessoa pode parar e continuar depois, em qualquer aparelho, de onde parou.
3. **Responde uma mensagem por vez.** A tela mostra a mensagem, o rótulo do ClassInd e a descrição e o exemplo desse rótulo. Em seguida a pessoa indica o quanto concorda que *o rótulo classifica corretamente a mensagem apresentada*, em uma escala de cinco pontos, de "discordo totalmente" a "concordo totalmente".

A tarefa é avaliar o conteúdo da mensagem, não julgar quem a escreveu. Nenhuma resposta é obrigatória, e a pessoa pode pausar ou encerrar a qualquer momento.

## Como as mensagens são distribuídas

- **Cada mensagem é avaliada por duas pessoas diferentes.** Isso permite comparar as respostas e medir o quanto as pessoas concordam entre si. A segunda pessoa é sempre a mesma para cada responsável, em duplas ou trincas fixas, e as respostas ficam registradas como 1ª e 2ª leitura.
- **A carga de trabalho é combinada com cada anotador:** uma parte da equipe responde a mais mensagens, e as demais dividem o restante de forma equilibrada.
- **A ordem é embaralhada.** Cada pessoa vê as suas mensagens em ordem aleatória, e os rótulos aparecem misturados.
- **Há mensagens de controle.** Uma parte da amostra (200 mensagens) recebeu um rótulo escolhido ao acaso, porque as mensagens originais não tinham rótulo. Elas são entregues junto com as demais, sem nenhuma indicação para quem responde, e ficam marcadas no banco. Servem para verificar se as pessoas estão avaliando com atenção.
- **Validação futura.** Duas pessoas da equipe de pesquisa (Kênia e Helena) foram reservadas para validar, mais adiante, as avaliações dos anotadores. Por enquanto elas não recebem mensagens.

## A amostra

São 3.290 mensagens: 3.090 com rótulo atribuído pelo processo da pesquisa, em 40 rótulos do ClassInd, e 200 mensagens de controle. As mensagens foram anonimizadas: **não há nome de usuário nem outro dado que identifique quem escreveu**.

## Privacidade

As mensagens da amostra **não ficam no site nem no repositório público**. Elas ficam apenas no banco de dados, e cada pessoa recebe somente as mensagens que lhe foram atribuídas. As respostas não pedem dados pessoais. O repositório contém apenas o código do formulário e as descrições públicas dos rótulos do ClassInd.

## O que se obtém no final

Uma tabela com todas as respostas, indicando para cada mensagem: o rótulo, quem respondeu, a nota de 1 a 5, se foi a 1ª ou a 2ª leitura e se era uma mensagem de controle. Também há uma visão com **uma linha por mensagem**, com as duas respostas lado a lado e a diferença entre elas, pronta para a análise de concordância.

## Como funciona por dentro

O formulário é uma página estática, publicada no GitHub Pages, que conversa diretamente com um banco no **Supabase**. O banco guarda as mensagens, a lista de anotadores, a divisão do trabalho e as respostas. A página só consegue ler as mensagens da pessoa que escolheu o próprio nome e gravar as respostas dela.

Detalhes técnicos de instalação, importação da amostra e distribuição das mensagens estão em [README.md](README.md) e nos arquivos da pasta `sql/`.

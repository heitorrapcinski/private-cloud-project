# Fluxo de Trabalho Agile-Agentic: Da Intenção ao Impacto em Horas

Este modelo redefine o ciclo tradicional agile, comprimindo sprints de semanas para ciclos de 24 horas (**Daily Sprints**). A estratégia baseia-se em uma operação de dois turnos: o **Turno Humano** (focado em requisitos, design e detalhamento de tarefas) e o **Turno de Agentes** (focado em execução das demais fases de engenharia).

## As Quatro Posturas Cognitivas Fundamentais
*“Visão aprofundada, especificação ousada, decisão rápida e iteração sem medo.”*

A capacitação técnica não é suficiente sem uma transformação na forma de pensar e agir. A frase acima adota quatro posturas cognitivas essenciais que definem como os profissionais devem operar no novo paradigma:

*   **Visão aprofundada**: É o que separa quem usa IA de quem é usado por ela. Não é saber usar a ferramenta — é ter repertório suficiente para formular o problema certo. A maioria das falhas com IA não acontece na geração, acontece aqui: o problema foi mal compreendido, o contexto foi mal lido, a dor real ficou escondida atrás do sintoma. Visão aprofundada é diagnóstico antes de solução, é curiosidade antes de resposta, é a capacidade humana que nenhum agente substitui — porque o agente só enxerga o que você ilumina.

*   **Especificação ousada**: É onde o humano exerce criatividade com intenção. A spec não é um briefing burocrático — é um ato de design. Ousada porque propõe soluções que ainda não existem, que cruzam domínios, que desafiam o óbvio. É aqui que o repertório vira invenção. Uma spec tímida produz código correto e mediocre. Uma spec ousada abre espaço para o agente gerar algo que surpreende — mas dentro de uma direção que só o humano com visão consegue apontar.

*   **Decisão rápida**: O novo gargalo. A IA gera opções, variações e alternativas em segundos — e isso paralisa quem não está habituado a decidir com informação incompleta. Decisão rápida não é impulsividade: é a consciência de que errar custa pouco e não decidir custa tudo. É a coragem de escolher um caminho sabendo que a iteração vai corrigir o que precisar. Quem espera pela certeza antes de decidir perdeu o ponto central do paradigma.

*   **Iteração sem medo**: É a consequência natural das três anteriores — e o que fecha o ciclo. Quando o custo de geração caiu a quase zero, o erro deixou de ser fracasso e virou dado. Cada iteração é uma hipótese testada, uma spec refinada, um aprendizado capturado. Sem medo porque o custo de recomeçar é baixo, porque a spec pode ser corrigida, porque o agente não julga e não se cansa. O medo que paralisava no desenvolvimento tradicional — simplesmente não faz mais sentido aqui.

## O Ritmo do Processo: O Daily Sprint
O ciclo é contínuo, transformando o desenvolvimento em um loop de alta velocidade.

### Turno Humano (Duração: 1h a 2h)
Um time multidisciplinar (Arquitetura, Produto, Marketing, Segurança e Engenharia) se reúne para as cerimônias de governança e direcionamento:

*   **Daily Sprint Review (30 min):** O time revisa Pull Requests, evidências de testes e flags de risco gerados pelos agentes. O foco humano é avaliar o ajuste arquitetural e se o comportamento atende à intenção original, e não a revisão de código linha a linha.
*   **Daily Sprint Planning & Spec Refinement (1h):**
    *   O time utiliza **Visão Aprofundada** para decompor o backlog em tarefas "prontas para agentes".
    *   Realiza-se o **Desenvolvimento Orientado por Especificações (SDD)**: criação de documentos Markdown estruturados definindo o "quê" (requisitos e critérios de aceitação) e restrições técnicas.
    *   **Decisão Rápida:** O time valida a especificação e autoriza o início da construção agêntica.

### Turno de Construção Agêntica (Automático/Assíncrono)
Após a definição humana, a frota de agentes assume as etapas de engenharia:

*   **Agentes de Planejamento:** Decompõem a *spec* em planos de implementação e sub-tarefas técnicas.
*   **Agentes de Codificação:** Implementam mudanças respeitando as regras de arquitetura e segurança (contexto persistente).
*   **Agentes de Teste e QA (Eval-Driven):** Executam suítes de testes e validam o comportamento contra as especificações (*Evals*).
*   **Agentes de Segurança e Documentação:** Realizam varreduras de vulnerabilidades e atualizam referências de API e sumários de mudanças.

## Papéis e Responsabilidades
*   **Squad Humana (Orquestradores):** Atuam como "Editores-chefe". Declaram a intenção de alto nível, definem limites e aplicam julgamento sobre os resultados dos agentes.
*   **Frota de Agentes (Executores):** Atuam como a força de trabalho de "turno da noite", entregando em 12 horas o progresso que levaria semanas em modelos tradicionais.

## Benefícios Esperados
*   **Velocidade:** Ciclos de feedback reduzidos de semanas para horas.
*   **Eficiência:** Casos reais demonstram até 10 vezes mais velocidade com metade do custo.
*   **Foco Humano:** Profissionais focam em estratégia e valor, delegando o trabalho braçal (*toil*) à automação.

Esta metodologia permite que a modernização e a entrega de valor tornem-se **"business as usual"**, eliminando a inércia competitiva.
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

*   **Agentes de Planejamento:** Decompõem a *spec* em planos de implementação e sub-tarefas técnicas:
    *   **Análise de Dependências:** Mapeiam dependências entre módulos, serviços e bibliotecas para determinar a ordem de execução e identificar riscos de acoplamento.
    *   **Decomposição em Sub-tarefas:** Quebram cada requisito da spec em unidades atômicas de trabalho com critérios de conclusão claros, estimativas de complexidade e pré-condições explícitas.
    *   **Geração do Grafo de Execução:** Produzem um DAG (Directed Acyclic Graph) de tarefas que permite paralelização máxima entre agentes de codificação, respeitando dependências sequenciais.
    *   **Alocação de Contexto:** Determinam quais arquivos, schemas, contratos de API e steering rules cada agente de codificação precisará carregar, minimizando contexto desnecessário e maximizando relevância.
    *   **Definição de Checkpoints:** Estabelecem pontos de verificação intermediários onde o progresso é validado antes de avançar para a próxima fase, evitando propagação de erros em cascata.

*   **Agentes de Codificação:** Implementam mudanças respeitando as regras de arquitetura e segurança (contexto persistente):
    *   **Carregamento de Contexto Persistente:** Inicializam com o grafo de execução, steering files do projeto, padrões de arquitetura e histórico de decisões relevantes — mantendo coerência entre sessões.
    *   **Implementação Incremental:** Codificam cada sub-tarefa de forma isolada em branches efêmeras, garantindo que cada commit represente uma mudança atômica, compilável e reversível.
    *   **Conformidade Arquitetural:** Validam em tempo de codificação que o código gerado respeita camadas de abstração, convenções de nomenclatura, padrões de injeção de dependência e limites de domínio definidos na spec.
    *   **Segurança by Default:** Aplicam práticas de secure coding automaticamente — queries parametrizadas, validação de input, sanitização de output, gerenciamento seguro de segredos e princípio do menor privilégio.
    *   **Auto-Revisão e Refatoração:** Executam uma passada de revisão sobre o próprio código antes de submeter, identificando code smells, duplicações e oportunidades de simplificação.
    *   **Geração de Pull Requests Estruturados:** Criam PRs com descrição contextualizada, referência à spec de origem, resumo das mudanças e evidências de conformidade para facilitar a revisão humana na Sprint Review.

*   **Agentes de Teste e QA (Eval-Driven):** Executam suítes de testes e validam o comportamento contra as especificações (*Evals*):
    *   **Geração Automática de Testes:** Derivam casos de teste diretamente dos critérios de aceitação da spec — unitários, de integração e end-to-end — garantindo cobertura alinhada à intenção original.
    *   **Execução Contínua de Evals:** Rodam as suítes contra cada commit, comparando outputs reais com os comportamentos esperados definidos nas especificações, tratando divergências como falhas bloqueantes.
    *   **Testes de Contrato e Compatibilidade:** Validam que interfaces entre serviços (APIs, eventos, schemas) permanecem compatíveis com consumidores existentes, prevenindo breaking changes silenciosas.
    *   **Testes de Performance e Carga:** Executam benchmarks automatizados para detectar regressões de latência, throughput e consumo de recursos antes que cheguem a ambientes superiores.
    *   **Análise de Cobertura e Gaps:** Identificam áreas do código sem cobertura adequada e geram testes complementares, priorizando caminhos críticos e edge cases derivados da spec.
    *   **Relatório de Qualidade:** Produzem um sumário consolidado com métricas de cobertura, taxa de aprovação, falhas categorizadas e recomendações de ação para a Sprint Review.

*   **Agentes de Segurança e Documentação:** Realizam varreduras de vulnerabilidades e atualizam referências de API e sumários de mudanças:
    *   **SAST e Análise Estática:** Executam varreduras de código estático para identificar vulnerabilidades (injection, XSS, SSRF, deserialização insegura) e violações de políticas de segurança corporativas.
    *   **SCA (Software Composition Analysis):** Analisam dependências de terceiros contra bases de CVEs conhecidas, verificam licenças e alertam sobre bibliotecas desatualizadas ou comprometidas.
    *   **Secrets Scanning:** Detectam credenciais, tokens e chaves hardcoded no código ou em arquivos de configuração, bloqueando o merge até a remediação.
    *   **Geração de Documentação de API:** Atualizam automaticamente especificações OpenAPI/AsyncAPI, diagramas de sequência e referências de endpoints a partir do código implementado.
    *   **Changelog e Release Notes:** Compilam sumários de mudanças legíveis por humanos, categorizando alterações por tipo (feature, fix, breaking change) e vinculando cada entrada à spec e ao PR de origem.
    *   **Atualização de Runbooks e Guias Operacionais:** Refletem mudanças de infraestrutura e configuração nos runbooks existentes, garantindo que a documentação operacional permaneça sincronizada com o estado real do sistema.
*   **Agentes de Entrega e Implantação Contínua (CD):** Orquestram o pipeline de entrega de ponta a ponta:
    *   **Build & Artefatos:** Compilam, empacotam e versionam artefatos imutáveis (containers, pacotes, imagens de VM) com rastreabilidade completa até o commit de origem.
    *   **Promoção entre Ambientes:** Promovem artefatos validados através dos estágios do pipeline (dev → staging → produção) respeitando gates de qualidade e aprovações definidas na spec.
    *   **Implantação Progressiva:** Executam estratégias de deploy seguro — canary releases, blue-green deployments ou rolling updates — com rollback automático baseado em métricas de saúde (latência, taxa de erro, saturação).
    *   **Validação Pós-Deploy:** Disparam smoke tests e verificações de integridade no ambiente-alvo, confirmando que o comportamento em produção corresponde ao esperado nas *Evals*.
    *   **Observabilidade do Deploy:** Correlacionam eventos de implantação com métricas de infraestrutura e aplicação, gerando relatórios de impacto para a Daily Sprint Review seguinte.

## Papéis e Responsabilidades
*   **Squad Humana (Orquestradores):** Atuam como "Editores-chefe". Declaram a intenção de alto nível, definem limites e aplicam julgamento sobre os resultados dos agentes.
*   **Frota de Agentes (Executores):** Atuam como a força de trabalho de "turno da noite", entregando em 12 horas o progresso que levaria semanas em modelos tradicionais.

## Benefícios Esperados
*   **Velocidade:** Ciclos de feedback reduzidos de semanas para horas.
*   **Eficiência:** Casos reais demonstram até 10 vezes mais velocidade com metade do custo.
*   **Foco Humano:** Profissionais focam em estratégia e valor, delegando o trabalho braçal (*toil*) à automação.

Esta metodologia permite que a modernização e a entrega de valor tornem-se **"business as usual"**, eliminando a inércia competitiva.
# Data Warehouse e Dicionário de Dados - Hamburgueria

Documentação e dicionário de dados do DW que desenvolvi para a operação da hamburgueria. O objetivo do projeto é centralizar o histórico, automatizar a baixa de estoque, controlar o caixa diário e ter clareza das margens reais do negócio.

---

## Status do Projeto e Roadmap

 **Nota sobre o escopo:** Toda a modelagem e a estrutura das tabelas descritas neste repositório já foram criadas no Supabase/PostgreSQL. O projeto foi previamente planejado utilizando o **dbdiagram.io** para validação relacional e funcional. Para agilizar o desenvolvimento da arquitetura e dos scripts SQL/ETL, utilizei o **Google AI Studio** como assistente técnico.

### Etapas Concluídas
- [x] **Levantamento e Planejamento:** Estruturação das entidades e regras de negócio com base nos dados históricos anotados da operação.
- [x] **Modelagem  Criação de Schemas:** Criação física das tabelas nas camadas Bronze e Silver (com validações de integridade, FKs e SCD2).
- [x] **Diagramação:** Conexão e validação do modelo relacional (Star Schema) via dbdiagram.io.

### Etapa Atual
- [ ] **Carga Histórica (População de Dados):** Inserção dos dados resumidos dos meses anteriores para estruturação dos primeiros dashboards no Power BI, focados na análise da saúde financeira e margens reais do negócio.

### Próximos Passos
- [ ] **Automação Diária:** Organização do fluxo contínuo das tabelas fato para alimentação diária da operação.
- [ ] **Integrações e Automações (Futuro):** Construção de pipeline unindo **WhatsApp + n8n + Supabase via Agente de IA** para atendimento automatizado, verificação de cadastros de clientes e consulta em tempo real do saldo/expiração de cashback.

---


## Benchmark de Modelos de IA (Auxílio na Geração de Scripts e Modelagem)

Para otimizar o tempo de desenvolvimento dos scripts DDL/ETL e validação das tabelas, fiz um teste comparativo entre diferentes LLMs e configurações no plano gratuito. O objetivo foi avaliar a precisão na geração de relacionamentos SQL complexos e minimizar alucinações de código.

| Modelo / Ferramenta | Configuração / Modo | Avaliação e Resultado |
| :--- | :--- | :--- |
| **Gemini Flash (AI Studio)** | Padrão | **OK** — Cumpriu a tarefa básica, mas apresentou algumas alucinações em regras de FKs e tipos de dados. |
| **Gemini Pro (AI Studio)** | Padrão | **Bom** — Entendimento superior do contexto do banco de dados e menor taxa de erros. |
| **Gemini Pro (AI Studio)** | **Code Execution ON** | **Excelente (Melhor Resultado)** — A execução de código integrada evitou alucinações. Mesmo no plano gratuito, manteve a consistência por várias horas de trabalho detalhado prompt a prompt. |
| **Claude Sonnet (Anthropic)** | Esforço Médio | **OK** — Respostas coerentes, mas com limitações de tamanho para scripts muito extensos. |
| **Claude Sonnet (Anthropic)** | Esforço Máximo | **Insuficiente** — O limite do plano gratuito foi atingido antes da geração da resposta completa. |

> **Conclusão técnica:** O uso do **Gemini Pro com Code Execution ativo** no Google AI Studio provou ser a ferramenta mais eficiente para este projeto de dados, permitindo iterar scripts complexos de DDL/DML sem estouro de contexto ou interrupções no fluxo de trabalho.


---


A modelagem segue a arquitetura **Kimball (Star Schema)** e foi dividida em 3 camadas de dados no PostgreSQL/Supabase:

- **Bronze (staging):** Recebe o dado bruto extraído dos CSVs/Excel sem passar por validação prévia.
- **Silver (dimensional):** É o modelo funcional do DW. Onde ficam as tabelas de dimensão, dimensões com histórico (SCD2), bridges para N:N e tabelas fato no grão atômico.
- **Gold (views):** Camada reservada para views e cálculos agregados prontos para consumo no Power BI (etapa em construção).

---

## Visão Geral da Modelagem

| Camada | Tabela | Tipo |
| :--- | :--- | :--- |
| **Bronze** | `stg_vendas_raw`, `stg_compras_raw`, `stg_contas_raw` | Staging |
| **Silver** | `dim_date`, `dim_canal_vendas`, `dim_clientes`, `dim_fornecedores`, `dim_categoria_conta`, `dim_contas_a_pagar`, `dim_cupom`, `dim_forma_pagamento` | Dimensão estável |
| **Silver** | `dim_produtos`, `dim_insumos` | Dimensão com histórico (SCD2) |
| **Silver** | `bridge_ficha_tecnica` | Bridge (N:N) |
| **Silver** | `fct_vendas`, `fct_itens_pedido`, `fct_compras_insumos`, `fct_movimentacao_estoque`, `fct_contas_pagas`, `fct_cashback_movimentacao`, `fct_perdas_desperdicio`, `fct_fechamento_caixa` | Fato transacional (grão atômico) |
| **Silver** | `fct_resumo_mensal_historico`, `fct_resumo_mensal_canal_historico` | Fato de snapshot histórico (carga única) |

---

## Dicionário de Dados Detalhado

---

### Camada Bronze — Staging

#### `stg_vendas_raw` / `stg_compras_raw` / `stg_contas_raw`
**Finalidade:** Funciona como uma zona de pouso para as planilhas exportadas do Excel. O arquivo cru cai aqui em JSONB sem nenhuma validação no schema. Isso previne que a carga inteira quebre por causa de um erro bobo de formatação ou texto em campo numérico. Depois que o dado pousa, um script de ETL lê essas linhas, trata e joga nas tabelas finais da camada Silver.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `id` | integer, PK | Identificador único da linha recebida na carga. |
| `linha_csv` | jsonb | A linha do arquivo CSV copiada na íntegra, sem tratamento. |
| `carregado_em` | timestamp | Marca temporal de quando o arquivo subiu. |
| `processado` | boolean | Flag de controle: indica se a linha já foi transformada e movida para a Silver. |

> **Relacionamentos:** Nenhum por regra de projeto. Como o dado ainda não está estruturado, não há FKs ligadas a staging.

---

### Camada Silver — Dimensões Estáveis

#### `dim_date`
**Finalidade:** Dimensão padrão de calendário. Criada para evitar a necessidade de reescrever funções de data (mês, ano, dia da semana) em cada consulta no SQL ou Power BI. As visões temporais e sazonais já ficam prontas.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `date_id` | integer, PK | Chave técnica da data (formato numerico como `YYYYMMDD`). |
| `data` | date | A data real, usada nos JOINs operacionais. |
| `ano`, `mes` | smallint | Atributos para agrupar totais por período. |
| `nome_mes`, `nome_dia_semana` | varchar | Nomes por extenso para facilitação de relatórios visuais. |
| `eh_fim_de_semana` | boolean | Flag booleana que facilita isolar o comportamento de vendas de fim de semana vs. dias úteis. |

> **Relacionamentos:** É a dimensão central do DW, referenciada via FK por praticamente todas as tabelas fato (`date_id`).

---

#### `dim_canal_vendas`
**Finalidade:** Mapear todos os pontos de entrada de pedidos da operação (iFood Loja 1, iFood Loja 2, 99Food, Balcão Presencial, Cardápio Web).

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `canal_id` | integer, PK | Chave técnica do canal de venda. |
| `nome_canal` | varchar | Nome do canal para exibição em dashboards. |
| `tipo_canal` | varchar | Agrupador macro (ex: *Delivery App*, *Presencial*, *Delivery Próprio*). Permite comparar plataformas inteiras sem depender do canal individual. |

> **Relacionamentos:** Referenciada em `fct_vendas`, `dim_cupom`, `dim_contas_a_pagar` e `fct_resumo_mensal_canal_historico`.

---

#### `dim_clientes`
**Finalidade:** Base de dados para o cadastro de clientes e programas de fidelidade. *(Estrutura pronta para população futura, à medida que os cadastros forem sendo coletados no atendimento)*.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `cliente_id` | integer, PK | Chave técnica do cliente. |
| `nome_cliente`, `telefone`, `bairro`, `rua`, `numero` | varchar | Dados para identificação e rotas de entrega. |
| `data_cadastro` | date | Data de entrada do cliente na base. |

> **Relacionamentos:** Referenciada por `fct_vendas` e `fct_cashback_movimentacao`. **Nota de projeto:** Essa dimensão não armazena o saldo atual de cashback do cliente numa coluna estática. O saldo é calculado de forma dinâmica/auditável lendo o histórico do ledger em `fct_cashback_movimentacao`.

---

#### `dim_fornecedores`
**Finalidade:** Cadastro centralizado dos fornecedores de insumos da operação.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `fornecedor_id` | integer, PK | Chave técnica do fornecedor. |
| `nome_fornecedor`, `categoria_fornecedor`, `telefone`, `observacoes` | varchar/text | Informações de contato e ramo de atuação. |
| `ativo` | boolean | Flag para indicar se o fornecedor continua ativo ou se foi descontinuado. |

> **Relacionamentos:** Referenciada diretamente na tabela `fct_compras_insumos`.

---

#### `dim_categoria_conta`
**Finalidade:** Classificar as despesas do negócio em um nível macro. Essa separação é fundamental no financeiro para não misturar os custos puramente operacionais do restaurante com retiradas pessoais dos sócios, o que distorceria a margem de lucro líquido real do negócio.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `categoria_macro_id` | integer, PK | Chave técnica do grupo de categoria. |
| `nome_categoria` | varchar | Nome do grupo (ex: `CUSTO_FIXO`, `CUSTO_VARIAVEL`, `GASTO_CASA_OPERACIONAL`). |
| `natureza` | varchar | Classificação conceitual: `DESPESA_EMPRESARIAL` vs. `RETIRADA_SOCIO`. |

> **Relacionamentos:** Referenciada pela tabela `dim_contas_a_pagar`.

---

#### `dim_contas_a_pagar`
**Finalidade:** Funciona como um plano de contas (um catálogo dos tipos recorrentes de despesa, como *Aluguel*, *Luz*, *Anúncio iFood*). O cadastro é feito uma única vez por tipo de conta — o valor e a ocorrência do pagamento em si são gravados separadamente na tabela fato.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `conta_id` | integer, PK | Chave técnica da conta. |
| `nome_conta` | varchar | Descrição amigável da conta. |
| `categoria_macro_id` | integer, FK | Liga a conta à sua categoria macro em `dim_categoria_conta`. |
| `socio` | varchar | Identifica qual dos sócios realizou a sangria/retirada, se aplicável. |
| `canal_id` | integer, FK (opcional) | Usado quando uma despesa pertence a um canal específico (ex: Anúncio exclusivo da Loja 1 do iFood). |

> **Relacionamentos:** Possui FKs para `dim_categoria_conta` e `dim_canal_vendas`. É referenciada por `fct_contas_pagas`.

---

#### `dim_cupom`
**Finalidade:** Catálogo com as categorias e campanhas de cupons promocionais rodadas nos canais de venda (ex: *Hits*, *Frete Grátis*, *Primeiro Pedido Clube*).

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `cupom_id` | integer, PK | Chave técnica do cupom. |
| `nome_cupom` | varchar | Nome/Identificador da campanha. |
| `tipo_cupom` | varchar | Classificação estratégica (`DESCONTO_FIXO`, `FRETE_GRATIS`, `PRIMEIRO_PEDIDO`). |
| `canal_id` | integer, FK | Indica em qual canal de venda aquela promoção roda. |
| `ativo` | boolean | Status da campanha (ativa ou finalizada). |

> **Relacionamentos:** Possui FK para `dim_canal_vendas` e é referenciada em `fct_vendas`. **Nota de projeto:** O desconto em dinheiro que varia em cada pedido (ex: R$ 5,00, R$ 8,00 ou R$ 10,00) é gravado no atributo `fct_vendas.cupom_desconto`. Esta dimensão guarda exclusivamente os metadados da campanha.

---

#### `dim_forma_pagamento`
**Finalidade:** Mapear todos os meios de pagamento recebidos e registrar as taxas percentuais cobradas pelas adquirentes/plataformas. Relações separadas entre Crédito e Débito foram mantidas (em vez de tirar uma média) para garantir cálculo de margem exato por pedido.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `forma_pagamento_id` | integer, PK | Chave técnica da forma de pagamento. |
| `nome_forma` | varchar | Descrição (ex: *Dinheiro*, *PIX*, *Cartão de Débito*, *Cartão de Crédito*). |
| `taxa_percentual_atual` | numeric | Percentual cobrado pela operadora do cartão/maquininha na transação. |

> **Relacionamentos:** Referenciada pela tabela fato `fct_vendas`.

---

### Camada Silver — Dimensões com Histórico (SCD Tipo 2)

#### `dim_produtos`
**Finalidade:** Catálogo de produtos estruturado como Slow Changing Dimension (SCD Type 2). Ele mantém o histórico temporal de preços de venda e custos. Em vez de sobrescrever o registro quando o preço de um hambúrguer muda, a versão antiga é encerrada e uma nova linha é criada. Dessa forma, se eu rodar um relatório retroativo de março, o DW saberá exatamente os valores que eram praticados em março.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `produto_sk` | integer, PK | Chave substituta (Surrogate Key) **exclusiva daquela versão** do registro. |
| `produto_id` | integer | Chave natural do produto. Ela é permanente entre atualizações e é quem garante a identidade do item no sistema. |
| `nome_produto`, `categoria` | varchar | Nome do produto e agrupador no cardápio. |
| `preco_balcao`, `preco_ifood` | numeric | Preços de venda praticados durante a janela de validade daquela versão. |
| `custo_producao_atual` | numeric | Cache do custo do produto calculado via `bridge_ficha_tecnica` × `dim_insumos`. Atualizado quando o custo de algum insumo sofre reajuste. |
| `ativo` | boolean | Disponibilidade do item no cardápio. |
| `valido_de`, `valido_ate` | date | Janela temporal de validade da versão (`valido_ate` fica nulo na versão ativa). |
| `versao_atual` | boolean | Flag booleana que isola a versão vigente (apenas uma `versao_atual = true` por `produto_id`). |

> **Relacionamentos:** As tabelas `bridge_ficha_tecnica` e `fct_itens_pedido` utilizam o `produto_id` (chave natural) para manter os relacionamentos lógicos do modelo.

---

#### `dim_insumos`
**Finalidade:** Catálogo de insumos/matérias-primas da cozinha, também modelado como SCD Type 2. Registra o histórico da variação de custos de cada ingrediente ao longo do tempo para monitorar a inflação de fornecedores.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `insumo_sk` | integer, PK | Surrogate Key identificadora da versão do insumo. |
| `insumo_id` | integer | Chave natural e estável da matéria-prima. |
| `nome_insumo`, `unidade_medida` | varchar | Identificação e unidade de controle de estoque (ex: *kg*, *g*, *unidade*, *litro*). |
| `custo_unitario` | numeric | Custo do ingrediente por unidade de medida durante aquela versão. |
| `valido_de`, `valido_ate`, `versao_atual` | date/boolean | Controle de histórico mantendo a mesma lógica da `dim_produtos`. |

> **Relacionamentos:** Referenciada logicamente via `insumo_id` pelas tabelas `bridge_ficha_tecnica`, `fct_compras_insumos`, `fct_movimentacao_estoque` e `fct_perdas_desperdicio`.

---

### Bridge (Tabela de Ligação N:N)

#### `bridge_ficha_tecnica`
**Finalidade:** Funciona como a ficha técnica/receita da cozinha. Mapeia a relação N:N entre os produtos acabados e as matérias-primas necessárias para produzi-los. É esta tabela que permite calcular dinamicamente o custo de produção dos lanches e rodar o motor de baixa automática no estoque a cada venda.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `produto_id`, `insumo_id` | integer, PK composta | Par único que liga um produto ao insumo correspondente. |
| `quantidade_insumo` | numeric | Quantidade exata da matéria-prima gasta para montar 1 unidade do produto (ex: 0.160 kg de carne para 1 smash burger). |

> **Relacionamentos:** Conecta os identificadores lógicos de `dim_produtos` e `dim_insumos`.

---

### Camada Silver — Fatos Transacionais (Grão Atômico)

#### `fct_vendas`
**Finalidade:** Tabela de cabeçalho das vendas do restaurante. Cada linha representa uma transação/pedido completo realizado em qualquer um dos canais.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `pedido_id` | integer, PK | Identificador único do pedido. |
| `date_id`, `canal_id` | integer, FK | Chaves para saber a data exata e em qual canal o pedido ocorreu. |
| `horario` | time | Hora, minuto e segundo em que a venda entrou no sistema. |
| `cliente_id` | integer, FK | Identificação do cliente (campo opcional). |
| `cupom_id` | integer, FK | Referência à categoria de promoção utilizada, se houver. |
| `forma_pagamento_id` | integer, FK | Meio de pagamento utilizado pelo cliente. |
| `valor_total_pedido` | numeric | Valor bruto cobrado do cliente na venda. |
| `taxa_entrega`, `custo_entrega` | numeric | Valor do frete cobrado do cliente vs. o valor real gasto para pagar o motoboy. |
| `cupom_desconto` | numeric | Desconto monetário real concedido na venda. |
| `cashback_usado` | numeric | Valor abatido da conta utilizando saldo de cashback acumulado. |
| `taxa_comissao` | numeric | Valor das comissões descontadas pela plataforma/marketplace (ex: iFood). |
| `valor_liquido_recebido` | numeric | O montante financeiro líquido que efetivamente entra no caixa da empresa. |
| `status_pedido` | varchar | Status da venda (ex: *Concluído*, *Cancelado*). |

> **Relacionamentos:** Possui FKs para `dim_date`, `dim_canal_vendas`, `dim_clientes`, `dim_cupom` e `dim_forma_pagamento`. É a tabela pai de `fct_itens_pedido` e `fct_cashback_movimentacao`.

---

#### `fct_itens_pedido`
**Finalidade:** Detalha os itens que compõem cada pedido de venda. O grão desta tabela é de **uma linha para cada item que faz parte de um pedido**.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `item_pedido_id` | integer, PK | Identificador da linha do item do pedido. |
| `pedido_id` | integer, FK | Chave de ligação para o cabeçalho do pedido em `fct_vendas`. |
| `produto_id` | integer | Código do produto vendido (referência lógica). |
| `quantidade` | smallint | Quantidade de unidades vendidas daquele item no pedido. |
| `preco_venda_unitario` | numeric | Preço unitário real praticado na hora da transação. |
| `custo_historico_unitario` | numeric | **Snapshot congelado do custo do produto no instante exato da venda.** Garante que a margem de lucro calculada no passado nunca seja alterada retroativamente por reajustes futuros nos insumos. |
| `estoque_processado` | boolean | Flag de controle que evita processamento/baixa duplicada no estoque. |

> **Relacionamentos:** FK obrigatória para `fct_vendas` e ponte lógica com a dimensão `dim_produtos`.

---

#### `fct_compras_insumos`
**Finalidade:** Registra cada entrada/compra de matérias-primas e insumos realizada junto aos fornecedores.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `compra_id` | integer, PK | Identificador único do registro de compra. |
| `date_id` | integer, FK | Data em que a compra foi realizada. |
| `insumo_id` | integer | Identificador do insumo comprado (referência lógica). |
| `fornecedor_id` | integer, FK | Código do fornecedor que vendeu o insumo. |
| `quantidade_comprada`, `valor_pago_total`, `preco_unitario_calculado` | numeric | Métricas de quantidade adquirida e custo cobrado na nota. |

> **Relacionamentos:** FKs conectando com `dim_date` e `dim_fornecedores`. Serve de gatilho para gerar registros de entrada positiva na `fct_movimentacao_estoque`.

---

#### `fct_movimentacao_estoque`
**Finalidade:** Funciona como um **Ledger (extrato financeiro) de estoque**. Toda e qualquer alteração no estoque — seja por compra de insumo, baixa por venda de lanche, perda de ingrediente ou acerto de inventário — gera uma linha nesta tabela. O saldo atual de estoque de um ingrediente nunca fica em uma coluna estática; ele é calculado fazendo `SUM(quantidade)` dos eventos nesta fato.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `movimentacao_id` | integer, PK | Identificador do evento no extrato de estoque. |
| `date_id` | integer, FK | Data em que a movimentação ocorreu. |
| `insumo_id` | integer | Identificador do ingrediente no estoque. |
| `quantidade` | numeric | Valor numérico da alteração: números positivos representam **Entradas**, números negativos representam **Saídas**. |
| `tipo_movimentacao` | varchar | Classificação do evento (`ENTRADA_COMPRA`, `SAIDA_VENDA`, `PERDA`, `AJUSTE_INVENTARIO`). |
| `origem_tipo`, `origem_id` | varchar/integer | Rastreabilidade do evento: apontam para a tabela e o registro que deram origem à movimentação (ex: indica qual `pedido_id` gerou a baixa). |
| `observacao` | text | Campo livre para detalhar ajustes manuais do estoque. |

> **Relacionamentos:** FK para `dim_date` e ligação lógica com `dim_insumos`.

---

#### `fct_contas_pagas`
**Finalidade:** Registra a ocorrência real de desembolso financeiro referente ao pagamento das contas da operação.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `pagamento_id` | integer, PK | Identificador único da transação de pagamento. |
| `date_id` | integer, FK | Data em que o dinheiro efetivamente saiu do caixa/conta. |
| `conta_id` | integer, FK | Qual tipo de conta foi paga (referência ao catálogo `dim_contas_a_pagar`). |
| `valor_pago` | numeric | Montante financeiro total quitado. |

> **Relacionamentos:** Conectada via FK com `dim_date` e `dim_contas_a_pagar`.

---

#### `fct_cashback_movimentacao`
**Finalidade:** Funciona como o **Ledger (extrato) do programa de cashback**. Toda concessão de novos créditos, uso de pontos para resgate em pedidos ou expiração de prazos vira um evento individual nesta fato. Permite saber com exatidão a auditoria do saldo de cada cliente sem risco de inconformidades.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `movimentacao_cashback_id` | integer, PK | Identificador único do evento no cashback. |
| `cliente_id` | integer, FK | Cliente proprietário da movimentação. |
| `date_id` | integer, FK | Data do evento. |
| `tipo_movimentacao` | varchar | Operação do saldo (`CREDITO`, `USO`, `EXPIRADO`). |
| `valor` | numeric | Valor em reais concedido, resgatado ou expirado. |
| `data_expiracao` | date | Prazo limite de utilização do crédito (preenchido com validade de 60 dias quando o evento for `CREDITO`). |
| `pedido_origem_id` | integer, FK | ID do pedido em `fct_vendas` que deu origem à concessão do cashback (se aplicável). |

> **Relacionamentos:** Relacionada a `dim_clientes`, `dim_date` e `fct_vendas`. O saldo ativo do cliente é descoberto aplicando a soma dos créditos não expirados versus as utilizações em views.

---

#### `fct_perdas_desperdicio`
**Finalidade:** Tabela reservada para lançamentos pontuais de desperdícios da cozinha (insumos vencidos, descartes de produção ou quebras operacionais). O registro correto dessa tabela evita descompasso entre o CMV teórico (calculado nas vendas) e o CMV real do balanço.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `perda_id` | integer, PK | Identificador do lançamento de perda. |
| `date_id` | integer, FK | Data do evento. |
| `insumo_id` | integer | Matéria-prima descartada. |
| `quantidade` | numeric | Quantidade física descartada do insumo. |
| `motivo` | varchar | Razão do descarte (`VENCIDO`, `QUEBRA`, `ERRO_PRODUCAO`). |
| `observacao` | text | Detalhes contextuais sobre o descarte. |

> **Relacionamentos:** Conectada a `dim_date` via FK e com ligação lógica a `dim_insumos`. Alimenta a tabela `fct_movimentacao_estoque` gerando saídas por perda.

---

#### `fct_fechamento_caixa`
**Finalidade:** Auditoria e conferência diária do caixa físico em espécie do restaurante. Permite bater se a quantidade de dinheiro na gaveta bate exatamente com os valores apurados pelas vendas no sistema.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `fechamento_id` | integer, PK | Identificador do fechamento de caixa. |
| `date_id` | integer, FK, UNIQUE | Data da operação (contém trava de unicidade para permitir estritamente **um fechamento por dia**). |
| `valor_dinheiro_esperado` | numeric | Montante do caixa calculado somando as vendas em dinheiro no sistema. |
| `valor_dinheiro_contado` | numeric | Valor em cédulas e moedas contado manualmente ao encerrar o expediente. |
| `diferenca` | numeric | Resultado do cálculo: `valor_dinheiro_contado` − `valor_dinheiro_esperado`. |
| `observacao` | text | Justificativas para eventuais quebras de caixa. |

> **Relacionamentos:** Possui FK para a dimensão de data (`dim_date`).

---

### Camada Silver — Fatos de Snapshot Histórico (Carga Única)

Tabelas do modelo reservadas exclusivamente para abrigar a carga histórica consolidada da operação prévia ao DW (período de 14 meses entre **Junho/2025 e Julho/2026**). Como esses dados da fase inicial do restaurante só existiam em fechamentos mensais no Excel, foram estruturados em tabelas de snapshot estáticas. Elas garantem visibilidade histórica sem poluir as tabelas do tracking transacional diário.

#### `fct_resumo_mensal_historico`
**Finalidade:** Guarda a fotografia mensal fechada com as métricas gerais do negócio, sem quebras por canais.

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `resumo_id` | integer, PK | Identificador do mês histórico. |
| `ano_mes` | varchar, UNIQUE | Chave do período no formato `YYYY-MM`. |
| `dias_trabalhados` | smallint | Total de dias em que o restaurante operou no mês. |
| `vendas_ifood`, `vendas_balcao` | numeric | Faturamento agrupado entre iFood e Vendas Presenciais. |
| `total_pedidos` | integer | Volume total de pedidos entregues no mês. |
| `faturamento_bruto` | numeric | Faturamento consolidado (já descontadas as taxas e cupons de plataforma). É a base primária para o cálculo percentual do CMV. |
| `repasse_liquidado` | numeric | Valor líquido final depositado em conta pelas plataformas de delivery. |
| `insumo_teorico` | numeric | Custo projetado das matérias-primas do mês com base nas fichas técnicas. |
| `insumos_comprados` | numeric | Total de dinheiro pago no mês para aquisição de insumos (regime de caixa). |
| `custo_fixo`, `custo_variavel`, `gastos_casa` | numeric | Despesas agregadas da operação no mês. |
| `lucro_liquido` | numeric, **coluna gerada** | Resultado do negócio calculado automaticamente pela fórmula física do banco: <br>`repasse_liquidado + vendas_balcao − insumos_comprados − custo_fixo − custo_variavel − gastos_casa` |

> **Relacionamentos:** Tabela em snapshot isolada propositalmente. Não exige FKs por se tratar de um histórico fechado.

---

#### `fct_resumo_mensal_canal_historico`
**Finalidade:** Guarda a mesma fotografia mensal dos 14 meses históricos, porém **detalhada linha a linha por canal de venda**. Essa tabela foi criada para desembrulhar os dados antigos e manter separadas as operações de iFood Loja 1, iFood Loja 2 e Balcão (que no modelo antigo ficavam em colunas agregadas).

| Coluna | Tipo | Pra que serve |
| :--- | :--- | :--- |
| `resumo_canal_id` | integer, PK | Identificador do registro mensal do canal. |
| `ano_mes` | varchar | Período de apuração no formato `YYYY-MM`. |
| `canal_id` | integer, FK | Canal a que se refere a linha (iFood 1, iFood 2, Balcão...). |
| `taxas_comissoes` | numeric | Comissões operacionais descontadas pelo canal no mês. |
| `promocoes_cupons` | numeric | Total investido em cupons promocionais dentro daquele canal. |
| `gastos_sobdemanda`, `pedidos_sobdemanda` | numeric/integer | Custo e frequência do uso de entregadores parceiros por corrida. Base de dados útil para calcular se vale mais a pena ter motoboy fixo ou usar sob demanda. |
| `gastos_anuncio` | numeric | Valor investido em publicidade no canal (ex: iFood Ads) para avaliação do retorno sobre o investimento. |
| `faturamento_bruto`, `repasse_liquidado`, `total_pedidos` | numeric/integer | Métricas consolidadas do canal no mês. |

> **Relacionamentos:** Possui FK conectando com `dim_canal_vendas`. A integridade dos dados históricos é assegurada através da constraint de unicidade nos campos `(ano_mes, canal_id)`.

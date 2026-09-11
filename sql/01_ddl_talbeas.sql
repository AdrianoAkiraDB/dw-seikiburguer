-- 1. Dimensão de Canais de Vendas
CREATE TABLE IF NOT EXISTS dim_canal_vendas (
    canal_id SERIAL PRIMARY KEY,
    nome_canal VARCHAR(50) NOT NULL UNIQUE,
    tipo_canal VARCHAR(30) NOT NULL -- Ex: 'Delivery App', 'Presencial'
);

-- Inserindo os canais padrão do negócio
INSERT INTO dim_canal_vendas (nome_canal, tipo_canal) VALUES
('iFood 1', 'Delivery App'),
('iFood 2', 'Delivery App'),
('Balcão', 'Presencial')
ON CONFLICT (nome_canal) DO NOTHING;

-- 2. Fato de Vendas e Desempenho por Canal
CREATE TABLE IF NOT EXISTS fct_vendas_mensal (
    venda_id SERIAL PRIMARY KEY,
    data DATE NOT NULL,
    canal_id INT REFERENCES dim_canal_vendas(canal_id),
    faturamento_bruto NUMERIC(10,2) DEFAULT 0,
    repasse_liquidado NUMERIC(10,2) DEFAULT 0,
    taxas_comissoes NUMERIC(10,2) DEFAULT 0,
    promocoes_cupons NUMERIC(10,2) DEFAULT 0,
    gastos_sobdemanda NUMERIC(10,2) DEFAULT 0,
    pedidos_sobdemanda INT DEFAULT 0,
    gastos_anuncio NUMERIC(10,2) DEFAULT 0,
    total_pedidos INT DEFAULT 0
);

-- 3. Fato de Custos Operacionais e DRE Consolidada
CREATE TABLE IF NOT EXISTS fct_custos_operacionais (
    custo_id SERIAL PRIMARY KEY,
    data DATE UNIQUE NOT NULL,
    insumos_cmv NUMERIC(10,2) DEFAULT 0,
    custo_fixo NUMERIC(10,2) DEFAULT 0,
    custo_variavel NUMERIC(10,2) DEFAULT 0,
    gastos_casa NUMERIC(10,2) DEFAULT 0,
    horas_trabalhadas NUMERIC(6,2) DEFAULT 0,
    dias_trabalhados INT DEFAULT 0
);




-- Exemplo de como inserir os custos do mês
-- Você pode adaptar ou colar os valores do seu histórico:
INSERT INTO fct_custos_operacionais 
(data, insumos_cmv, custo_fixo, custo_variavel, gastos_casa, horas_trabalhadas, dias_trabalhados)
VALUES 
('2025-07-01', 9705.26, 2422.94, 2021.57, 4516.02, 271.67, 25),

('2025-08-01', 7779.39, 2832.06, 1542.91, 4134.76, 296.00, 27),

('2025-09-01', 8864.06, 3379.80, 2240.85, 3436.09, 278.17, 25),

('2025-10-01', 8614.31, 3186.23, 1865.96, 4299.70, 302.05, 27),

('2025-11-01', 5369.67, 3757.26, 1010.97, 3577.28, 283.83, 26),

('2025-12-01', 5533.17, 2769.08, 625.32, 4451.68, 229.5, 21),

('2026-01-01', 8313.83, 2904.15, 1987.74, 3799.50, 290.33, 26),

('2026-02-01', 6536.60, 3119.81, 1598.85, 3396.93, 266, 24),

('2026-03-01', 7910.32, 2965.44, 2652.14, 3168.84, 283.83, 26),

('2026-04-01', 7424.96, 3160.43, 2530.00, 2778.31, 290.33, 26),

('2026-05-01', 4453.77, 3412.62, 2089.05, 2504.07, 253.83, 23),

('2026-06-01', 3884.073, 3452.03, 699.01, 1477.03, 121.83, 17),

('2026-07-01', 7196.04, 3450.08, 4457.95, 3140.22, 193.5, 27);


DROP TABLE IF EXISTS fct_vendas_mensal CASCADE;

CREATE TABLE fct_vendas_mensal (
    venda_id SERIAL PRIMARY KEY,
    data DATE NOT NULL,
    canal_id INT REFERENCES dim_canal_vendas(canal_id),
    taxas_comissoes NUMERIC(10,2) DEFAULT 0,
    promocoes_cupons NUMERIC(10,2) DEFAULT 0,
    gastos_sobdemanda NUMERIC(10,2) DEFAULT 0,
    pedidos_sobdemanda INT DEFAULT 0,
    gastos_anuncio NUMERIC(10,2) DEFAULT 0,
    faturamento_bruto NUMERIC(10,2) DEFAULT 0,
    repasse_liquidado NUMERIC(10,2) DEFAULT 0,
    total_pedidos INT DEFAULT 0
);



-- Exemplo para o mês 06/2025:
-- Canal 1: iFood 1 | Canal 2: iFood 2 | Canal 3: Balcão

INSERT INTO fct_vendas_mensal 
(data, canal_id, faturamento_bruto, taxas_comissoes, promocoes_cupons, gastos_sobdemanda, pedidos_sobdemanda, gastos_anuncio, total_pedidos)
VALUES 
-- iFood 1 (canal_id = 1)
('2025-06-01', 1, 19862.45, 2406.88, 4520.23, 716.10, 51, 0.00, 471),

-- iFood 2 (canal_id = 2)
('2025-06-01', 2, 0.00, 0.00, 0.00, 0.00, 0, 0.00, 0),

-- Balcão (canal_id = 3)
('2025-06-01', 3, 27500.00, 0.00, 0.00, 0.00, 0, 0.00, 144);


-- =========================================================================
-- atualizacao da fct_vendas porque estava dando erro ao rodar stg_vendas_raw com pedido_id 
-- =========================================================================

ALTER TABLE fct_vendas 
ALTER COLUMN pedido_id DROP IDENTITY IF EXISTS;



-- =========================================================================
/* atualizacao da fct_itens_pedido estava dando erro stg_vendas_raw procedure buscando produto_id sendo 
que estava produto_sk */
-- =========================================================================


ALTER TABLE fct_itens_pedido 
RENAME COLUMN produto_id TO produto_sk;

-- deu mesmo erro da fct_itens_pedido insumo_sk para insumo_id
ALTER TABLE fct_movimentacao_estoque 
RENAME COLUMN insumo_id TO insumo_sk;

-- erro por tamanho de caracteres antes era VARCHAR(15) agora atualizado VARCHAR(50)
ALTER TABLE fct_movimentacao_estoque 
ALTER COLUMN tipo_movimentacao TYPE VARCHAR(50),
ALTER COLUMN origem_tipo TYPE VARCHAR(50);

-- =========================================================================
-- 
-- =========================================================================

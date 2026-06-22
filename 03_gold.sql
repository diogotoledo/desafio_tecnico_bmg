-- =============================================================
-- CAMADA GOLD — Curated Layer
-- Objetivo: Agregações otimizadas para consumo analítico direto.
-- Regras: particionamento lógico, agregações e caching.
-- Fonte: silver_beneficiarios.parquet
-- =============================================================

CREATE SCHEMA IF NOT EXISTS gold;


-- -------------------------------------------------------------
-- TABELA BASE: dados pré-agregados na menor granularidade útil
-- Particionamento lógico: ORDER BY dt_competencia garante
-- locality of reference para scans temporais (padrão Parquet/Iceberg).
-- -------------------------------------------------------------
CREATE OR REPLACE TABLE gold.tb_beneficiarios_anl AS
SELECT
    dt_competencia,
    cd_operadora,
    nm_razao_social,
    modalidade_operadora,
    cd_municipio,
    nm_municipio,
    sg_uf,
    cd_plano,
    tp_sexo,
    faixa_etaria,
    tipo_vinculo,
    SUM(qtd_beneficiario_ativo)      AS qtd_beneficiario_ativo,
    SUM(qtd_beneficiario_aderido)    AS qtd_beneficiario_aderido,
    SUM(qtd_beneficiario_cancelado)  AS qtd_beneficiario_cancelado
FROM read_parquet('C:/work/BMG/tb_beneficiarios_stg.parquet')
GROUP BY
	dt_competencia,
    cd_operadora,
    nm_razao_social,
    modalidade_operadora,
    cd_municipio,
    nm_municipio,
    sg_uf,
    cd_plano,
    tp_sexo,
    faixa_etaria,
    tipo_vinculo
ORDER BY dt_competencia, cd_operadora, cd_municipio;


-- -------------------------------------------------------------
-- CACHING — Agregações pré-computadas por tema analítico
-- Evita full scans repetidos na fact_beneficiarios a cada consulta
-- -------------------------------------------------------------

-- Cache A: beneficiários por operadora
CREATE OR REPLACE TABLE gold.tb_operadora_anl_agg AS
SELECT
    cd_operadora,
    nm_razao_social,
    modalidade_operadora,
    SUM(qtd_beneficiario_ativo)      AS total_beneficiarios_ativos,
    SUM(qtd_beneficiario_cancelado)  AS total_cancelados
FROM gold.tb_beneficiarios_anl
GROUP BY cd_operadora, nm_razao_social, modalidade_operadora
ORDER BY total_beneficiarios_ativos DESC;


-- Cache B: beneficiários por faixa etária
CREATE OR REPLACE TABLE gold.tb_faixa_etaria_anl_agg AS
SELECT
    faixa_etaria,
    SUM(qtd_beneficiario_ativo)      AS total_beneficiarios_ativos
FROM gold.tb_beneficiarios_anl
GROUP BY faixa_etaria
ORDER BY total_beneficiarios_ativos DESC;


-- Cache C: beneficiários por município
CREATE OR REPLACE TABLE gold.tb_municipio_anl_agg AS
SELECT
    cd_municipio,
    nm_municipio,
    sg_uf,
    SUM(qtd_beneficiario_ativo)      AS total_beneficiarios_ativos
FROM gold.tb_beneficiarios_anl
GROUP BY cd_municipio, nm_municipio, sg_uf
ORDER BY total_beneficiarios_ativos DESC;
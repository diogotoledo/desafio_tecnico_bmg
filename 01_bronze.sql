-- =============================================================
-- CAMADA BRONZE — Raw Layer
-- Objetivo: Ingestão do arquivo original sem transformações.
-- Fonte: ANS - Informações Consolidadas de Beneficiários (TO)
-- Competência: 2025-08
-- =============================================================

CREATE SCHEMA IF NOT EXISTS bronze;

-- Tabela raw com todas as colunas tipadas como VARCHAR (as-is)
CREATE OR REPLACE TABLE bronze.tb_beneficiarios_raw AS
SELECT
    ID_CMPT_MOVEL,
    CD_OPERADORA,
    NM_RAZAO_SOCIAL,
    NR_CNPJ,
    MODALIDADE_OPERADORA,
    SG_UF,
    CD_MUNICIPIO,
    NM_MUNICIPIO,
    TP_SEXO,
    DE_FAIXA_ETARIA,
    DE_FAIXA_ETARIA_REAJ,
    CD_PLANO,
    TP_VIGENCIA_PLANO,
    DE_CONTRATACAO_PLANO,
    DE_SEGMENTACAO_PLANO,
    DE_ABRG_GEOGRAFICA_PLANO,
    COBERTURA_ASSIST_PLAN,
    TIPO_VINCULO,
    QT_BENEFICIARIO_ATIVO,
    QT_BENEFICIARIO_ADERIDO,
    QT_BENEFICIARIO_CANCELADO,
    DT_CARGA
FROM read_csv_auto(
    'C:/work/BMG/pda-024-icb-TO-2025_08.csv',
    sep=';',
    header=True,
    quote='"',
    encoding='UTF-8'
);
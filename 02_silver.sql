-- =============================================================
-- CAMADA SILVER — Refined Layer
-- Objetivo: Tipagem correta, limpeza e padronização dos dados.
-- Fonte: bronze.beneficiarios_raw
-- =============================================================

CREATE SCHEMA IF NOT EXISTS silver;

CREATE OR REPLACE TABLE silver.tb_beneficiarios_stg AS
SELECT
    STRPTIME(CAST(ID_CMPT_MOVEL AS VARCHAR), '%Y-%m')::DATE         AS dt_competencia,
    TRIM(CAST(CD_OPERADORA         AS VARCHAR))                     AS cd_operadora,
    TRIM(CAST(NM_RAZAO_SOCIAL      AS VARCHAR))                     AS nm_razao_social,
    -- CNPJ mascarado: mantém raiz (8 dígitos), oculta filial e verificadores
    REGEXP_REPLACE(
        CAST(NR_CNPJ AS VARCHAR),
        '(\d{8})\d{6}',
        '\1******'
    )                                                               AS nr_cnpj,
    TRIM(CAST(MODALIDADE_OPERADORA AS VARCHAR))                     AS modalidade_operadora,
    TRIM(CAST(SG_UF                 AS VARCHAR))                    AS sg_uf,
    TRIM(CAST(CD_MUNICIPIO          AS VARCHAR))                    AS cd_municipio,
    TRIM(CAST(NM_MUNICIPIO          AS VARCHAR))                    AS nm_municipio,
    TRIM(CAST(TP_SEXO               AS VARCHAR))                    AS tp_sexo,
    TRIM(CAST(DE_FAIXA_ETARIA       AS VARCHAR))                    AS faixa_etaria,
    TRIM(CAST(DE_FAIXA_ETARIA_REAJ  AS VARCHAR))                    AS faixa_etaria_reajuste,
    TRIM(CAST(CD_PLANO              AS VARCHAR))                    AS cd_plano,
    TRIM(CAST(TP_VIGENCIA_PLANO     AS VARCHAR))                    AS tp_vigencia_plano,
    TRIM(CAST(DE_CONTRATACAO_PLANO  AS VARCHAR))                    AS ds_contratacao_plano,
    TRIM(CAST(DE_SEGMENTACAO_PLANO  AS VARCHAR))                    AS ds_segmentacao_plano,
    TRIM(CAST(DE_ABRG_GEOGRAFICA_PLANO AS VARCHAR))                 AS ds_abrg_geografica_plano,
    TRIM(CAST(COBERTURA_ASSIST_PLAN AS VARCHAR))                    AS cobertura_assist_plano,
    TRIM(CAST(TIPO_VINCULO          AS VARCHAR))                    AS tipo_vinculo,
    COALESCE(TRY_CAST(QT_BENEFICIARIO_ATIVO     AS INTEGER), 0)     AS qtd_beneficiario_ativo,
    COALESCE(TRY_CAST(QT_BENEFICIARIO_ADERIDO   AS INTEGER), 0)     AS qtd_beneficiario_aderido,
    COALESCE(TRY_CAST(QT_BENEFICIARIO_CANCELADO AS INTEGER), 0)     AS qtd_beneficiario_cancelado,
    TRY_CAST(DT_CARGA AS DATE)                                      AS dt_carga
FROM bronze.tb_beneficiarios_raw
	WHERE CAST(CD_OPERADORA AS VARCHAR) IS NOT NULL
  	AND CAST(NM_MUNICIPIO  AS VARCHAR) IS NOT NULL;
  	

-- =============================================================
-- SILVER — Exportação para Parquet (formato colunar)
-- Simula o armazenamento em Data Lake (ex: S3, ADLS, GCS)
-- =============================================================

COPY silver.tb_beneficiarios_stg
TO 'C:/work/BMG/tb_beneficiarios_stg.parquet'
(FORMAT PARQUET, COMPRESSION SNAPPY);

-- Verificação
SELECT COUNT(*) AS total_registros
FROM read_parquet('C:/work/BMG/tb_beneficiarios_stg.parquet');
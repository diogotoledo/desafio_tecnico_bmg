-- =============================================================
-- CONSULTAS ANALÍTICAS — lêem do cache (sem full scan na fato)
-- =============================================================

-- a) Top 5 operadoras com maior número de beneficiários ativos
SELECT cd_operadora, nm_razao_social, total_beneficiarios_ativos
FROM gold.tb_operadora_anl_agg
LIMIT 5;

-- b) Faixa etária com mais beneficiários ativos
SELECT faixa_etaria, total_beneficiarios_ativos
FROM gold.tb_faixa_etaria_anl_agg
LIMIT 1;

-- c) Beneficiários por município em ordem decrescente
SELECT cd_municipio, nm_municipio, total_beneficiarios_ativos
FROM gold.tb_municipio_anl_agg;
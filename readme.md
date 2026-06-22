# Pipeline de Dados — Beneficiários ANS (Tocantins)

**Desafio Técnico — Engenheiro de Dados | BMG**

---

## Visão Geral

Este projeto implementa um pipeline de dados seguindo a **arquitetura Medallion** (Bronze → Silver → Gold), utilizando SQL via **DuckDB**. Os dados são provenientes da ANS (Agência Nacional de Saúde Suplementar) e contêm informações de operadoras e beneficiários de planos de saúde do estado do Tocantins, competência **2025-08**.

**Fonte dos dados:**
https://dadosabertos.ans.gov.br/FTP/PDA/informacoes_consolidadas_de_beneficiarios-024/202508/pda-024-icb-TO-2025_08.zip

---

## Arquitetura

```
[CSV - ANS]
     │
     ▼
┌──────────────────────────────────────────────┐
│  BRONZE — Raw Layer                          │
│  bronze.tb_beneficiarios_raw                 │
│  Ingestão as-is, sem transformações          │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│  SILVER — Refined Layer                      │
│  silver.tb_beneficiarios_stg                 │
│  Tipagem, limpeza, mascaramento CNPJ         │
│  Exportação → tb_beneficiarios_stg.parquet   │
└──────────────────────┬───────────────────────┘
                       │ (lê do .parquet)
                       ▼
┌──────────────────────────────────────────────┐
│  GOLD — Curated Layer                        │
│  gold.tb_beneficiarios_anl    (tabela base)  │
│  gold.tb_operadora_anl_agg    (cache)        │
│  gold.tb_faixa_etaria_anl_agg (cache)        │
│  gold.tb_municipio_anl_agg    (cache)        │
│  Particionamento lógico + agregações         │
└──────────────────────────────────────────────┘
```

---

## Estrutura do Projeto

```
bmg_teste/
├── 01_bronze.sql                    # Ingestão raw do CSV
├── 02_silver.sql                    # Refinamento, tipagem e exportação Parquet
├── 03_gold.sql                      # Tabela base, caching e agregações analíticas
├── 04_respostas_teste.sql           # Consultas analíticas finais
├── pda-024-icb-TO-2025_08.csv       # Arquivo fonte (ANS)
├── tb_beneficiarios_stg.parquet     # Gerado pelo script Silver
└── README.md                        # Este documento
```

---

## Camadas do Pipeline

### 🥉 Bronze — Raw Layer

**Objetivo:** Preservar o dado original sem nenhuma transformação.

**Tabela:** `bronze.tb_beneficiarios_raw`

- Ingestão direta do CSV via `read_csv_auto` com separador `;`, `quote='"'` e encoding UTF-8
- Todas as colunas mantidas com tipos inferidos automaticamente pelo DuckDB
- Nenhuma regra de negócio aplicada — serve como fonte de verdade auditável da carga original
- Permite reprocessamento completo das camadas subsequentes a qualquer momento

---

### 🥈 Silver — Refined Layer

**Objetivo:** Converter, limpar, tipar e padronizar os dados para consumo seguro.

**Tabela:** `silver.tb_beneficiarios_stg`

**Transformações aplicadas:**

| Coluna original | Coluna Silver | Transformação |
|----------------|---------------|---------------|
| `ID_CMPT_MOVEL` | `dt_competencia` | `STRPTIME` → `DATE` (ex: `2025-08` → `2025-08-01`) |
| `NR_CNPJ` | `nr_cnpj` | Mascaramento: mantém raiz (8 dígitos), oculta filial e verificadores (ex: `19962272******`) |
| `DE_FAIXA_ETARIA` | `faixa_etaria` | `TRIM + CAST VARCHAR` |
| `QT_BENEFICIARIO_*` | `qtd_beneficiario_*` | `TRY_CAST AS INTEGER` + `COALESCE(..., 0)` |
| `DT_CARGA` | `dt_carga` | `TRY_CAST AS DATE` |
| Todas as strings | — | `TRIM(CAST(... AS VARCHAR))` para remover espaços e normalizar tipos |
| Linhas inválidas | — | Filtro `WHERE cd_operadora IS NOT NULL AND nm_municipio IS NOT NULL` |

**Sobre o mascaramento (LGPD):**
O campo `NR_CNPJ`, embora seja dado público, é mascarado parcialmente como boa prática de governança de dados em contexto financeiro — seguindo o princípio de menor privilégio. Os campos `faixa_etaria` e `tp_sexo` representam agregações populacionais sem identificação individual, portanto não requerem mascaramento neste contexto.

**Formato de saída:** Parquet com compressão SNAPPY
```sql
COPY silver.tb_beneficiarios_stg
TO 'C:/work/BMG/tb_beneficiarios_stg.parquet'
(FORMAT PARQUET, COMPRESSION SNAPPY);
```

> A compressão SNAPPY foi escolhida por oferecer melhor equilíbrio entre velocidade de leitura e taxa de compressão — padrão de mercado em Data Lakes (S3, ADLS, GCS).

- Total de registros: **84.175**
- Nulos em operadora: **0**
- Nulos em município: **0**
- Registros com `qtd_beneficiario_ativo = 0`: **1.360** (esperado — aderidos/cancelados sem ativos)

---

### 🥇 Gold — Curated Layer

**Objetivo:** Dados otimizados para consumo analítico direto, com aplicação de regras de performance.

#### Tabela Base

**`gold.tb_beneficiarios_anl`** — granularidade mínima útil para análise, com métricas pré-somadas.

Lê diretamente do arquivo Parquet da Silver, aplicando `GROUP BY` explícito por todas as dimensões analíticas e `ORDER BY dt_competencia, cd_operadora, cd_municipio` para particionamento lógico.

**Regras de performance aplicadas:**

| Regra | Implementação |
|-------|---------------|
| **Agregações** | `GROUP BY` por todas as dimensões + `SUM()` nas métricas — reduz linhas brutas à menor granularidade necessária |
| **Particionamento lógico** | `ORDER BY dt_competencia, cd_operadora, cd_municipio` — organiza dados fisicamente por período, otimizando scans temporais (equivalente ao partition pruning em Spark/Iceberg/Parquet) |
| **Caching** | Tabelas `_agg` pré-computam resultados das consultas mais frequentes, eliminando full scans repetidos na tabela base |

#### Tabelas de Cache

| Tabela | Descrição |
|--------|-----------|
| `gold.tb_operadora_anl_agg` | Beneficiários e cancelados totais por operadora, pré-ordenado por volume |
| `gold.tb_faixa_etaria_anl_agg` | Beneficiários totais por faixa etária, pré-ordenado por volume |
| `gold.tb_municipio_anl_agg` | Beneficiários totais por município + UF, pré-ordenado por volume |

---

## Consultas Analíticas

As consultas (`04_respostas_teste.sql`) lêem exclusivamente das tabelas de cache da Gold — sem full scans, sem agregações em tempo de execução.

### a) Top 5 operadoras com maior número de beneficiários ativos
```sql
SELECT cd_operadora, nm_razao_social, total_beneficiarios_ativos
FROM gold.tb_operadora_anl_agg
LIMIT 5;
```

### b) Faixa etária com mais beneficiários ativos
```sql
SELECT faixa_etaria, total_beneficiarios_ativos
FROM gold.tb_faixa_etaria_anl_agg
LIMIT 1;
```

### c) Beneficiários por município em ordem decrescente
```sql
SELECT cd_municipio, nm_municipio, total_beneficiarios_ativos
FROM gold.tb_municipio_anl_agg;
```

> **Nota:** As consultas utilizam `SUM(qtd_beneficiario_ativo)` e não `COUNT(*)` pois a coluna representa a quantidade de pessoas — não o número de linhas. Cada linha agrega múltiplos beneficiários de uma mesma combinação operadora/município/plano/faixa etária.

---

## Tecnologias Utilizadas

| Tecnologia | Uso |
|------------|-----|
| **DuckDB** | Engine SQL embarcada para processamento local sem infraestrutura |
| **Parquet + SNAPPY** | Formato colunar para persistência da camada Silver |
| **DBeaver** | Interface SQL para execução e visualização dos resultados |
| **SQL** | Linguagem principal do pipeline |

---

## Como Executar

1. Instale o DuckDB ou conecte via DBeaver (driver JDBC DuckDB `org.duckdb:duckdb_jdbc:1.1.0`)
2. Crie uma conexão apontando para um arquivo `.duckdb` em uma pasta com permissão de escrita (ex: `C:/...caminho/BMG/bmg.duckdb`)
3. Coloque o arquivo CSV na mesma pasta (`C:/...caminho/BMG/`)
4. Execute os scripts na ordem:

```
01_bronze.sql → 02_silver.sql → 03_gold.sql → 04_respostas_teste.sql
```

5. O arquivo `tb_beneficiarios_stg.parquet` será gerado automaticamente pelo script Silver
6. O script `04_respostas_teste.sql` retorna os resultados das 3 consultas do teste

---

## Modularidade

O pipeline foi estruturado seguindo o princípio de **responsabilidade única**:

- Cada script tem um único objetivo — ingerir, refinar, agregar ou consultar
- Cada tabela de cache da Gold responde a um único tema analítico
- Alterações em uma camada não impactam as demais
- Novas análises podem ser adicionadas como novas tabelas `_agg` sem modificar o que já existe
- Em produção, cada script seria uma task independente em uma DAG do Airflow

---

## Decisões de Arquitetura

- **DuckDB** foi escolhido por suportar leitura nativa de CSV e Parquet via SQL puro, sem dependências externas — garantindo reprodutibilidade total do teste
- **Parquet com SNAPPY** é o padrão de mercado em Data Lakes (AWS S3, Azure ADLS, GCS) pela combinação de leitura colunar rápida e compressão eficiente
- **Tabelas desnormalizadas na Gold** seguem o padrão de Data Lakes modernos (Databricks, BigQuery, Redshift), onde o custo de leitura colunar torna JOINs desnecessários e tabelas largas e flat são mais eficientes
- **Tabelas `_agg` como cache** simulam views materializadas — padrão em Databricks (Delta Live Tables) e BigQuery (Materialized Views) — onde o custo de agregação é pago uma vez na carga e não a cada consulta
- **Mascaramento de CNPJ** aplica o princípio de menor privilégio, demonstrando atenção à LGPD e governança de dados em contexto de instituição financeira

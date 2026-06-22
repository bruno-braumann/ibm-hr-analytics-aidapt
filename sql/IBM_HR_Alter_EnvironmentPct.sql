-- ================================================================================
-- SCRIPT DE ALTERAÇÃO: Adicionar environment_satisfaction_pct
-- Tabela: f_satisfaction
-- Objetivo: Adicionar coluna de percentagem para environment_satisfaction
-- ================================================================================

-- IMPORTANTE: Este script adiciona uma nova coluna a uma tabela existente
-- Certifica-te que tens backup da base de dados antes de executar!

-- ================================================================================
-- PASSO 1: VERIFICAR ESTRUTURA ATUAL DA TABELA
-- ================================================================================

-- Ver as colunas atuais da tabela f_satisfaction
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'f_satisfaction'
ORDER BY ORDINAL_POSITION;

-- ================================================================================
-- PASSO 2: ADICIONAR A NOVA COLUNA environment_satisfaction_pct
-- ================================================================================

-- Adicionar coluna de percentagem para environment_satisfaction
ALTER TABLE f_satisfaction
ADD environment_satisfaction_pct DECIMAL(5,2);

-- NOTA: A coluna é criada com valores NULL inicialmente
-- Será preenchida no próximo passo

-- ================================================================================
-- PASSO 3: CALCULAR E PREENCHER OS VALORES DA NOVA COLUNA
-- ================================================================================

-- Calcular environment_satisfaction_pct (normalizar 1-4 para 0-100%)
-- Fórmula: ((valor - 1) * 100) / (4 - 1) = ((valor - 1) * 100) / 3
-- Valor 1 = 0%, Valor 2 = 33.33%, Valor 3 = 66.67%, Valor 4 = 100%

UPDATE f_satisfaction
SET environment_satisfaction_pct = 
    CAST(((environment_satisfaction - 1) * 100.0 / 3) AS DECIMAL(5,2))
WHERE environment_satisfaction IS NOT NULL;

-- ================================================================================
-- PASSO 4: VERIFICAR OS RESULTADOS
-- ================================================================================

-- Ver exemplos de dados com a nova coluna
SELECT TOP 20
    employee_number,
    environment_satisfaction,
    environment_satisfaction_pct,
    environment_satisfaction_label,
    job_satisfaction,
    job_satisfaction_pct
FROM f_satisfaction
ORDER BY employee_number;

-- Verificar distribuição de valores
SELECT 
    environment_satisfaction,
    environment_satisfaction_pct,
    environment_satisfaction_label,
    COUNT(*) AS total_funcionarios
FROM f_satisfaction
GROUP BY environment_satisfaction, environment_satisfaction_pct, environment_satisfaction_label
ORDER BY environment_satisfaction;

-- Resultado esperado:
-- 1 | 0.00   | Low       | ~XXX funcionários
-- 2 | 33.33  | Medium    | ~XXX funcionários
-- 3 | 66.67  | High      | ~XXX funcionários
-- 4 | 100.00 | Very High | ~XXX funcionários

-- ================================================================================
-- PASSO 5: VERIFICAR CONSISTÊNCIA COM job_satisfaction_pct
-- ================================================================================

-- Comparar as duas métricas de percentagem
SELECT 
    'job_satisfaction_pct' AS metrica,
    AVG(job_satisfaction_pct) AS media_pct,
    MIN(job_satisfaction_pct) AS min_pct,
    MAX(job_satisfaction_pct) AS max_pct
FROM f_satisfaction
UNION ALL
SELECT 
    'environment_satisfaction_pct' AS metrica,
    AVG(environment_satisfaction_pct) AS media_pct,
    MIN(environment_satisfaction_pct) AS min_pct,
    MAX(environment_satisfaction_pct) AS max_pct
FROM f_satisfaction;

-- ================================================================================
-- PASSO 6 (OPCIONAL): VERIFICAR NOVA ESTRUTURA DA TABELA
-- ================================================================================

-- Confirmar que a coluna foi adicionada
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'f_satisfaction'
    AND COLUMN_NAME LIKE '%pct%'
ORDER BY ORDINAL_POSITION;

-- Resultado esperado:
-- job_satisfaction_pct         | decimal | 5 | 2 | YES
-- environment_satisfaction_pct | decimal | 5 | 2 | YES

-- ================================================================================
-- RESUMO DA ALTERAÇÃO
-- ================================================================================

/*
O QUE FOI ADICIONADO:

1. NOVA COLUNA: environment_satisfaction_pct DECIMAL(5,2)
   - Normaliza valores de 1-4 para 0-100%
   - Mesma lógica que job_satisfaction_pct

2. VALORES CALCULADOS:
   - environment_satisfaction = 1 → 0.00%
   - environment_satisfaction = 2 → 33.33%
   - environment_satisfaction = 3 → 66.67%
   - environment_satisfaction = 4 → 100.00%

3. CONSISTÊNCIA:
   - Agora f_satisfaction tem percentagens para as duas métricas principais
   - Alinhado com f_satisfaction_history
   - Facilita visualizações no Power BI

PRÓXIMOS PASSOS:
- Atualizar views que usam f_satisfaction para incluir a nova coluna
- Atualizar relatórios no Power BI se necessário
*/

-- ================================================================================
-- FIM DO SCRIPT
-- ================================================================================

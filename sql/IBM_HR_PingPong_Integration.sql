-- ================================================================================
-- INTEGRAÇÃO DO PINGPONGSURVEY NO SQL SERVER
-- Projeto: IBM HR Analytics - Group 4
-- Data: 11/02/2026
-- Objetivo: Integrar dados do survey pós-Ping Pong e permitir análise ANTES vs DEPOIS
-- ================================================================================

-- ================================================================================
-- PASSO 1: CRIAR TABELA STAGING PARA O PINGPONGSURVEY
-- ================================================================================

CREATE TABLE stg_pingpong_survey (
    employee_number INT,
    environment_satisfaction INT,
    job_involvement INT,
    job_satisfaction INT,
    relationship_satisfaction INT,
    work_life_balance INT,
    datasurvey DATE
);

-- ================================================================================
-- PASSO 2: IMPORTAR DADOS DO EXCEL
-- ================================================================================

-- OPÇÃO A: BULK INSERT (se converteste o Excel para CSV)
-- Substitui 'C:\path\to\PingPongSurvey.csv' pelo caminho real do ficheiro

BULK INSERT stg_pingpong_survey
FROM 'C:\Users\Formando\Desktop\Projeto 1\PingPongSurvey.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    TABLOCK
);

-- OPÇÃO B: Import Wizard
-- Bot. Direito na Base de Dados → Tasks → Import Flat File
-- Seleciona PingPongSurvey.xlsx ou .csv
-- Escolhe a tabela 'stg_pingpong_survey'
-- Clica em Finish

-- ================================================================================
-- PASSO 3: CRIAR TABELA DE HISTÓRICO DE SATISFAÇÃO
-- ================================================================================

CREATE TABLE f_satisfaction_history (
    satisfaction_history_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_number INT NOT NULL,
    survey_date DATE NOT NULL,
    environment_satisfaction INT,
    job_involvement INT,
    job_satisfaction INT,
    relationship_satisfaction INT,
    work_life_balance INT,
    survey_type VARCHAR(50), -- 'BASELINE' ou 'POST_PINGPONG'
    
    -- Colunas calculadas - Labels
    environment_satisfaction_label VARCHAR(50),
    job_involvement_label VARCHAR(50),
    job_satisfaction_label VARCHAR(50),
    relationship_satisfaction_label VARCHAR(50),
    work_life_balance_label VARCHAR(50),
    
    -- Colunas calculadas - Percentagens (apenas para métricas principais)
    environment_satisfaction_pct DECIMAL(5,2),
    job_satisfaction_pct DECIMAL(5,2),
    
    -- Foreign Key
    CONSTRAINT FK_satisfaction_history_employee 
        FOREIGN KEY (employee_number) 
        REFERENCES d_employee (employee_number)
);

-- ================================================================================
-- PASSO 4: INSERIR DADOS BASELINE (ANTES DO PING PONG)
-- ================================================================================

-- Inserir dados originais da tabela f_satisfaction como dados 'BASELINE'
-- Data de referência: 22/01/2026 (ANTES da introdução do Ping Pong)

INSERT INTO f_satisfaction_history (
    employee_number,
    survey_date,
    environment_satisfaction,
    job_involvement,
    job_satisfaction,
    relationship_satisfaction,
    work_life_balance,
    survey_type
)
SELECT DISTINCT
    fs.employee_number,
    '2026-01-22' AS survey_date, -- Data de referência ANTES
    fs.environment_satisfaction,
    fm.job_involvement, -- Job_involvement está em f_employee_movement
    fs.job_satisfaction,
    fs.relationship_satisfaction,
    fs.work_life_balance,
    'BASELINE' AS survey_type
FROM f_satisfaction fs
INNER JOIN (
    -- Garantir apenas 1 registo por funcionário em f_employee_movement
    SELECT DISTINCT employee_number, job_involvement
    FROM f_employee_movement
) fm ON fs.employee_number = fm.employee_number
INNER JOIN d_employee de 
    ON fs.employee_number = de.employee_number
WHERE de.attrition_flag = 0; -- Apenas funcionários ativos

-- Verificar inserção
SELECT COUNT(*) AS total_baseline 
FROM f_satisfaction_history 
WHERE survey_type = 'BASELINE';
-- Resultado esperado: ~1233 registos

-- ================================================================================
-- PASSO 5: INSERIR DADOS POST_PINGPONG (DEPOIS DO PING PONG)
-- ================================================================================

-- Inserir dados do PingPongSurvey como dados 'POST_PINGPONG'
-- Data: 04/02/2026 (DEPOIS da introdução do Ping Pong)

INSERT INTO f_satisfaction_history (
    employee_number,
    survey_date,
    environment_satisfaction,
    job_involvement,
    job_satisfaction,
    relationship_satisfaction,
    work_life_balance,
    survey_type
)
SELECT 
    employee_number,
    datasurvey,
    environment_satisfaction,
    job_involvement,
    job_satisfaction,
    relationship_satisfaction,
    work_life_balance,
    'POST_PINGPONG' AS survey_type
FROM stg_pingpong_survey;

-- Verificar inserção
SELECT COUNT(*) AS total_post_pingpong 
FROM f_satisfaction_history 
WHERE survey_type = 'POST_PINGPONG';
-- Resultado esperado: 1233 registos

-- Garantir que não há duplicados
SELECT 
    survey_type,
    COUNT(*) AS total
FROM f_satisfaction_history
GROUP BY survey_type;
-- Resultado esperado:
-- BASELINE      | 1233
-- POST_PINGPONG | 1233

-- ================================================================================
-- PASSO 6: CALCULAR COLUNAS DERIVADAS (LABELS)
-- ================================================================================

-- Atualizar environment_satisfaction_label
UPDATE f_satisfaction_history
SET environment_satisfaction_label = 
    CASE environment_satisfaction
        WHEN 1 THEN 'Low'
        WHEN 2 THEN 'Medium'
        WHEN 3 THEN 'High'
        WHEN 4 THEN 'Very High'
        ELSE 'Unknown'
    END;

-- Atualizar job_involvement_label
UPDATE f_satisfaction_history
SET job_involvement_label = 
    CASE job_involvement
        WHEN 1 THEN 'Low'
        WHEN 2 THEN 'Medium'
        WHEN 3 THEN 'High'
        WHEN 4 THEN 'Very High'
        ELSE 'Unknown'
    END;

-- Atualizar job_satisfaction_label
UPDATE f_satisfaction_history
SET job_satisfaction_label = 
    CASE job_satisfaction
        WHEN 1 THEN 'Low'
        WHEN 2 THEN 'Medium'
        WHEN 3 THEN 'High'
        WHEN 4 THEN 'Very High'
        ELSE 'Unknown'
    END;

-- Atualizar relationship_satisfaction_label
UPDATE f_satisfaction_history
SET relationship_satisfaction_label = 
    CASE relationship_satisfaction
        WHEN 1 THEN 'Low'
        WHEN 2 THEN 'Medium'
        WHEN 3 THEN 'High'
        WHEN 4 THEN 'Very High'
        ELSE 'Unknown'
    END;

-- Atualizar work_life_balance_label
UPDATE f_satisfaction_history
SET work_life_balance_label = 
    CASE work_life_balance
        WHEN 1 THEN 'Bad'
        WHEN 2 THEN 'Good'
        WHEN 3 THEN 'Better'
        WHEN 4 THEN 'Best'
        ELSE 'Unknown'
    END;

-- ----------------------------------------
-- CALCULAR PERCENTAGENS (normalizar 1-4 para 0-100%)
-- ----------------------------------------
-- Apenas para as métricas principais (consistente com o design original)
-- Fórmula: ((valor - 1) * 100) / (4 - 1) = ((valor - 1) * 100) / 3

-- Atualizar environment_satisfaction_pct
UPDATE f_satisfaction_history
SET environment_satisfaction_pct = 
    CAST(((environment_satisfaction - 1) * 100.0 / 3) AS DECIMAL(5,2));

-- Atualizar job_satisfaction_pct
UPDATE f_satisfaction_history
SET job_satisfaction_pct = 
    CAST(((job_satisfaction - 1) * 100.0 / 3) AS DECIMAL(5,2));

-- ================================================================================
-- PASSO 7: CRIAR VIEWS PARA ANÁLISE
-- ================================================================================

-- ----------------------------------------
-- VIEW 1: COMPARAÇÃO ANTES vs DEPOIS
-- ----------------------------------------
-- Esta view permite comparação direta lado-a-lado dos valores ANTES e DEPOIS
-- para cada funcionário, incluindo o cálculo do delta (diferença)

CREATE VIEW vw_pingpong_comparison AS
SELECT 
    e.employee_number,
    e.age,
    e.age_band,
    e.gender,
    e.marital_status,
    e.generation,
    d.department_name,
    jr.job_role_name,
    jr.job_level,
    jr.job_level_label,
    jr.is_manager,
    
    -- ANTES (BASELINE) - 22/01/2026
    baseline.environment_satisfaction AS env_sat_before,
    baseline.job_involvement AS job_inv_before,
    baseline.job_satisfaction AS job_sat_before,
    baseline.relationship_satisfaction AS rel_sat_before,
    baseline.work_life_balance AS wlb_before,
    
    -- DEPOIS (POST_PINGPONG) - 04/02/2026
    post.environment_satisfaction AS env_sat_after,
    post.job_involvement AS job_inv_after,
    post.job_satisfaction AS job_sat_after,
    post.relationship_satisfaction AS rel_sat_after,
    post.work_life_balance AS wlb_after,
    
    -- DIFERENÇAS (DELTA) - valores positivos = melhoria, negativos = deterioração
    post.environment_satisfaction - baseline.environment_satisfaction AS env_sat_delta,
    post.job_involvement - baseline.job_involvement AS job_inv_delta,
    post.job_satisfaction - baseline.job_satisfaction AS job_sat_delta,
    post.relationship_satisfaction - baseline.relationship_satisfaction AS rel_sat_delta,
    post.work_life_balance - baseline.work_life_balance AS wlb_delta,
    
    -- LABELS
    baseline.environment_satisfaction_label AS env_sat_label_before,
    post.environment_satisfaction_label AS env_sat_label_after,
    baseline.job_involvement_label AS job_inv_label_before,
    post.job_involvement_label AS job_inv_label_after,
    baseline.job_satisfaction_label AS job_sat_label_before,
    post.job_satisfaction_label AS job_sat_label_after,
    baseline.relationship_satisfaction_label AS rel_sat_label_before,
    post.relationship_satisfaction_label AS rel_sat_label_after,
    baseline.work_life_balance_label AS wlb_label_before,
    post.work_life_balance_label AS wlb_label_after,
    
    -- PERCENTAGENS (0-100%) - apenas métricas principais
    baseline.environment_satisfaction_pct AS env_sat_pct_before,
    post.environment_satisfaction_pct AS env_sat_pct_after,
    post.environment_satisfaction_pct - baseline.environment_satisfaction_pct AS env_sat_pct_delta,
    baseline.job_satisfaction_pct AS job_sat_pct_before,
    post.job_satisfaction_pct AS job_sat_pct_after,
    post.job_satisfaction_pct - baseline.job_satisfaction_pct AS job_sat_pct_delta
    
FROM d_employee e
INNER JOIN f_employee_movement fm ON e.employee_number = fm.employee_number
INNER JOIN d_department d ON fm.department_id = d.department_id
INNER JOIN d_job_role jr ON fm.job_role_id = jr.job_role_id
LEFT JOIN f_satisfaction_history baseline 
    ON e.employee_number = baseline.employee_number 
    AND baseline.survey_type = 'BASELINE'
LEFT JOIN f_satisfaction_history post 
    ON e.employee_number = post.employee_number 
    AND post.survey_type = 'POST_PINGPONG'
WHERE baseline.employee_number IS NOT NULL 
    AND post.employee_number IS NOT NULL;

-- ----------------------------------------
-- VIEW 2: ESTATÍSTICAS AGREGADAS POR DEPARTAMENTO
-- ----------------------------------------
-- Esta view agrega as médias por departamento e tipo de survey

CREATE VIEW vw_pingpong_dept_stats AS
SELECT 
    d.department_name,
    h.survey_type,
    COUNT(*) AS employee_count,
    
    -- Médias de cada métrica
    AVG(CAST(h.environment_satisfaction AS FLOAT)) AS avg_env_sat,
    AVG(CAST(h.job_involvement AS FLOAT)) AS avg_job_inv,
    AVG(CAST(h.job_satisfaction AS FLOAT)) AS avg_job_sat,
    AVG(CAST(h.relationship_satisfaction AS FLOAT)) AS avg_rel_sat,
    AVG(CAST(h.work_life_balance AS FLOAT)) AS avg_wlb,
    
    -- Médias em percentagem (0-100%) - apenas métricas principais
    AVG(h.environment_satisfaction_pct) AS avg_env_sat_pct,
    AVG(h.job_satisfaction_pct) AS avg_job_sat_pct,
    
    -- Distribuição por nível de satisfação (contagem)
    SUM(CASE WHEN h.environment_satisfaction = 1 THEN 1 ELSE 0 END) AS env_sat_low,
    SUM(CASE WHEN h.environment_satisfaction = 2 THEN 1 ELSE 0 END) AS env_sat_medium,
    SUM(CASE WHEN h.environment_satisfaction = 3 THEN 1 ELSE 0 END) AS env_sat_high,
    SUM(CASE WHEN h.environment_satisfaction = 4 THEN 1 ELSE 0 END) AS env_sat_very_high
    
FROM f_satisfaction_history h
INNER JOIN f_employee_movement fm ON h.employee_number = fm.employee_number
INNER JOIN d_department d ON fm.department_id = d.department_id
GROUP BY d.department_name, h.survey_type;

-- ----------------------------------------
-- VIEW 3: ESTATÍSTICAS AGREGADAS POR GERAÇÃO
-- ----------------------------------------
-- Esta view agrega as médias por geração e tipo de survey

CREATE VIEW vw_pingpong_generation_stats AS
SELECT 
    e.generation,
    h.survey_type,
    COUNT(*) AS employee_count,
    
    -- Médias de cada métrica
    AVG(CAST(h.environment_satisfaction AS FLOAT)) AS avg_env_sat,
    AVG(CAST(h.job_involvement AS FLOAT)) AS avg_job_inv,
    AVG(CAST(h.job_satisfaction AS FLOAT)) AS avg_job_sat,
    AVG(CAST(h.relationship_satisfaction AS FLOAT)) AS avg_rel_sat,
    AVG(CAST(h.work_life_balance AS FLOAT)) AS avg_wlb,
    
    -- Médias em percentagem (0-100%) - apenas métricas principais
    AVG(h.environment_satisfaction_pct) AS avg_env_sat_pct,
    AVG(h.job_satisfaction_pct) AS avg_job_sat_pct
    
FROM f_satisfaction_history h
INNER JOIN d_employee e ON h.employee_number = e.employee_number
GROUP BY e.generation, h.survey_type;

-- ----------------------------------------
-- VIEW 4: ANÁLISE DE MELHORIAS E DETERIORAÇÕES
-- ----------------------------------------
-- Esta view identifica funcionários que melhoraram ou pioraram

CREATE VIEW vw_pingpong_improvements AS
SELECT 
    e.employee_number,
    e.age,
    e.gender,
    d.department_name,
    jr.job_role_name,
    
    -- Calcular se houve melhoria geral (soma de todos os deltas)
    (post.environment_satisfaction - baseline.environment_satisfaction) +
    (post.job_involvement - baseline.job_involvement) +
    (post.job_satisfaction - baseline.job_satisfaction) +
    (post.relationship_satisfaction - baseline.relationship_satisfaction) +
    (post.work_life_balance - baseline.work_life_balance) AS total_delta,
    
    -- Classificar
    CASE 
        WHEN (post.environment_satisfaction - baseline.environment_satisfaction) +
             (post.job_involvement - baseline.job_involvement) +
             (post.job_satisfaction - baseline.job_satisfaction) +
             (post.relationship_satisfaction - baseline.relationship_satisfaction) +
             (post.work_life_balance - baseline.work_life_balance) > 0 
        THEN 'Improved'
        WHEN (post.environment_satisfaction - baseline.environment_satisfaction) +
             (post.job_involvement - baseline.job_involvement) +
             (post.job_satisfaction - baseline.job_satisfaction) +
             (post.relationship_satisfaction - baseline.relationship_satisfaction) +
             (post.work_life_balance - baseline.work_life_balance) < 0 
        THEN 'Deteriorated'
        ELSE 'No Change'
    END AS improvement_status
    
FROM d_employee e
INNER JOIN f_employee_movement fm ON e.employee_number = fm.employee_number
INNER JOIN d_department d ON fm.department_id = d.department_id
INNER JOIN d_job_role jr ON fm.job_role_id = jr.job_role_id
INNER JOIN f_satisfaction_history baseline 
    ON e.employee_number = baseline.employee_number 
    AND baseline.survey_type = 'BASELINE'
INNER JOIN f_satisfaction_history post 
    ON e.employee_number = post.employee_number 
    AND post.survey_type = 'POST_PINGPONG';

-- ================================================================================
-- PASSO 8: CRIAR ÍNDICES PARA OTIMIZAÇÃO
-- ================================================================================

-- Índice na coluna employee_number para melhorar performance de JOINs
CREATE INDEX IX_SatisfactionHistory_EmployeeNumber 
    ON f_satisfaction_history(employee_number);

-- Índice na coluna survey_type para melhorar filtros
CREATE INDEX IX_SatisfactionHistory_SurveyType 
    ON f_satisfaction_history(survey_type);

-- Índice composto para queries que filtram por ambos
CREATE INDEX IX_SatisfactionHistory_Employee_SurveyType 
    ON f_satisfaction_history(employee_number, survey_type);

-- ================================================================================
-- PASSO 9: QUERIES DE VERIFICAÇÃO E VALIDAÇÃO
-- ================================================================================

-- ----------------------------------------
-- Verificar total de registos por tipo de survey
-- ----------------------------------------
SELECT 
    survey_type,
    COUNT(*) AS total_registos
FROM f_satisfaction_history
GROUP BY survey_type;
-- Resultado esperado:
-- BASELINE: 1233
-- POST_PINGPONG: 1233

-- ----------------------------------------
-- Verificar se há funcionários sem dados DEPOIS
-- ----------------------------------------
SELECT 
    e.employee_number,
    e.age,
    e.gender,
    d.department_name
FROM d_employee e
INNER JOIN f_employee_movement fm ON e.employee_number = fm.employee_number
INNER JOIN d_department d ON fm.department_id = d.department_id
WHERE e.attrition_flag = 0
    AND e.employee_number NOT IN (
        SELECT employee_number 
        FROM f_satisfaction_history 
        WHERE survey_type = 'POST_PINGPONG'
    );
-- Resultado esperado: 0 registos

-- ----------------------------------------
-- Ver exemplos de funcionários que melhoraram mais
-- ----------------------------------------
SELECT TOP 10 
    employee_number,
    department_name,
    job_role_name,
    env_sat_delta,
    job_inv_delta,
    job_sat_delta,
    rel_sat_delta,
    wlb_delta,
    (env_sat_delta + job_inv_delta + job_sat_delta + rel_sat_delta + wlb_delta) AS total_improvement
FROM vw_pingpong_comparison
ORDER BY (env_sat_delta + job_inv_delta + job_sat_delta + rel_sat_delta + wlb_delta) DESC;

-- ----------------------------------------
-- Ver exemplos de funcionários que pioraram mais
-- ----------------------------------------
SELECT TOP 10 
    employee_number,
    department_name,
    job_role_name,
    env_sat_delta,
    job_inv_delta,
    job_sat_delta,
    rel_sat_delta,
    wlb_delta,
    (env_sat_delta + job_inv_delta + job_sat_delta + rel_sat_delta + wlb_delta) AS total_deterioration
FROM vw_pingpong_comparison
ORDER BY (env_sat_delta + job_inv_delta + job_sat_delta + rel_sat_delta + wlb_delta) ASC;

-- ----------------------------------------
-- Estatísticas gerais de melhoria
-- ----------------------------------------
SELECT 
    COUNT(*) AS total_employees,
    SUM(CASE WHEN env_sat_delta > 0 THEN 1 ELSE 0 END) AS improved_env_sat,
    SUM(CASE WHEN env_sat_delta < 0 THEN 1 ELSE 0 END) AS deteriorated_env_sat,
    SUM(CASE WHEN env_sat_delta = 0 THEN 1 ELSE 0 END) AS no_change_env_sat,
    CAST(AVG(CAST(env_sat_after AS FLOAT)) - AVG(CAST(env_sat_before AS FLOAT)) AS DECIMAL(5,2)) AS avg_env_sat_change
FROM vw_pingpong_comparison;

-- ----------------------------------------
-- Comparação de médias ANTES vs DEPOIS (geral)
-- ----------------------------------------
SELECT 
    'Environment Satisfaction' AS metric,
    AVG(CAST(env_sat_before AS FLOAT)) AS avg_before,
    AVG(CAST(env_sat_after AS FLOAT)) AS avg_after,
    AVG(CAST(env_sat_after AS FLOAT)) - AVG(CAST(env_sat_before AS FLOAT)) AS delta
FROM vw_pingpong_comparison
UNION ALL
SELECT 
    'Job Involvement' AS metric,
    AVG(CAST(job_inv_before AS FLOAT)) AS avg_before,
    AVG(CAST(job_inv_after AS FLOAT)) AS avg_after,
    AVG(CAST(job_inv_after AS FLOAT)) - AVG(CAST(job_inv_before AS FLOAT)) AS delta
FROM vw_pingpong_comparison
UNION ALL
SELECT 
    'Job Satisfaction' AS metric,
    AVG(CAST(job_sat_before AS FLOAT)) AS avg_before,
    AVG(CAST(job_sat_after AS FLOAT)) AS avg_after,
    AVG(CAST(job_sat_after AS FLOAT)) - AVG(CAST(job_sat_before AS FLOAT)) AS delta
FROM vw_pingpong_comparison
UNION ALL
SELECT 
    'Relationship Satisfaction' AS metric,
    AVG(CAST(rel_sat_before AS FLOAT)) AS avg_before,
    AVG(CAST(rel_sat_after AS FLOAT)) AS avg_after,
    AVG(CAST(rel_sat_after AS FLOAT)) - AVG(CAST(rel_sat_before AS FLOAT)) AS delta
FROM vw_pingpong_comparison
UNION ALL
SELECT 
    'Work Life Balance' AS metric,
    AVG(CAST(wlb_before AS FLOAT)) AS avg_before,
    AVG(CAST(wlb_after AS FLOAT)) AS avg_after,
    AVG(CAST(wlb_after AS FLOAT)) - AVG(CAST(wlb_before AS FLOAT)) AS delta
FROM vw_pingpong_comparison;

-- ----------------------------------------
-- Comparação por departamento
-- ----------------------------------------
SELECT 
    department_name,
    survey_type,
    employee_count,
    CAST(avg_env_sat AS DECIMAL(5,2)) AS avg_env_sat,
    CAST(avg_job_inv AS DECIMAL(5,2)) AS avg_job_inv,
    CAST(avg_job_sat AS DECIMAL(5,2)) AS avg_job_sat,
    CAST(avg_rel_sat AS DECIMAL(5,2)) AS avg_rel_sat,
    CAST(avg_wlb AS DECIMAL(5,2)) AS avg_wlb
FROM vw_pingpong_dept_stats
ORDER BY department_name, survey_type;

-- ----------------------------------------
-- Distribuição de melhorias
-- ----------------------------------------
SELECT 
    improvement_status,
    COUNT(*) AS employee_count,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM vw_pingpong_improvements) AS DECIMAL(5,2)) AS percentage
FROM vw_pingpong_improvements
GROUP BY improvement_status;

-- ================================================================================
-- OPCIONAL: LIMPAR STAGING TABLE (após confirmar que tudo está correto)
-- ================================================================================

-- DROP TABLE stg_pingpong_survey;

-- ================================================================================
-- FIM DO SCRIPT
-- ================================================================================


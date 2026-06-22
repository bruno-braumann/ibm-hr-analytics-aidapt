-- ================================================================================
-- SCRIPT DE ALTERAÇÃO: DATETIME2 para DATE
-- Tabela: f_employee_movement
-- Coluna: date_movement
-- ================================================================================

-- IMPORTANTE: Este script altera a estrutura de uma tabela existente
-- Certifica-te que tens backup da base de dados antes de executar!

-- ================================================================================
-- PASSO 1: VERIFICAR O TIPO DE DADOS ATUAL
-- ================================================================================

-- Ver o tipo de dados atual da coluna date_movement
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'f_employee_movement'
    AND COLUMN_NAME = 'date_movement';

-- Resultado esperado: DATETIME2

-- ================================================================================
-- PASSO 2: VERIFICAR SE HÁ DADOS COM COMPONENTE DE HORA
-- ================================================================================

-- Verificar se alguma data tem hora diferente de 00:00:00
SELECT 
    employee_number,
    date_movement,
    CAST(date_movement AS DATE) AS date_only,
    CASE 
        WHEN CAST(date_movement AS TIME) = '00:00:00.0000000' THEN 'Sem hora'
        ELSE 'TEM HORA!'
    END AS tem_componente_hora
FROM f_employee_movement
WHERE date_movement IS NOT NULL
    AND CAST(date_movement AS TIME) <> '00:00:00.0000000';

-- Se retornar 0 linhas: SEGURO alterar para DATE (não há perda de dados)
-- Se retornar linhas: ATENÇÃO - haverá perda da componente de hora!

-- ================================================================================
-- PASSO 3: ALTERAR O TIPO DE DADOS DE DATETIME2 PARA DATE
-- ================================================================================

-- Alterar a coluna date_movement de DATETIME2 para DATE
ALTER TABLE f_employee_movement
ALTER COLUMN date_movement DATE;

-- NOTA: Se a coluna tiver constraints ou índices, pode ser necessário removê-los antes
-- e recriá-los depois. Vê o PASSO 4 se houver erros.

-- ================================================================================
-- PASSO 4: VERIFICAR A ALTERAÇÃO
-- ================================================================================

-- Confirmar que o tipo de dados foi alterado
SELECT 
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'f_employee_movement'
    AND COLUMN_NAME = 'date_movement';

-- Resultado esperado: DATE

-- Ver alguns exemplos de dados após a alteração
SELECT TOP 10
    employee_number,
    date_movement,
    years_since_last_promotion
FROM f_employee_movement
WHERE date_movement IS NOT NULL
ORDER BY employee_number;

-- ================================================================================
-- PASSO 5 (OPCIONAL): SE HOUVER ERROS POR CAUSA DE CONSTRAINTS/ÍNDICES
-- ================================================================================

-- Se o ALTER TABLE falhar devido a constraints ou índices, usa este método alternativo:

-- 5.1. Verificar se existem índices na coluna
SELECT 
    i.name AS index_name,
    i.type_desc AS index_type
FROM sys.indexes i
INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE OBJECT_NAME(i.object_id) = 'f_employee_movement'
    AND c.name = 'date_movement';

-- 5.2. Se existirem índices, guarda os nomes e remove-os temporariamente
-- Exemplo (substitui 'IX_NomeDoIndice' pelo nome real):
-- DROP INDEX IX_NomeDoIndice ON f_employee_movement;

-- 5.3. Tenta novamente o ALTER TABLE
-- ALTER TABLE f_employee_movement
-- ALTER COLUMN date_movement DATE;

-- 5.4. Recria os índices que removeste
-- Exemplo:
-- CREATE INDEX IX_NomeDoIndice ON f_employee_movement(date_movement);

-- ================================================================================
-- PASSO 6: TESTAR AS QUERIES QUE USAM date_movement
-- ================================================================================

-- Verificar que as queries continuam a funcionar corretamente

-- Query 1: Calcular anos desde a última promoção
SELECT 
    employee_number,
    date_movement,
    years_since_last_promotion,
    DATEDIFF(YEAR, date_movement, '2026-01-22') AS anos_calculados
FROM f_employee_movement
WHERE date_movement IS NOT NULL
ORDER BY employee_number;

-- Query 2: Filtrar por intervalo de datas
SELECT 
    COUNT(*) AS total_movimentos,
    MIN(date_movement) AS primeira_data,
    MAX(date_movement) AS ultima_data
FROM f_employee_movement
WHERE date_movement IS NOT NULL;

-- ================================================================================
-- RESUMO DAS VANTAGENS DA ALTERAÇÃO
-- ================================================================================

/*
VANTAGENS de usar DATE em vez de DATETIME2:

1. ESPAÇO: DATE usa 3 bytes vs DATETIME2 que usa 6-8 bytes
   - Economia de ~50% de espaço de armazenamento
   - Com 1233 registos: ~4KB economizados (pequeno mas consistente)

2. CLAREZA SEMÂNTICA: 
   - date_movement é conceptualmente uma DATA, não um timestamp
   - Evita confusão sobre se a hora é relevante

3. PERFORMANCE:
   - Comparações e índices ligeiramente mais rápidos
   - Menos overhead em operações de data

4. CONSISTÊNCIA:
   - Alinha com Integracao_PingPongSurvey.sql que usa DATE
   - Melhor prática para colunas que não precisam de hora

5. SIMPLICIDADE:
   - Queries mais simples (não precisa de CAST para remover hora)
   - Menos possibilidade de bugs com comparações de data+hora
*/

-- ================================================================================
-- FIM DO SCRIPT
-- ================================================================================

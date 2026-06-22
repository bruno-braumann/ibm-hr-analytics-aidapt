-- 1. Criar Base de dados / Database
CREATE DATABASE 
	IBM_Project_Group4_2026; -- Sugestão de nome

/*           OU

Pasta "Databases" - Bot. Direito - New Database - Database name: (Inserir nome) - OK
*/

-- 2. Criamos uma staging que replica as colunas do CSV (nomes em minúsculas com underscore). 
CREATE TABLE stg_employee_raw (
    age INT,
    attrition VARCHAR(10),
    business_travel VARCHAR(50),
    daily_rate INT,
    department VARCHAR(100),
    distance_from_home INT,
    education INT,
    education_field VARCHAR(100),
    employee_count INT,
    employee_number INT,
    environment_satisfaction INT,
    gender VARCHAR(20),
    hourly_rate INT,
    job_involvement INT,
    job_level INT,
    job_role VARCHAR(100),
    job_satisfaction INT,
    marital_status VARCHAR(50),
    monthly_income INT,
    monthly_rate INT,
    num_companies_worked INT,
    over18 VARCHAR(5),
    over_time VARCHAR(10),
    percent_salary_hike INT,
    performance_rating INT,
    relationship_satisfaction INT,
    standard_hours INT,
    stock_option_level INT,
    total_working_years INT,
    training_times_last_year INT,
    work_life_balance INT,
    years_at_company INT,
    years_in_current_role INT,
    years_since_last_promotion INT,
    years_with_curr_manager INT
);

-- 3. Load CSV into staging
-- Substituir 'C:\path\to\WA_Fn-UseC_-HR-Employee-Attrition.csv' pela localização atual do ficheiro
BULK INSERT stg_employee_raw
FROM 'C:\Users\Formando\Desktop\Projeto 1\WA_Fn-UseC_-HR-Employee-Attrition.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001', -- UTF-8 if file encoded
    TABLOCK
);

-- Confirmar inserção dos dados
SELECT * FROM [dbo].[stg_employee_raw];

-- 4. Criar d_department (DIMENSÃO)
CREATE TABLE d_department (
    department_id INT IDENTITY(1,1) PRIMARY KEY,
    department_name VARCHAR(100) UNIQUE NOT NULL,
);

-- Inserir departamentos únicos
INSERT INTO d_department 
	(department_name)
SELECT DISTINCT Department
FROM  stg_employee_raw
WHERE Department IS NOT NULL; -- Não é obrigatório, mas é um boa prática caso existam valores nulos e ao criar a tabela definimos "department_name VARCHAR(100) UNIQUE NOT NULL". Se houvesse valores nulos iria dar erro porque a coluna não aceita nulos.

-- Confirmar inserção dos dados
SELECT * FROM [dbo].[d_department];

-- 5. Criar d_job_role (DIMENSÃO) 
CREATE TABLE d_job_role (
    job_role_id INT IDENTITY(1,1) PRIMARY KEY,
    job_role_name VARCHAR(150) NOT NULL,
    job_level INT,
    job_level_label VARCHAR(50),
    is_manager BIT,
);

-- Inserir job roles únicos com job level
INSERT INTO d_job_role 
	(job_role_name, job_level)
SELECT DISTINCT 
    job_role,
    job_level
FROM  stg_employee_raw
WHERE job_role IS NOT NULL;

-- Atualizar job_level_label
UPDATE d_job_role
SET job_level_label = CASE job_level
    WHEN 1 THEN 'Associate'
    WHEN 2 THEN 'Specialist'
    WHEN 3 THEN 'Expert'
    WHEN 4 THEN 'Lead'
    WHEN 5 THEN 'Principal'
    ELSE 'Unknown'
END;

-- Atualizar is_manager (cargos com "Manager" ou "Director" no nome)
UPDATE d_job_role
SET is_manager = CASE 
    WHEN 
	job_role_name LIKE '%Manager%' 
	OR job_role_name LIKE '%Director%' THEN 1
    ELSE 0
END;

-- Confirmar inserção dos dados
SELECT * FROM [dbo].[d_job_role];

-- 6. Criar d_employee (DIMENSÃO)
CREATE TABLE d_employee (
    employee_number INT PRIMARY KEY, -- from CSV
    age INT NOT NULL,
    gender VARCHAR(20),
    marital_status VARCHAR(50),
    over18 VARCHAR(5), -- Sempre "Y", manter para compliance
    distance_from_home INT,
    employee_count INT, -- Sempre 1, manter para rastreabilidade
    total_working_years INT,
    num_companies_worked INT,
    standard_hours INT,
    attrition VARCHAR(10),
-- Colunas calculadas
    age_band VARCHAR(20),
    birth_year INT,
    generation VARCHAR(50),
    retirement_risk BIT,
    years_to_retirement INT,
    retire_in_5yrs_flag_bit BIT NULL,     -- option A: BIT
    retire_in_5yrs_flag_varchar VARCHAR(50) NULL, -- option B: VARCHAR
    attrition_flag BIT
);

-- Inserir dados base (mantendo attrition como 'Yes'/'No')
INSERT INTO d_employee 
	(employee_number, age, gender, marital_status, over18, distance_from_home,
    employee_count, total_working_years, num_companies_worked, standard_hours, attrition)
SELECT 
    employee_number,
    age,
    gender,
    marital_status,
    Over18,
    distance_from_home,
    employee_count,
    total_working_years,
    num_companies_worked,
    standard_hours,
    attrition  -- Mantêm 'Yes' ou 'No' do ficheiro original
FROM stg_employee_raw;

-- Calcular colunas derivadas

-- age_band
UPDATE d_employee
SET age_band = CASE
    WHEN age BETWEEN 18 AND 19 THEN '18-19'
    WHEN age BETWEEN 20 AND 29 THEN '20-29'
    WHEN age BETWEEN 30 AND 39 THEN '30-39'
    WHEN age BETWEEN 40 AND 49 THEN '40-49'
    WHEN age BETWEEN 50 AND 59 THEN '50-59'
    WHEN age >= 60 THEN '60+'
    ELSE 'Unknown'
END;

-- birth_year (usando o ano atual como referência)
UPDATE d_employee
SET birth_year = YEAR(GETDATE()) - age;

-- generation
UPDATE d_employee
SET generation = CASE
    WHEN birth_year BETWEEN 1946 AND 1964 THEN 'Baby Boomers'
    WHEN birth_year BETWEEN 1965 AND 1980 THEN 'Generation X'
    WHEN birth_year BETWEEN 1981 AND 1996 THEN 'Millennials'
    WHEN birth_year BETWEEN 1997 AND 2010 THEN 'Generation Z'
    WHEN birth_year BETWEEN 2011 AND 2024 THEN 'Generation Alpha'
    WHEN birth_year >= 2025 THEN 'Generation Beta'
    ELSE 'Unknown'
END;

-- retirement_risk (>=60 anos)
UPDATE d_employee
SET retirement_risk = CASE WHEN age >= 60 THEN 1 ELSE 0 END;

-- years_to_retirement
UPDATE d_employee
SET years_to_retirement = 60 - age;

-- retire_in_5yrs_flag_bit
UPDATE d_employee
SET retire_in_5yrs_flag_bit = CASE 
    WHEN years_to_retirement BETWEEN 0 AND 5 THEN 1 
    ELSE 0 
END;

-- retire_in_5yrs_flag_varchar
UPDATE d_employee
SET retire_in_5yrs_flag_varchar = CASE 
    WHEN years_to_retirement BETWEEN 0 AND 5 THEN 'Within 5 years'
    ELSE 'No'
END;

-- attrition_flag
UPDATE d_employee
SET attrition_flag = CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END;

-- Confirmar inserção dos dados
SELECT * FROM [dbo].[d_employee];

-- 7. Criar d_education (DIMENSÃO)
CREATE TABLE d_education (
    education_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_number INT NOT NULL, -- FK to d_employee.employee_number
    education_level INT,
    education_field VARCHAR(100),
    education_level_label VARCHAR(50),

    -- Foreign Key
    CONSTRAINT FK_education_employee 
	FOREIGN KEY (employee_number) 
        	REFERENCES d_employee (employee_number)	
);

-- Inserir dados de educação
INSERT INTO d_education 
	(employee_number, education_level, education_field)
SELECT 
    employee_number,
    education,
    education_field
FROM stg_employee_raw;

-- Atualizar education_level_label
UPDATE d_education
SET education_level_label = CASE education_level
    WHEN 1 THEN 'Below College'
    WHEN 2 THEN 'College'
    WHEN 3 THEN 'Bachelor'
    WHEN 4 THEN 'Master'
    WHEN 5 THEN 'Doctor'
    ELSE 'Unknown'
END;

-- Confirmar inserção dos dados
SELECT * FROM [dbo].[d_education];

-- 8. Criar f_employee_movement
CREATE TABLE f_employee_movement (
    employee_movement_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_number INT NOT NULL, -- FK to d_employee.employee_number
    job_role_id INT,         -- FK to d_job_role.job_role_id
    department_id INT,       -- FK to d_department.department_id
    business_travel VARCHAR(50),
    over_time VARCHAR(10),
    years_at_company INT,
    years_in_current_role INT,
    years_with_curr_manager INT,
    years_since_last_promotion INT,
    job_involvement INT,
    monthly_income INT,
    monthly_rate INT,
    hourly_rate INT,
    daily_rate INT,
    percent_salary_hike INT,
    stock_option_level INT,
    performance_rating INT,
    training_times_last_year INT,   
    -- Colunas calculadas
    distance_from_home_band VARCHAR(50),
    job_involvement_label VARCHAR(50),
    tenure_category VARCHAR(50),
    compensation_level_label VARCHAR(50),
    annual_income INT,
    performance_percent DECIMAL(5,2),
    performance_rating_label VARCHAR(20),
    date_movement DATE,
    date_movement_flag BIT,

     -- Foreign Keys
    CONSTRAINT FK_movement_employee 
	FOREIGN KEY (employee_number) 
        	REFERENCES d_employee (employee_number),
    CONSTRAINT FK_movement_jobrole 
	FOREIGN KEY (job_role_id) 
        	REFERENCES d_job_role (job_role_id),
    CONSTRAINT FK_movement_department 
	FOREIGN KEY (department_id) 
        	REFERENCES d_department (department_id)
   
);

-- Inserir dados base
INSERT INTO f_employee_movement 
	(employee_number, business_travel, over_time, years_at_company,
    years_in_current_role, years_with_curr_manager, years_since_last_promotion,
    job_involvement, monthly_income, monthly_rate, hourly_rate, daily_rate,
    percent_salary_hike, stock_option_level, performance_rating, training_times_last_year)
SELECT 
    E.employee_number,
    E.business_travel,
    E.over_time,
    E.years_at_company,
    E.years_in_current_role,
    E.years_with_curr_manager,
    E.years_since_last_promotion,
    E.job_involvement,
    E.monthly_income,
    E.monthly_rate,
    E.hourly_rate,
    E.daily_rate,
    E.percent_salary_hike,
    E.stock_option_level,
    E.performance_rating,
    E.training_times_last_year
FROM stg_employee_raw E;

-- Atualizar job_role_id
UPDATE F
	SET F.job_role_id = JR.job_role_id
	FROM f_employee_movement F
INNER JOIN stg_employee_raw E 
    ON F.employee_number = E.employee_number
INNER JOIN d_job_role JR
    ON E.job_role = JR.job_role_name AND E.job_level = JR.job_level;

-- Atualizar department_id
UPDATE F
	SET F.department_id = D.department_id
	FROM f_employee_movement F
INNER JOIN stg_employee_raw E 
    ON F.employee_number = E.employee_number
INNER JOIN d_department D 
    ON E.department = D.department_name;

-- Calcular colunas derivadas

-- distance_from_home_band
UPDATE F
SET F.distance_from_home_band = CASE
    WHEN E.distance_from_home BETWEEN 0 AND 5 THEN 'Near (0-5)'
    WHEN E.distance_from_home BETWEEN 6 AND 15 THEN 'Medium (6-15)'
    WHEN E.distance_from_home > 15 THEN 'Far (>15)'
    ELSE 'Unknown'
END
FROM f_employee_movement F
	INNER JOIN d_employee E ON F.employee_number = E.employee_number;

-- job_involvement_label
UPDATE f_employee_movement
	SET job_involvement_label = CASE job_involvement
    		WHEN 1 THEN 'Low'
    		WHEN 2 THEN 'Medium'
    		WHEN 3 THEN 'High'
   		 WHEN 4 THEN 'Very High'
   		 ELSE 'Unknown'
	END;

-- tenure_category
UPDATE f_employee_movement
	SET tenure_category = CASE
    		WHEN years_at_company BETWEEN 0 AND 1 THEN 'New Hire (0-1)'
    		WHEN years_at_company BETWEEN 2 AND 5 THEN 'Early (2-5)'
    		WHEN years_at_company BETWEEN 6 AND 10 THEN 'Mid (6-10)'
    		WHEN years_at_company >= 11 THEN 'Senior (11+)'
    		ELSE 'Unknown'
	END;

-- compensation_level_label
UPDATE f_employee_movement
	SET compensation_level_label = CASE
    		WHEN monthly_income < 3000 THEN 'Low'
    		WHEN monthly_income BETWEEN 3000 AND 8000 THEN 'Medium'
    		WHEN monthly_income > 8000 THEN 'High'
    		ELSE 'Unknown'
	END;

-- annual_income
UPDATE f_employee_movement
	SET annual_income = monthly_income * 12;

-- performance_percent (normalizar 1-4 para 0-100%)
UPDATE f_employee_movement
	SET performance_percent = CAST(((performance_rating - 1) * 100.0 / (4 - 1)) AS DECIMAL(5,2));

-- performance_rating_label
UPDATE f_employee_movement
	SET performance_rating_label = CASE performance_rating
    		WHEN 1 THEN 'Low'
    		WHEN 2 THEN 'Good'
    		WHEN 3 THEN 'Excellent'
    		WHEN 4 THEN 'Outstanding'
    		ELSE 'Unknown'
	END;

-- ========================================
-- UPDATE da coluna date_movement
-- Data base: 22/01/2026 menos years_since_last_promotion
-- Se attrition_flag = 1, date_movement fica NULL
-- ========================================

UPDATE f
SET f.date_movement = CASE 
    WHEN e.attrition_flag = 1 THEN NULL
    ELSE DATEADD(YEAR, -f.years_since_last_promotion, '2026-01-22')
END
FROM f_employee_movement f
INNER JOIN d_employee e ON f.employee_number = e.employee_number;

-- Verificar os resultados
SELECT 
    f.employee_number,
    e.attrition_flag,
    f.years_since_last_promotion,
    f.date_movement,
    CASE 
        WHEN f.date_movement IS NULL THEN 'NULL (Attrition)'
        ELSE CAST(DATEDIFF(YEAR, f.date_movement, '2026-01-22') AS NVARCHAR)
    END AS anos_calculados
FROM f_employee_movement f
INNER JOIN d_employee e ON f.employee_number = e.employee_number
ORDER BY e.attrition_flag DESC, f.employee_number;

-- Confirmar inserção dos dados
SELECT * FROM [dbo].[f_employee_movement];

-- 9. Criar f_satisfaction
CREATE TABLE f_satisfaction (
    satisfaction_id INT IDENTITY(1,1) PRIMARY KEY,
    employee_number INT NOT NULL, -- FK to d_employee.employee_number
    job_satisfaction INT,
    environment_satisfaction INT,  
    relationship_satisfaction INT,
    work_life_balance INT,
    -- Colunas calculadas
    job_satisfaction_pct DECIMAL (5,2),
    environment_satisfaction_pct DECIMAL (5,2),
    environment_satisfaction_label VARCHAR (50),
    relationship_satisfaction_label VARCHAR (50),
    work_life_balance_label VARCHAR (50),

    -- Foreign Key
    CONSTRAINT FK_satisfaction_employee 
	FOREIGN KEY (employee_number) 
    	REFERENCES d_employee (employee_number)
);

-- Inserir dados base
INSERT INTO f_satisfaction 
	(employee_number, job_satisfaction, environment_satisfaction, relationship_satisfaction, work_life_balance)
SELECT 
    employee_number,
    job_satisfaction,
    environment_satisfaction,
    relationship_satisfaction,
    work_life_balance
FROM stg_employee_raw;

-- Calcular colunas derivadas

-- job_satisfaction_pct (normalizar 1-4 para 0-100%)
UPDATE f_satisfaction
	SET job_satisfaction_pct = CAST(((job_satisfaction - 1) * 100.0 / (4 - 1)) AS DECIMAL(5,2));

-- environment_satisfaction_pct (normalizar 1-4 para 0-100%)
UPDATE f_satisfaction
	SET environment_satisfaction_pct = CAST(((environment_satisfaction - 1) * 100.0 / (4 - 1)) AS DECIMAL(5,2));

-- environment_satisfaction_label
UPDATE f_satisfaction
	SET environment_satisfaction_label = CASE environment_satisfaction
    		WHEN 1 THEN 'Low'
    		WHEN 2 THEN 'Medium'
    		WHEN 3 THEN 'High'
    		WHEN 4 THEN 'Very High'
    		ELSE 'Unknown'
	END;

-- relationship_satisfaction_label
UPDATE f_satisfaction
	SET relationship_satisfaction_label = CASE relationship_satisfaction
    		WHEN 1 THEN 'Low'
    		WHEN 2 THEN 'Medium'
    		WHEN 3 THEN 'High'
    		WHEN 4 THEN 'Very High'
    		ELSE 'Unknown'
	END;

-- work_life_balance_label
UPDATE f_satisfaction
	SET work_life_balance_label = CASE work_life_balance
    		WHEN 1 THEN 'Bad'
    		WHEN 2 THEN 'Good'
    		WHEN 3 THEN 'Better'
    		WHEN 4 THEN 'Best'
    		ELSE 'Unknown'
	END;

-- Confirmar inserção dos dados
SELECT * FROM [dbo].[f_satisfaction];

-- ========================================
-- ÍNDICES PARA OTIMIZAÇÃO
-- ========================================

-- índices em Foreign Keys
CREATE INDEX IX_Education_EmployeeNumber ON d_education(employee_number);
CREATE INDEX IX_Movement_EmployeeNumber ON f_employee_movement(employee_number);
CREATE INDEX IX_Movement_JobRoleID ON f_employee_movement(job_role_id);
CREATE INDEX IX_Movement_DepartmentID ON f_employee_movement(department_id);
CREATE INDEX IX_Satisfaction_EmployeeNumber ON f_satisfaction(employee_number);

-- índices em campos frequentemente filtrados
CREATE INDEX IX_Employee_Attrition ON d_employee(attrition_flag);
CREATE INDEX IX_Employee_AgeBand ON d_employee(age_band);
CREATE INDEX IX_Employee_Generation ON d_employee(generation);
CREATE INDEX IX_Movement_TenureCategory ON f_employee_movement(tenure_category);
CREATE INDEX IX_Movement_CompensationLevel ON f_employee_movement(compensation_level_label);

-- ========================================
-- VIEWS DE ANÁLISE
-- ========================================
-- View completa combinando todas as tabelas
CREATE VIEW vw_employee_analytics AS
SELECT 
    -- Employee Info
    e.employee_number,
    e.age,
    e.age_band,
    e.gender,
    e.marital_status,
    e.generation,
    e.attrition,
    e.attrition_flag,
    e.retirement_risk,
    e.years_to_retirement,
    e.retire_in_5yrs_flag_bit,
	e.retire_in_5yrs_flag_varchar,
    e.total_working_years,
    e.num_companies_worked,
    
    -- Education
    ed.education_level,
    ed.education_level_label,
    ed.education_field,
    
    -- Department & Role
    d.department_name,
    jr.job_role_name,
    jr.job_level,
    jr.job_level_label,
    jr.is_manager,
    
    -- Movement/Employment
    fm.business_travel,
    fm.over_time,
    fm.years_at_company,
    fm.tenure_category,
    fm.years_in_current_role,
    fm.years_with_curr_manager,
    fm.years_since_last_promotion,
    fm.distance_from_home_band,
    
    -- Compensation
    fm.monthly_income,
    fm.annual_income,
    fm.compensation_level_label,
    fm.percent_salary_hike,
    fm.stock_option_level,
    

    -- Performance
    fm.performance_rating,
    fm.performance_rating_label,
    fm.performance_percent,
    fm.job_involvement,
    fm.job_involvement_label,
    fm.training_times_last_year,
    
    -- Satisfaction
    fs.job_satisfaction,
    fs.job_satisfaction_pct,
    fs.environment_satisfaction,
    fs.environment_satisfaction_label,
    fs.relationship_satisfaction,
    fs.relationship_satisfaction_label,
    fs.work_life_balance,
    fs.work_life_balance_label
    
FROM d_employee e
LEFT JOIN d_education ed ON e.employee_number = ed.employee_number
LEFT JOIN f_employee_movement fm ON e.employee_number = fm.employee_number
LEFT JOIN d_department d ON fm.department_id = d.department_id
LEFT JOIN d_job_role jr ON fm.job_role_id = jr.job_role_id
LEFT JOIN f_satisfaction fs ON e.employee_number = fs.employee_number;

-- View focada em ANÁLISE de Attrition
CREATE VIEW vw_attrition_analysis AS
SELECT 
    e.employee_number,
    e.age,
    e.age_band,
    e.gender,
    e.generation,
    e.attrition,
    e.attrition_flag,
    d.department_name,
    jr.job_role_name,
    jr.is_manager,
    fm.years_at_company,
    fm.tenure_category,
    fm.monthly_income,
    fm.compensation_level_label,
    fm.over_time,
    fm.distance_from_home_band,
    fs.job_satisfaction,
    fs.work_life_balance,
    fs.work_life_balance_label,
    fm.performance_rating,
    fm.performance_rating_label
FROM d_employee e
INNER JOIN f_employee_movement fm ON e.employee_number = fm.employee_number
INNER JOIN d_department d ON fm.department_id = d.department_id
INNER JOIN d_job_role jr ON fm.job_role_id = jr.job_role_id
INNER JOIN f_satisfaction fs ON e.employee_number = fs.employee_number;

-- View focada em ANÁLISE de Compensação
CREATE VIEW vw_compensation_analysis AS
SELECT 
    e.employee_number,
    e.age_band,
    e.gender,
    e.generation,
    d.department_name,
    jr.job_role_name,
    jr.job_level_label,
    ed.education_level_label,
    fm.years_at_company,
    fm.monthly_income,
    fm.annual_income,
    fm.compensation_level_label,
    fm.percent_salary_hike,
    fm.stock_option_level,
    fm.performance_rating,
    fm.performance_rating_label
FROM d_employee e
INNER JOIN f_employee_movement fm ON e.employee_number = fm.employee_number
INNER JOIN d_department d ON fm.department_id = d.department_id
INNER JOIN d_job_role jr ON fm.job_role_id = jr.job_role_id
INNER JOIN d_education ed ON e.employee_number = ed.employee_number;


-- ========================================
-- VERIFICAÇÃO DE DADOS
-- ========================================

-- Verificar contagem de registos
SELECT 'Table Name' AS TableName, 'Record Count' AS RecordCount
UNION ALL
SELECT 'd_employee', CAST(COUNT(*) AS NVARCHAR) FROM d_employee
UNION ALL
SELECT 'd_department', CAST(COUNT(*) AS NVARCHAR) FROM d_department
UNION ALL
SELECT 'd_job_role', CAST(COUNT(*) AS NVARCHAR) FROM d_job_role
UNION ALL
SELECT 'd_education', CAST(COUNT(*) AS NVARCHAR) FROM d_education
UNION ALL
SELECT 'f_employee_movement', CAST(COUNT(*) AS NVARCHAR) FROM f_employee_movement
UNION ALL
SELECT 'f_satisfaction', CAST(COUNT(*) AS NVARCHAR) FROM f_satisfaction;

-- Verificar distribuição (%) por attrition
SELECT 
    	attrition,
    	COUNT(*) AS employee_count,
    	CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM d_employee) AS DECIMAL(5,2)) AS percentage
FROM 
	d_employee
GROUP BY 
	attrition;

-- Verificar distribuição por geração
SELECT 
    	generation,
    	COUNT (*) AS employee_count,
    	AVG( age) AS avg_age
FROM 
	d_employee
GROUP BY 
	generation
ORDER BY 
	avg_age;


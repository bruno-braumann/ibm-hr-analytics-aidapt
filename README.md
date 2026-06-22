# IBM HR Analytics, AiDAPT Project

A group project developed as part of the **AiDAPT course at Cegid Academy**, analysing IBM HR data across three technologies: R (exploratory analysis), SQL Server (data modelling), and Power BI (dashboard).

The project simulates a consulting engagement where a fictional IBM HR director requests an analysis of the workforce and the impact of a workplace initiative, the introduction of a ping pong table, on employee well-being and satisfaction.

> **Note:** This project uses the IBM HR Analytics dataset for educational purposes only. IBM branding is used solely to contextualise the simulated scenario.

---

## Project Brief

The fictional client, a long-tenured IBM HR director, presented the following context:

- The company had recently lost its HR director and was undertaking a workforce review
- A 2026 target had been set to reach 50/50 gender parity across all levels
- A ping pong table had been introduced as a well-being initiative, with a follow-up survey planned to measure its impact
- The deliverable was a three-slide Power BI dashboard for a board presentation, focused on macro indicators

### Questions the analysis was designed to answer

**Slide 1, Demographic Composition and Diversity**
- How far is the company from the 50/50 gender target, overall and by level and department?
- Does gender influence salary, career progression, or role?
- Is the workforce young or ageing? What is the generational breakdown?
- How many employees are at retirement risk in the next 5 years, globally and by department?

**Slide 2, Well-Being, Performance and Ping Pong Impact**
- How many employees are satisfied vs. dissatisfied?
- How does satisfaction vary by department, gender, generation, role, and tenure?
- Is there a correlation between satisfaction and performance?
- What was the impact of the ping pong initiative across the five satisfaction dimensions?

**Slide 3, From Analysis to Decision**
- Is there a relationship between commute distance and satisfaction or performance?
- What are the turnover patterns by department, generation, and tenure stage?
- Is salary policy aligned with performance?
- What are the strategic recommendations based on the data?

---

## Repository Structure

```
ibm-hr-analytics-aidapt/
├── data/
│   ├── WA_Fn-UseC_-HR-Employee-Attrition.csv   # IBM HR dataset (source: Kaggle)
│   └── PingPongSurvey.xlsx                      # Post-initiative satisfaction survey
├── r/
│   └── IBM_HR_EDA.ipynb                         # Exploratory Data Analysis in R
├── sql/
│   ├── IBM_HR_Schema.sql                        # Main schema: staging, dimensions, facts, views
│   ├── IBM_HR_Alter_DateMovement.sql            # Alter: date_movement DATETIME2 → DATE
│   ├── IBM_HR_Alter_EnvironmentPct.sql          # Alter: add environment_satisfaction_pct
│   └── IBM_HR_PingPong_Integration.sql          # Ping Pong survey data integration
└── powerbi/
    ├── IBM_HR_Analytics_Dashboard.pbix
    └── screenshots/
        ├── slide1_demographic_composition.png
        ├── slide2_wellbeing_performance_pingpong.png
        └── slide3_analysis_to_decision.png
```

---

## Dataset

**IBM HR Analytics Employee Attrition & Performance**, sourced from [Kaggle](https://www.kaggle.com/datasets/pavansubhasht/ibm-hr-analytics-attrition-dataset).

- 1,470 employees across 3 departments and 9 job roles
- 35 variables covering demographics, compensation, satisfaction, and performance
- 16.9% attrition rate (237 employees left)

The **PingPongSurvey.xlsx** contains post-initiative satisfaction data for the 1,233 active employees, collected on 04/02/2026, used to measure the before/after impact of the ping pong initiative.

---

## Workflow

### 1. Exploratory Data Analysis, R (`r/`)

Conducted in Google Colab using R with `tidyverse`, `ggplot2`, `corrplot`, and `pheatmap`.

- Data structure inspection and quality checks
- Descriptive statistics and distribution analysis
- Visualisations: histograms, boxplots, correlation heatmaps
- Variable type correction (numeric → factor where appropriate)

### 2. Data Modelling, SQL Server (`sql/`)

Built a dimensional schema in SQL Server to support analytical queries and Power BI integration.

**Schema overview:**

```
stg_employee_raw (staging)
        ↓
d_employee ──→ f_employee_movement ←── d_department
         └──→ d_education                    ↑
         └──→ f_satisfaction          d_job_role
```

**Tables:**

| Table | Type | Description |
|---|---|---|
| `d_employee` | Dimension | Employee demographics and derived fields |
| `d_department` | Dimension | Departments |
| `d_job_role` | Dimension | Job roles and levels |
| `d_education` | Dimension | Education level and field |
| `f_employee_movement` | Fact | Employment, compensation, and performance data |
| `f_satisfaction` | Fact | Satisfaction metrics (baseline) |
| `f_satisfaction_history` | Fact | Satisfaction history: before and after Ping Pong |

> ⚠️ **Known limitation:** `d_education` is linked directly to `d_employee` instead of the fact table, which does not conform strictly to the star schema pattern. Identified as a future improvement.

**Subsequent alterations (applied after initial deployment):**

- `IBM_HR_Alter_DateMovement.sql`, changed `date_movement` from `DATETIME2` to `DATE` for semantic clarity and storage efficiency
- `IBM_HR_Alter_EnvironmentPct.sql`, added `environment_satisfaction_pct` to align with existing `job_satisfaction_pct`

### 3. Dashboard, Power BI (`powerbi/`)

Three-page dashboard built in Power BI Desktop (version 2.148.878.0, October 2025), connected directly to SQL Server.

---

## Dashboard

### Slide 1, Demographic Composition and Diversity

![Slide 1](https://raw.githubusercontent.com/bruno-braumann/ibm-hr-analytics-aidapt/main/powerbi/slide1_demographic_composition.png)

Gender distribution, job level breakdown, generational analysis, retirement risk by role, average salary by role and gender, and satisfaction by department.

### Slide 2, Well-Being, Performance and Ping Pong Impact

![Slide 2](https://raw.githubusercontent.com/bruno-braumann/ibm-hr-analytics-aidapt/main/powerbi/slide2_wellbeing_performance_pingpong.png)

Before/after satisfaction comparison across 5 dimensions (environment, job satisfaction, relationships, work-life balance, engagement), scatter plots for satisfaction vs performance and salary increase vs performance.

### Slide 3, From Analysis to Decision

![Slide 3](https://raw.githubusercontent.com/bruno-braumann/ibm-hr-analytics-aidapt/main/powerbi/slide3_analysis_to_decision.png)

Distance vs satisfaction, turnover by department and generation, attrition patterns by tenure, salary distribution, retirement risk by department, and strategic recommendations.

---

## Key Findings

- **Gender:** 59% male / 41% female, moderate deviation from parity, concentrated at entry levels
- **Ping Pong impact:** 54.9% of employees reported deterioration in overall well-being; only Job Involvement improved (+35.4%)
- **Attrition:** 68% of exits occur in the first 5 years, primarily in the Early (2–5 years) tenure group
- **Retirement risk:** 58 employees at risk in the next 5 years, with R&D most exposed (38 employees)
- **Salary equity:** No consistent gender pay gap identified across job roles

---

## Technologies

![SQL Server](https://img.shields.io/badge/SQL%20Server-T--SQL-CC2927?style=flat&logo=microsoftsqlserver&logoColor=white)
![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-F2C811?style=flat&logo=powerbi&logoColor=black)
![R](https://img.shields.io/badge/R-EDA-276DC3?style=flat&logo=r&logoColor=white)

---

*AiDAPT Course, Cegid Academy | Group Project*

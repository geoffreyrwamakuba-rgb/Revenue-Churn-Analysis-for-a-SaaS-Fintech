---------------------------------------------
-- 0. CLEAN-UP EXISTING OBJECTS
---------------------------------------------
DROP VIEW IF EXISTS Final_Report;
DROP TABLE IF EXISTS mrr_movements, movements, mrr_delta,
subscriptions, accounts, final_cohort_table,
NRR_Table, Churn_Rate, ER_pct,
Industry_Revenue,Industry_Churn_Rate;

---------------------------------------------
-- 1. CREATE RAW TABLES
---------------------------------------------

CREATE TABLE accounts (
    account_id INTEGER PRIMARY KEY NOT NULL, 
    signup_date DATE,
    churn_date DATE, 
    plan_type VARCHAR(20), 
    seats INTEGER, 
    business VARCHAR(20), 
    industry VARCHAR(30), 
    hq_location VARCHAR(30)
);

CREATE TABLE subscriptions (
    account_id INTEGER NOT NULL,
    month DATE NOT NULL,
    plan_type VARCHAR(20),
    seats INTEGER,
    mrr NUMERIC(12,2) NOT NULL
);

-- Constraints
ALTER TABLE subscriptions
ADD CONSTRAINT subscriptions_pk PRIMARY KEY (account_id, month);

ALTER TABLE subscriptions
ADD CONSTRAINT subs_account_fk
FOREIGN KEY (account_id) REFERENCES accounts(account_id);

-- Indexes
CREATE INDEX idx_subscriptions_month ON subscriptions(month);
CREATE INDEX idx_accounts_churn_date ON accounts(churn_date);
CREATE INDEX idx_accounts_signup_date ON accounts(signup_date);

---------------------------------------------
-- 2. IMPORT RAW DATA
---------------------------------------------
COPY accounts
FROM 'C:/Users/geoff/Downloads/Project 2 - SQL Reporting/accounts.csv'
DELIMITER ',' CSV HEADER;

COPY subscriptions
FROM 'C:/Users/geoff/Downloads/Project 2 - SQL Reporting/subscriptions.csv'
DELIMITER ',' CSV HEADER;

SELECT * FROM subscriptions;

---------------------------------------------
-- 3. CALCULATE MRR MOVEMENT
---------------------------------------------

CREATE TEMP TABLE mrr_delta AS
SELECT
    s.account_id,
    s.month,
    s.mrr AS current_mrr,
    LAG(s.mrr) OVER (PARTITION BY s.account_id ORDER BY s.month) AS previous_mrr
FROM subscriptions s;

CREATE TEMP TABLE movements AS
SELECT 
    m.account_id,
    m.month,
    m.previous_mrr,
    m.current_mrr,

    CASE WHEN m.previous_mrr IS NULL AND m.current_mrr > 0 
         THEN m.current_mrr ELSE 0 END AS new_mrr,

    CASE WHEN m.previous_mrr IS NOT NULL AND m.current_mrr > m.previous_mrr
         THEN m.current_mrr - m.previous_mrr ELSE 0 END AS expansion_mrr,

    CASE WHEN m.previous_mrr IS NOT NULL AND m.current_mrr < m.previous_mrr
         THEN m.previous_mrr - m.current_mrr ELSE 0 END AS contraction_mrr,

    CASE WHEN DATE_TRUNC('month', a.churn_date) = DATE_TRUNC('month', m.month)
         THEN m.previous_mrr ELSE 0 END AS churn_mrr

FROM mrr_delta m
LEFT JOIN accounts a ON a.account_id = m.account_id;

---------------------------------------------
-- 4. CREATE FINAL MRR MOVEMENTS TABLE
---------------------------------------------

CREATE TABLE mrr_movements (
    month DATE PRIMARY KEY,
    New_MRR NUMERIC(12,2),
    Expansion_MRR NUMERIC(12,2),
    Contraction_MRR NUMERIC(12,2),
    Churn_MRR NUMERIC(12,2),
    Total NUMERIC(12,2)
);

INSERT INTO mrr_movements (month, new_mrr, expansion_mrr, contraction_mrr, churn_mrr)
SELECT 
    month,
    SUM(new_mrr),
    SUM(expansion_mrr),
    -1 * SUM(contraction_mrr),
    -1 * SUM(churn_mrr)
FROM movements
GROUP BY month;

UPDATE mrr_movements
SET Total = New_MRR + Expansion_MRR + Contraction_MRR + Churn_MRR;

SELECT * FROM mrr_movements ORDER BY month;

---------------------------------------------
-- 5. COHORT ANALYSIS
---------------------------------------------

WITH quarter_sequence AS (
    SELECT DISTINCT DATE_TRUNC('quarter', month) AS quarter
    FROM subscriptions
),
quarterly_subscriptions AS (
    SELECT
        account_id,
        DATE_TRUNC('quarter', month) AS quarter,
        SUM(mrr) AS mrr
    FROM subscriptions
    GROUP BY account_id, DATE_TRUNC('quarter', month)
),
customer_quarters AS (
    SELECT
        a.account_id,
        DATE_TRUNC('quarter', a.signup_date) AS cohort_quarter,
        qs.quarter
    FROM accounts a
    CROSS JOIN quarter_sequence qs
    WHERE qs.quarter >= DATE_TRUNC('quarter', a.signup_date)
),
with_activity AS (
    SELECT 
        cq.*,
        COALESCE(qs.mrr, 0) AS mrr
    FROM customer_quarters cq
    LEFT JOIN quarterly_subscriptions qs
           ON qs.account_id = cq.account_id
          AND qs.quarter = cq.quarter
)
SELECT
    account_id,
    cohort_quarter,
    quarter,
    ((EXTRACT(YEAR FROM quarter) * 4 + EXTRACT(QUARTER FROM quarter))
      - (EXTRACT(YEAR FROM cohort_quarter) * 4 + EXTRACT(QUARTER FROM cohort_quarter))
    ) AS quarters_since_signup,
    mrr,
    CASE WHEN mrr > 0 THEN 1 ELSE 0 END AS retained_flag
FROM with_activity
ORDER BY account_id, quarter;

---------------------------------------------
-- 6. CREATE FINAL COHORT TABLE
---------------------------------------------

CREATE TABLE final_cohort_table (
    account_id INTEGER NOT NULL,
    cohort_quarter DATE,
    quarter DATE,
    quarters_since_signup INTEGER,
    mrr INTEGER,
    retained_flag INTEGER
);

INSERT INTO final_cohort_table
(account_id, cohort_quarter, quarter, quarters_since_signup, mrr, retained_flag)
(
WITH quarter_sequence AS (
    SELECT DISTINCT DATE_TRUNC('quarter', month) AS quarter
    FROM subscriptions
),
quarterly_subscriptions AS (
    SELECT
        account_id,
        DATE_TRUNC('quarter', month) AS quarter,
        SUM(mrr) AS mrr
    FROM subscriptions
    GROUP BY account_id, DATE_TRUNC('quarter', month)
),
customer_quarters AS (
    SELECT
        a.account_id,
        DATE_TRUNC('quarter', a.signup_date) AS cohort_quarter,
        qs.quarter
    FROM accounts a
    CROSS JOIN quarter_sequence qs
    WHERE qs.quarter >= DATE_TRUNC('quarter', a.signup_date)
),
with_activity AS (
    SELECT 
        cq.*,
        COALESCE(qs.mrr, 0) AS mrr
    FROM customer_quarters cq
    LEFT JOIN quarterly_subscriptions qs
           ON qs.account_id = cq.account_id
          AND qs.quarter = cq.quarter
)
SELECT
    account_id,
    cohort_quarter,
    quarter,
    ((EXTRACT(YEAR FROM quarter) * 4 + EXTRACT(QUARTER FROM quarter))
      - (EXTRACT(YEAR FROM cohort_quarter) * 4 + EXTRACT(QUARTER FROM cohort_quarter))
    ),
    mrr,
    CASE WHEN mrr > 0 THEN 1 ELSE 0 END
FROM with_activity
);

---------------------------------------------
-- 7. TOTAL MRR, MoM Change
---------------------------------------------

WITH monthly_mrr AS (
    SELECT
        DATE_TRUNC('month', month) AS month,
        SUM(total) OVER (ORDER BY month) AS cumulative_mrr
    FROM mrr_movements
)
SELECT
    month,
    cumulative_mrr / 1e6,
    LAG(cumulative_mrr / 1e6) OVER (ORDER BY month) AS previous_mrr,
    (cumulative_mrr - LAG(cumulative_mrr) OVER (ORDER BY month))
      / NULLIF(LAG(cumulative_mrr) OVER (ORDER BY month), 0) AS mom_change_pct
FROM monthly_mrr
ORDER BY month;

---------------------------------------------
-- 8. NET REVENUE RETENTION
---------------------------------------------

CREATE TEMP TABLE NRR_Table (
    month DATE,
    ending_mrr_existing INT,
    starting_mrr_existing INT,
    NRR NUMERIC(12,2)
);

INSERT INTO NRR_Table
(month, ending_mrr_existing, starting_mrr_existing, NRR)
(
WITH monthly AS (
    SELECT
        account_id,
        DATE_TRUNC('month', month) AS month,
        mrr
    FROM subscriptions
),
prev_curr AS (
    SELECT
        m.account_id,
        m.month,
        m.mrr AS current_mrr,
        LAG(m.mrr) OVER (PARTITION BY account_id ORDER BY month) AS previous_mrr
    FROM monthly m
)
SELECT
    month,
    SUM(current_mrr) FILTER (WHERE previous_mrr > 0),
    SUM(previous_mrr) FILTER (WHERE previous_mrr > 0),
    SUM(current_mrr) FILTER (WHERE previous_mrr > 0)
       / NULLIF(SUM(previous_mrr) FILTER (WHERE previous_mrr > 0), 0)
FROM prev_curr
GROUP BY month
);

---------------------------------------------
-- 9. CHURN RATE
---------------------------------------------

CREATE TEMP TABLE Churn_Rate (
    month DATE,
    active_last_month INT,
    churned_customers INT,
    customer_churn_rate NUMERIC(12,4)
);

INSERT INTO Churn_Rate
(month, active_last_month, churned_customers, customer_churn_rate)
(
WITH months AS (
    SELECT DISTINCT DATE_TRUNC('month', month) AS month
    FROM subscriptions
),
active_previous AS (
    SELECT
        m.month,
        COUNT(DISTINCT s.account_id) AS active_last_month
    FROM months m
    LEFT JOIN subscriptions s
        ON DATE_TRUNC('month', s.month) = m.month - INTERVAL '1 month'
    GROUP BY m.month
),
customers_churned AS (
    SELECT
        DATE_TRUNC('month', churn_date) AS churn_month,
        COUNT(DISTINCT account_id) AS churned_customers
    FROM accounts
    WHERE churn_date IS NOT NULL
    GROUP BY churn_month
)
SELECT
    ap.month,
    active_last_month,
    COALESCE(cc.churned_customers, 0),
    COALESCE(cc.churned_customers, 0)
        / NULLIF(active_last_month, 0)::DECIMAL
FROM active_previous ap
LEFT JOIN customers_churned cc
       ON ap.month = cc.churn_month
);

---------------------------------------------
-- 10. EXPANSION MRR %
---------------------------------------------

CREATE TEMP TABLE ER_pct (
    month DATE,
    expansion_mrr INT,
    new_mrr INT,
    expansion_revenue_pct NUMERIC(12,2)
);

INSERT INTO ER_pct
(month, expansion_mrr, new_mrr, expansion_revenue_pct)
SELECT
    month,
    expansion_mrr,
    new_mrr,
    expansion_mrr / NULLIF(expansion_mrr + new_mrr, 0)::DECIMAL
FROM mrr_movements;

---------------------------------------------
-- 11. REVENUE & CHURN REPORT
---------------------------------------------

CREATE VIEW Final_Report AS 
SELECT 
    m.month AS "Month",
    m.total AS "MRR_Change (USD)",
    SUM(m.total) OVER (ORDER BY m.month) AS "Total_MRR (USD)",
    ROUND(n.NRR,2) AS "NRR (%)",
    ROUND(c.customer_churn_rate,2) AS "Churn Rate (%)",
    ROUND(e.expansion_revenue_pct,2) AS "Expansion Revenue %"
FROM mrr_movements m
JOIN NRR_Table n ON m.month = n.month
JOIN Churn_Rate c ON m.month = c.month
JOIN ER_pct e ON m.month = e.month;

SELECT * FROM Final_Report ORDER BY "Month";


---------------------------------------------
-- 12. Churn Rate by Industry
---------------------------------------------

CREATE TABLE Industry_Churn_Rate AS
WITH quarters AS (
    SELECT DISTINCT DATE_TRUNC('quarter', month) AS quarter
    FROM subscriptions
),

active_previous AS (
    SELECT
        q.quarter,
        a.industry,
        COUNT(DISTINCT s.account_id) AS active_last_quarter
    FROM quarters q
    JOIN subscriptions s
        ON DATE_TRUNC('quarter', s.month) = q.quarter - INTERVAL '3 months'
    JOIN accounts a
        ON a.account_id = s.account_id
    GROUP BY q.quarter, a.industry
),

industry_churn AS (
    SELECT
        DATE_TRUNC('quarter', churn_date) AS churn_quarter,
        industry,
        COUNT(DISTINCT account_id) AS churned_customers
    FROM accounts
    WHERE churn_date IS NOT NULL
    GROUP BY 1, 2
)

SELECT
    ap.quarter,
    ap.industry,
    ap.active_last_quarter,
    COALESCE(ic.churned_customers, 0) AS churned_customers,
    COALESCE(ic.churned_customers, 0)::DECIMAL
        / NULLIF(ap.active_last_quarter, 0) AS churn_rate
FROM active_previous ap
LEFT JOIN industry_churn ic
       ON ap.quarter = ic.churn_quarter
      AND ap.industry = ic.industry;

SELECT * FROM Industry_Churn_Rate;

---------------------------------------------
-- 13. Revenue by Industry
---------------------------------------------
CREATE TABLE Industry_Revenue AS
SELECT
    DATE_TRUNC('month', s.month) AS month,
    a.industry,
    SUM(s.mrr) AS total_mrr
FROM subscriptions s
JOIN accounts a ON a.account_id = s.account_id
GROUP BY 1, 2;

SELECT * FROM Industry_Revenue ORDER BY month, industry;

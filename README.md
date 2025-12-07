# Revenue & Churn Insights for an Expense Management SaaS

## Executive Summary
This project uses SQL, Python, and Tableau to model, analyse, and visualise subscription revenue for an Expense Management SaaS platform.

The dashboard provides visibility into core SaaS revenue metrics, including:
- MRR trends & cumulative revenue
- MRR movement (New, Expansion, Contraction, Churn)
- Customer churn & revenue leakage
- Net Revenue Retention (NRR)
- Quarterly cohort retention

These insights support Finance, RevOps, Product, and Customer Success teams by quantifying revenue risks, identifying adoption issues, and showing where expansion opportunities occur.
## Dashboard
![alt text](https://github.com/geoffreyrwamakuba-rgb/Revenue-Churn-Analysis-for-a-SaaS-Fintech/blob/main/Dashboard%20Image.png?raw=true)

## Business Problem
Expense management platforms face several challenges:
- Understanding Expansion & Contraction Drivers
- Predicting Churn Before Revenue Loss
- Forecasting Revenue Accurately
  
## Methodology
### Data Source
Python was used to generate two datasets:
-	Accounts (customer profile, signup, churn, industry, seats)
-	Subscriptions (monthly MRR per account)
The model simulates 3 years of realistic behaviour based on patterns observed in real expense platforms (e.g., Ramp, Brex):

#### Assumptions Built Into the Data Generation include:
-	Churn Probability
-	Expansion Behaviour
-	Contraction Events & Plan upgrades

### SQL Analysis
**Generated SQL queries to calculate:**
- MRR Movements - Using LAG() to compare monthly MRR per account:
  - New, Expansion, Contraction & Churn MRR
- Quarterly Cohort Table - Cohorts grouped by signup quarter with:
  - Retained flags
  - Quarter-by-quarter activity
- Net Revenue Retention (NRR)
- Churn Rate
- Expansion MRR %

## Skills Demonstrated
- Advanced SQL (CTEs, window functions, views, constraints, indexing)
- Python (data generation with realistic assumptions)
- Tableau (dashboard design, KPIs, multi-chart layouts)
- SaaS metric interpretation (NRR, churn, expansion, cohorts)

## Key Insights & Recommendations
### Insight 1 – MRR Growth Is Driven More by Expansion Than New Sales
- Across most months, Expansion MRR > New MRR.
- Existing customers are increasing seats or upgrading plans.
- The product is sticky for customers who stay 3+ months.
- Customer Success and product experience are strong expansion drivers.
### Recommendation – Double down on expansion motions
- Identify features correlated with expansion (e.g., corporate cards, reimbursement workflows (Uber & Deliveroo)).
- Implement “adoption nudges” for companies with <60% seat activation.

### Insight 2 – Significant Drop in Retention after the first year
- Strong onboarding but weak customer loyalty
- Competitors may be pulling customers away
- There is a lack of customer tracking
### Recommendation – Differentiate products and track customers 
- Expand offering (audit automation or AI receipt extraction)
- Improve UX — expense tools with poor UX churn the fastest
- Create engagement triggers for low-activity or recently contracted accounts

## Next Steps
Strategic Enhancements
- Add **Customer Acquisition Cost** (CAC) data and calculate **LTV/CAC**
- Compare retention across industries to heighten focus
- Design A/B test for new product offering

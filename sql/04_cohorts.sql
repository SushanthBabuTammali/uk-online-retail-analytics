-- 04_cohorts.sql
-- Monthly acquisition cohorts: of the customers who first bought in month X,
-- what % bought again 1, 2, 3 ... months later?

CREATE OR REPLACE TABLE cohort_retention AS
WITH first_purchase AS (
    SELECT customer_id, date_trunc('month', min(invoice_ts))::DATE AS cohort_month
    FROM sales GROUP BY customer_id
),
activity AS (
    SELECT DISTINCT s.customer_id, f.cohort_month,
           date_diff('month', f.cohort_month, date_trunc('month', s.invoice_ts)::DATE) AS months_since
    FROM sales s JOIN first_purchase f USING (customer_id)
    WHERE s.invoice_ts < DATE '2011-12-01'   -- Dec 2011 is only 9 days: would look like a fake drop
),
sizes AS (
    SELECT cohort_month, count(*) AS cohort_size FROM first_purchase GROUP BY 1
)
SELECT a.cohort_month, s.cohort_size, a.months_since,
       count(*) AS active_customers,
       round(100.0 * count(*) / s.cohort_size, 1) AS retention_pct
FROM activity a JOIN sizes s USING (cohort_month)
WHERE a.cohort_month < DATE '2011-12-01'
GROUP BY a.cohort_month, s.cohort_size, a.months_since
ORDER BY a.cohort_month, a.months_since;

-- Average retention curve across cohorts (month 1, 2, 3 ...).
CREATE OR REPLACE TABLE retention_curve AS
SELECT months_since, round(avg(retention_pct), 1) AS avg_retention_pct, count(*) AS cohorts
FROM cohort_retention
WHERE months_since BETWEEN 1 AND 11
GROUP BY 1 ORDER BY 1;

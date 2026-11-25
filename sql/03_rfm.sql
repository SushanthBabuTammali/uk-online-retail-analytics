-- 03_rfm.sql
-- RFM segmentation: Recency, Frequency, Monetary value per customer.
-- Each metric is scored 1-5 with NTILE (quintiles); 5 is best.
-- Snapshot date = the day after the last invoice, as if we ran this the next morning.

CREATE OR REPLACE TABLE rfm AS
WITH snapshot AS (SELECT max(invoice_ts)::DATE + 1 AS snap FROM sales),
base AS (
    SELECT customer_id,
           date_diff('day', max(invoice_ts)::DATE, (SELECT snap FROM snapshot)) AS recency_days,
           count(DISTINCT invoice_no)                                           AS frequency,
           sum(revenue)                                                          AS monetary
    FROM sales
    GROUP BY customer_id
),
scored AS (
    SELECT *,
           6 - ntile(5) OVER (ORDER BY recency_days) AS r_score,  -- fewer days = better
           ntile(5) OVER (ORDER BY frequency)        AS f_score,
           ntile(5) OVER (ORDER BY monetary)         AS m_score
    FROM base
)
SELECT *,
       CASE
           WHEN r_score >= 4 AND f_score >= 4                 THEN 'Champions'
           WHEN r_score >= 3 AND f_score >= 3                 THEN 'Loyal'
           WHEN r_score >= 4 AND f_score <= 2                 THEN 'New / Promising'
           WHEN r_score <= 2 AND f_score >= 3                 THEN 'At Risk'
           WHEN r_score <= 2 AND f_score <= 2                 THEN 'Hibernating'
           ELSE 'Needs Attention'
       END AS segment
FROM scored;

CREATE OR REPLACE TABLE segment_summary AS
SELECT segment,
       count(*)                                     AS customers,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS pct_customers,
       round(sum(monetary), 0)                      AS revenue_gbp,
       round(100.0 * sum(monetary) / sum(sum(monetary)) OVER (), 1) AS pct_revenue,
       round(avg(recency_days), 0)                  AS avg_recency_days,
       round(avg(frequency), 1)                     AS avg_orders
FROM rfm
GROUP BY segment
ORDER BY revenue_gbp DESC;

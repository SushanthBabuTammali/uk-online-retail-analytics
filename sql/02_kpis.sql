-- 02_kpis.sql
-- Headline KPIs and monthly trend. Dec 2011 is a partial month (data ends 9 Dec),
-- so it is flagged rather than silently compared with full months.

CREATE OR REPLACE TABLE kpi_summary AS
SELECT
    round(sum(revenue), 0)                                   AS total_revenue_gbp,
    count(DISTINCT invoice_no)                               AS orders,
    count(DISTINCT customer_id)                              AS customers,
    round(sum(revenue) / count(DISTINCT invoice_no), 2)      AS avg_order_value_gbp,
    round(count(DISTINCT invoice_no) * 1.0
          / count(DISTINCT customer_id), 2)                  AS orders_per_customer,
    min(invoice_ts)::DATE                                    AS first_date,
    max(invoice_ts)::DATE                                    AS last_date
FROM sales;

CREATE OR REPLACE TABLE monthly AS
SELECT
    date_trunc('month', invoice_ts)::DATE      AS month,
    round(sum(revenue), 0)                     AS revenue_gbp,
    count(DISTINCT invoice_no)                 AS orders,
    count(DISTINCT customer_id)                AS active_customers,
    round(sum(revenue) / count(DISTINCT invoice_no), 2) AS aov_gbp,
    (date_trunc('month', invoice_ts)::DATE = DATE '2011-12-01') AS partial_month
FROM sales
GROUP BY ALL
ORDER BY 1;

-- Revenue by country: UK vs international share.
CREATE OR REPLACE TABLE by_country AS
SELECT country,
       round(sum(revenue), 0) AS revenue_gbp,
       count(DISTINCT customer_id) AS customers,
       round(100.0 * sum(revenue) / sum(sum(revenue)) OVER (), 1) AS revenue_share_pct
FROM sales
GROUP BY country
ORDER BY revenue_gbp DESC;

-- Top products by revenue.
CREATE OR REPLACE TABLE top_products AS
SELECT stock_code, any_value(description) AS description,
       sum(quantity) AS units, round(sum(revenue), 0) AS revenue_gbp
FROM sales
GROUP BY stock_code
ORDER BY revenue_gbp DESC
LIMIT 10;

-- Day-of-week x hour heat map data (when do customers order?).
CREATE OR REPLACE TABLE order_timing AS
SELECT dayname(invoice_ts) AS weekday, isodow(invoice_ts) AS dow,
       hour(invoice_ts) AS hour, count(DISTINCT invoice_no) AS orders
FROM sales
GROUP BY ALL
ORDER BY dow, hour;

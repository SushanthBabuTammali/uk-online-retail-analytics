-- 01_clean.sql
-- Load the raw UCI Online Retail file and build a clean sales table.
-- Rules (each one is a real data-quality issue found in the raw file):
--   * cancelled invoices start with 'C'          -> kept separately as returns
--   * rows with no CustomerID                    -> can't be used for customer analysis
--   * Quantity <= 0 or UnitPrice <= 0            -> adjustments, damages, test rows
--   * non-product stock codes (POST, M, DOT ...) -> postage / manual fees, not sales
--   * exact duplicate rows                       -> removed
--   * orders reversed by a matching cancellation -> removed (e.g. one 80,995-unit order
--     of "PAPER CRAFT, LITTLE BIRDIE" was cancelled minutes later and would otherwise
--     appear as the best-selling product)

CREATE OR REPLACE TABLE raw AS
SELECT *
FROM read_csv('data/online_retail.csv', header = true,
              types = {'InvoiceNo': 'VARCHAR', 'StockCode': 'VARCHAR', 'CustomerID': 'VARCHAR'});

-- Cancellation lines, used to find the original order lines they reverse.
CREATE OR REPLACE TABLE cancel_keys AS
SELECT DISTINCT CustomerID, StockCode, -Quantity AS Quantity
FROM raw
WHERE InvoiceNo LIKE 'C%' AND CustomerID IS NOT NULL;

CREATE OR REPLACE TABLE sales AS
SELECT DISTINCT
    InvoiceNo                                        AS invoice_no,
    StockCode                                        AS stock_code,
    trim(Description)                                AS description,
    Quantity                                         AS quantity,
    strptime(InvoiceDate, '%m/%d/%Y %H:%M')          AS invoice_ts,
    UnitPrice                                        AS unit_price,
    Quantity * UnitPrice                             AS revenue,
    CAST(CAST(CustomerID AS DOUBLE) AS INTEGER)      AS customer_id,
    Country                                          AS country
FROM raw
ANTI JOIN cancel_keys USING (CustomerID, StockCode, Quantity)
WHERE InvoiceNo NOT LIKE 'C%'
  AND CustomerID IS NOT NULL
  AND Quantity > 0
  AND UnitPrice > 0
  AND StockCode NOT IN ('POST', 'DOT', 'M', 'BANK CHARGES', 'PADS', 'CRUK', 'C2', 'D', 'AMAZONFEE', 'B', 'S');

CREATE OR REPLACE TABLE returns AS
SELECT InvoiceNo AS invoice_no, StockCode AS stock_code,
       -Quantity * UnitPrice AS refund_value,
       strptime(InvoiceDate, '%m/%d/%Y %H:%M') AS invoice_ts
FROM raw
WHERE InvoiceNo LIKE 'C%';

-- Data-quality summary: how many raw rows each rule removed.
CREATE OR REPLACE TABLE data_quality AS
SELECT 'raw rows'                       AS check_name, count(*) AS row_count FROM raw
UNION ALL SELECT 'cancelled / returns',  count(*) FROM raw WHERE InvoiceNo LIKE 'C%'
UNION ALL SELECT 'missing CustomerID',   count(*) FROM raw WHERE CustomerID IS NULL
UNION ALL SELECT 'non-positive qty/price', count(*) FROM raw WHERE Quantity <= 0 OR UnitPrice <= 0
UNION ALL SELECT 'orders reversed by a cancellation', count(*)
          FROM raw SEMI JOIN cancel_keys USING (CustomerID, StockCode, Quantity)
          WHERE InvoiceNo NOT LIKE 'C%'
UNION ALL SELECT 'clean sales rows',     count(*) FROM sales;

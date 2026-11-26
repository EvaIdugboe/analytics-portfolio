/*
AfriTech Electronics: illustrative PostgreSQL analysis queries.
Based on the case-study model: CustomerData, TransactionData, SocialMedia.
Requires populated tables; contains read-only statements only.
*/

-- Revenue trend and transaction volume by year
SELECT TransactionYear,
       ROUND(SUM(PurchaseAmount), 2) AS revenue_usd,
       COUNT(*) AS transactions,
       ROUND(AVG(PurchaseAmount), 2) AS average_order_value_usd
FROM TransactionData
GROUP BY TransactionYear
ORDER BY TransactionYear;

-- Customer segment revenue (join only CustomerData to TransactionData)
SELECT c.CustomerType,
       COUNT(DISTINCT c.CustomerID) AS purchasing_customers,
       ROUND(SUM(t.PurchaseAmount), 2) AS segment_revenue_usd,
       ROUND(SUM(t.PurchaseAmount) /
             NULLIF(COUNT(DISTINCT c.CustomerID), 0), 2) AS spend_per_purchasing_customer
FROM CustomerData AS c
JOIN TransactionData AS t
  ON t.CustomerID = c.CustomerID
GROUP BY c.CustomerType
ORDER BY segment_revenue_usd DESC;

-- Recall transaction rate and associated purchase amounts by product
SELECT ProductPurchased,
       COUNT(*) AS transactions,
       ROUND(100.0 * COUNT(*) FILTER (WHERE ProductRecalled IS TRUE)
             / NULLIF(COUNT(*), 0), 2) AS recall_rate_pct,
       ROUND(COALESCE(SUM(PurchaseAmount)
             FILTER (WHERE ProductRecalled IS TRUE), 0), 2) AS recall_linked_revenue_usd
FROM TransactionData
GROUP BY ProductPurchased
ORDER BY recall_rate_pct DESC;

-- Total engagements by platform
SELECT Platform,
       SUM(COALESCE(EngagementLikes, 0)
         + COALESCE(EngagementShares, 0)
         + COALESCE(EngagementComments, 0)) AS total_engagements
FROM SocialMedia
GROUP BY Platform
ORDER BY total_engagements DESC;

-- Share of social sentiment records
SELECT Sentiment,
       COUNT(*) AS post_records,
       ROUND(100.0 * COUNT(*) /
             NULLIF((SELECT COUNT(*) FROM SocialMedia), 0), 2) AS share_pct
FROM SocialMedia
GROUP BY Sentiment
ORDER BY post_records DESC;

-- Validate response-date intervals before making service-level claims
WITH intervals AS (
  SELECT (FirstResponseTime - CrisisEventTime) AS interval_days
  FROM SocialMedia
  WHERE FirstResponseTime IS NOT NULL
    AND CrisisEventTime IS NOT NULL
)
SELECT COUNT(*) AS observations,
       ROUND(AVG(interval_days), 2) AS mean_days,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP
             (ORDER BY interval_days)::numeric, 2) AS median_days,
       MIN(interval_days) AS minimum_days,
       MAX(interval_days) AS maximum_days,
       COUNT(*) FILTER (WHERE interval_days < 0) AS negative_intervals
FROM intervals;

/*
Do not join TransactionData to SocialMedia using CustomerID alone to
attribute a sentiment post to a product or purchase. That may multiply rows.
*/

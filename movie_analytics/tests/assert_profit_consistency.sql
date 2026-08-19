-- Fail if any row violates the rule:
-- profit_usd must be NULL when revenue or budget is NULL,
-- and must be NOT NULL when both are NOT NULL.
SELECT *
FROM {{ ref('fct_movie_performance') }}
WHERE (profit_usd IS NOT NULL AND (revenue_worldwide_usd IS NULL OR budget_usd IS NULL))
   OR (profit_usd IS NULL AND revenue_worldwide_usd IS NOT NULL AND budget_usd IS NOT NULL)
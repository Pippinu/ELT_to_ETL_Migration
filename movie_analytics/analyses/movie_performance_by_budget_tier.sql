-- GOOD QUERY
SELECT
    dm.budget_tier,
    COUNT(fmp.movie_key) AS total_movies,
    ROUND(SUM(fmp.profit_usd) / 1000000000, 3) AS total_profit_billions_usd,
    ROUND(SUM(fmp.revenue_worldwide_usd) / 1000000000, 3) AS total_revenue_billions_usd,
    -- Aggregate ROI
    ROUND(CAST(SUM(fmp.profit_usd) AS DOUBLE) / NULLIF(SUM(fmp.budget_usd), 0), 3) AS aggregate_roi_ratio,
    -- Aggregate Weighted Rating
    ROUND(CAST(SUM(fmp.weighted_score) AS DOUBLE) / NULLIF(SUM(fmp.vote_count), 0), 3) AS aggregate_rating
FROM main_marts.fct_movie_performance fmp
JOIN main_marts.dim_movie dm 
    ON fmp.movie_key = dm.movie_key
WHERE dm.budget_tier IS NOT NULL
GROUP BY dm.budget_tier
ORDER BY aggregate_roi_ratio DESC;
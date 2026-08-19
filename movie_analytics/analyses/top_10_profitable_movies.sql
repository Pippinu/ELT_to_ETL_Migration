-- Highest profit films, including ROI for reference
SELECT
    m.title,
    f.profit_usd,
    f.revenue_worldwide_usd,
    f.budget_usd,
    f.roi_ratio
FROM main_marts.fct_movie_performance f
JOIN main_marts.dim_movie m ON f.movie_key = m.movie_key
ORDER BY f.profit_usd DESC
LIMIT 10;
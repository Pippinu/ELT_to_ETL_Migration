-- GOOD QUERY

SELECT
    dd.decade,
    dg.genre_name,
    COUNT(DISTINCT fmp.movie_key) AS total_movies,
    ROUND(SUM(fmp.profit_usd) / 1000000, 3) AS total_profit_millions_usd,
    ROUND(SUM(fmp.budget_usd) / 1000000, 3) AS total_budget_millions_usd,
    -- Safely recalculating aggregate ROI to avoid averaging ratios
    ROUND(CAST(SUM(fmp.profit_usd) AS DOUBLE) / NULLIF(SUM(fmp.budget_usd), 0), 3) AS aggregate_roi
FROM main_marts.fct_movie_performance fmp
JOIN main_marts.bridge_movie_genre bmg 
    ON fmp.movie_key = bmg.movie_key
JOIN main_marts.dim_genre dg 
    ON bmg.genre_key = dg.genre_key
JOIN main_marts.dim_date dd 
    ON fmp.release_date_key = dd.date_key
WHERE dd.decade IS NOT NULL
    AND decade >= 1960 -- Exclude pre-war decades due to potential data inaccuracies
GROUP BY 
    dd.decade,
    dg.genre_name
HAVING aggregate_roi is not null
    AND total_movies > 30
ORDER BY 
    dd.decade DESC, 
    total_profit_millions_usd DESC;
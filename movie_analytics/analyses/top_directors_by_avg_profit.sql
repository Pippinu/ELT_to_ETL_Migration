-- GOOD QUERY

WITH first AS (
    SELECT
        dp.person_name,
        dcr.job,
        COUNT(DISTINCT fmc.movie_key) AS total_films,
        ROUND(SUM(fmp.profit_usd) / 1000000, 3) AS total_career_profit_millions_usd,
        ROUND(SUM(fmp.revenue_worldwide_usd) / 1000000, 3) AS total_career_revenue_millions_usd,
        -- Recalculating the weighted score: SUM(vote_count * vote_avg) / SUM(vote_count)
        ROUND((CAST(SUM(fmp.weighted_score) AS DOUBLE) / NULLIF(SUM(fmp.vote_count), 0)), 3) AS career_avg_rating,
    FROM main_marts.fct_movie_credit fmc
    JOIN main_marts.dim_person dp 
        ON fmc.person_key = dp.person_key
    JOIN main_marts.dim_credit_role dcr 
        ON fmc.credit_role_key = dcr.credit_role_key
    JOIN main_marts.fct_movie_performance fmp 
        ON fmc.movie_key = fmp.movie_key
    WHERE dcr.job = 'Director'
    GROUP BY 
        dp.person_name, 
        dcr.job
    HAVING 
        COUNT(DISTINCT fmc.movie_key) >= 5 -- Filter for established careers only
        AND career_avg_rating >= 7 -- Filter for quality careers only
)

SELECT 
    *,
    ROUND(total_career_profit_millions_usd / total_films, 3) AS avg_profit_per_film_millions_usd,
FROM first
ORDER BY avg_profit_per_film_millions_usd DESC
LIMIT 10;
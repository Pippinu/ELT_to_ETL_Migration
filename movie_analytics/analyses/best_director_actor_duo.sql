-- GOOD QUERY
SELECT
    dp_dir.person_name AS director_name,
    dp_act.person_name AS actor_name,
    COUNT(DISTINCT fmc_dir.movie_key) AS collaborative_films,
    ROUND(SUM(fmp.revenue_worldwide_usd) / 1000000.0, 3) AS combined_revenue_millions_usd,
    ROUND(SUM(fmp.profit_usd) / 1000000.0, 3) AS combined_profit_millions_usd,
    ROUND(CAST(SUM(fmp.weighted_score) AS DOUBLE) / NULLIF(SUM(fmp.vote_count), 0), 2) AS avg_collaborative_rating
FROM main_marts.fct_movie_credit fmc_dir
-- 1. Setup the Director side of the relationship
JOIN main_marts.dim_credit_role dcr_dir 
    ON fmc_dir.credit_role_key = dcr_dir.credit_role_key 
    AND dcr_dir.job = 'Director'
JOIN main_marts.dim_person dp_dir 
    ON fmc_dir.person_key = dp_dir.person_key
    
-- 2. Self-join to find Actors in the exact same movie
JOIN main_marts.fct_movie_credit fmc_act 
    ON fmc_dir.movie_key = fmc_act.movie_key
JOIN main_marts.dim_credit_role dcr_act 
    ON fmc_act.credit_role_key = dcr_act.credit_role_key 
    AND dcr_act.job = 'Original Music Composer'
JOIN main_marts.dim_person dp_act 
    ON fmc_act.person_key = dp_act.person_key
    
-- 3. Bring in the financial performance data
JOIN main_marts.fct_movie_performance fmp 
    ON fmc_dir.movie_key = fmp.movie_key
WHERE dp_dir.person_name != dp_act.person_name
GROUP BY 
    director_name, 
    actor_name
HAVING COUNT(DISTINCT fmc_dir.movie_key) >= 3 -- Filter for frequent collaborators
ORDER BY combined_profit_millions_usd DESC;
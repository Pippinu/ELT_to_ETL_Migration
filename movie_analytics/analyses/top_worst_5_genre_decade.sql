-- GOOD QUERY, da capire se ha senso selezionare range [100, 300] per total_movies
-- Select the top 5 and bottom 5 genres by average ROI for movies with a budget greater than $100 million, grouped by decade

(
    SELECT
        g.genre_name,
        d.decade,
        ROUND(SUM(f.profit_usd) / NULLIF(SUM(f.budget_usd), 0), 3) AS avg_roi,
        COUNT(DISTINCT f.movie_key) AS total_movies
    FROM main_marts.fct_movie_performance f
    JOIN main_marts.bridge_movie_genre bg ON f.movie_key = bg.movie_key
    JOIN main_marts.dim_genre g ON bg.genre_key = g.genre_key
    JOIN main_marts.dim_date d ON f.release_date_key = d.date_key
    WHERE f.budget_usd > 1000000
    GROUP BY g.genre_name, d.decade
    HAVING total_movies > 50
        AND total_movies < 300
    ORDER BY avg_roi DESC
    LIMIT 5
)
UNION ALL
(
    SELECT
        g.genre_name,
        d.decade,
        ROUND(SUM(f.profit_usd) / NULLIF(SUM(f.budget_usd), 0), 3) AS avg_roi,
        COUNT(DISTINCT f.movie_key) AS total_movies
    FROM main_marts.fct_movie_performance f
    JOIN main_marts.bridge_movie_genre bg ON f.movie_key = bg.movie_key
    JOIN main_marts.dim_genre g ON bg.genre_key = g.genre_key
    JOIN main_marts.dim_date d ON f.release_date_key = d.date_key
    WHERE f.budget_usd > 1000000
    GROUP BY g.genre_name, d.decade
    HAVING total_movies > 50 
        AND total_movies < 300
    ORDER BY avg_roi ASC
    LIMIT 5
);
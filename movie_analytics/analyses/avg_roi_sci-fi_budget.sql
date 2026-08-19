-- Select the top 5 and bottom 5 genres by average ROI for movies with a budget greater than $100 million, grouped by decade

(
    SELECT
        g.genre_name,
        d.decade,
        ROUND(SUM(f.profit_usd) / NULLIF(SUM(f.budget_usd), 0), 3) AS avg_roi
    FROM main_marts.fct_movie_performance f
    JOIN main_marts.bridge_movie_genre bg ON f.movie_key = bg.movie_key
    JOIN main_marts.dim_genre g ON bg.genre_key = g.genre_key
    JOIN main_marts.dim_date d ON f.release_date_key = d.date_key
    WHERE f.budget_usd > 1000000
        AND d.decade BETWEEN 1980 AND 2020
    GROUP BY g.genre_name, d.decade
    ORDER BY avg_roi DESC
    LIMIT 5
)
UNION ALL
(
    SELECT
        g.genre_name,
        d.decade,
        ROUND(SUM(f.profit_usd) / NULLIF(SUM(f.budget_usd), 0), 3) AS avg_roi
    FROM main_marts.fct_movie_performance f
    JOIN main_marts.bridge_movie_genre bg ON f.movie_key = bg.movie_key
    JOIN main_marts.dim_genre g ON bg.genre_key = g.genre_key
    JOIN main_marts.dim_date d ON f.release_date_key = d.date_key
    WHERE f.budget_usd > 1000000
        AND d.decade BETWEEN 1980 AND 2020
    GROUP BY g.genre_name, d.decade
    ORDER BY avg_roi ASC
    LIMIT 5
);

SELECT
    m.title,
    d.decade,
    f.revenue_worldwide_usd,
    f.profit_usd, 
    f.budget_usd,
FROM main_marts.fct_movie_performance f
JOIN main_marts.bridge_movie_genre bg ON f.movie_key = bg.movie_key
JOIN main_marts.dim_genre g ON bg.genre_key = g.genre_key
JOIN main_marts.dim_date d ON f.release_date_key = d.date_key
JOIN main_marts.dim_movie m ON f.movie_key = m.movie_key
WHERE f.budget_usd > 1000000
    AND d.decade = 2010
    AND g.genre_name = 'TV Movie';
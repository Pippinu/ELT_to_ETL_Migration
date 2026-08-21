-- GOOD QUERY
-- Worldwide revenue for Science Fiction films per decade
SELECT
    d.decade,
    SUM(f.revenue_worldwide_usd) / 1000000 AS "sci-fi revenue (per Million USD)"
FROM main_marts.fct_movie_performance f
JOIN main_marts.bridge_movie_genre bg ON f.movie_key = bg.movie_key
JOIN main_marts.dim_genre g ON bg.genre_key = g.genre_key
JOIN main_marts.dim_date d ON f.release_date_key = d.date_key
WHERE g.genre_name = 'Science Fiction'
GROUP BY d.decade
ORDER BY d.decade;
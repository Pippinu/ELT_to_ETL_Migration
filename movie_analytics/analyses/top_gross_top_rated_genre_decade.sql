-- GOOD QUERY
-- For each decade, the genre with highest total revenue and the genre with highest average rating
WITH genre_metrics AS (
    SELECT
        g.genre_name,
        d.decade,
        SUM(f.revenue_worldwide_usd) AS total_revenue,
        COUNT(DISTINCT f.movie_key) AS total_movies,
        AVG(f.vote_avg) AS avg_rating
    FROM main_marts.fct_movie_performance f
    JOIN main_marts.bridge_movie_genre bg ON f.movie_key = bg.movie_key
    JOIN main_marts.dim_genre g ON bg.genre_key = g.genre_key
    JOIN main_marts.dim_date d ON f.release_date_key = d.date_key
    GROUP BY g.genre_name, d.decade
    HAVING total_movies > 40
),
top_grossing AS (
    SELECT decade, genre_name AS top_grossing_genre, total_movies
    FROM genre_metrics
    QUALIFY ROW_NUMBER() OVER (PARTITION BY decade ORDER BY total_revenue DESC) = 1
),
top_rated AS (
    SELECT decade, genre_name AS top_rated_genre, total_movies
    FROM genre_metrics
    QUALIFY ROW_NUMBER() OVER (PARTITION BY decade ORDER BY avg_rating DESC) = 1
)

SELECT
    COALESCE(tg.decade, tr.decade) AS decade,
    tg.top_grossing_genre,
    tg.total_movies,
    tr.top_rated_genre,
    tr.total_movies
FROM top_grossing tg
FULL OUTER JOIN top_rated tr ON tg.decade = tr.decade
ORDER BY decade;
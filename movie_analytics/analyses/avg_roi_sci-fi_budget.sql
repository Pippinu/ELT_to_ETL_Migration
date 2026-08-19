-- ROI computed as total profit / total budget for the group (non‑additive measure)
SELECT
    SUM(f.profit_usd) / NULLIF(SUM(f.budget_usd), 0) AS avg_roi
FROM main_marts.fct_movie_performance f
JOIN main_marts.bridge_movie_genre bg ON f.movie_key = bg.movie_key
JOIN main_marts.dim_genre g ON bg.genre_key = g.genre_key
WHERE g.genre_name = 'Science Fiction'
  AND f.budget_usd > 100000000;
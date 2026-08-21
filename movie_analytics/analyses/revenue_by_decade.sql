-- Possibile iniziare con questa query per dimostrare che i film preguerra 
-- hanno dati finanziari probabilemente approssimati e non adeguati all'inflazione
-- quindi suggerisce di tagliare tali decadi dalle successive query

-- Total worldwide revenue per decade
SELECT
    d.decade,
    SUM(f.revenue_worldwide_usd) AS total_revenue
FROM main_marts.fct_movie_performance f
JOIN main_marts.dim_date d ON f.release_date_key = d.date_key
GROUP BY d.decade
ORDER BY d.decade;
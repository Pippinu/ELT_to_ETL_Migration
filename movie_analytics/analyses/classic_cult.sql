-- Movies with vote_avg >= 7.5 and worldwide revenue < $5M, sorted by highest rating

-- NO SENSE OLAP QUERY
SELECT
    m.title,
    f.vote_avg,
    f.revenue_worldwide_usd,
    f.vote_count
FROM main_marts.fct_movie_performance f
JOIN main_marts.dim_movie m ON f.movie_key = m.movie_key
WHERE f.vote_avg >= 7.5
  AND f.revenue_worldwide_usd BETWEEN 1 AND 5000000
  -- AND f.vote_count >= 1000
ORDER BY f.vote_avg DESC;
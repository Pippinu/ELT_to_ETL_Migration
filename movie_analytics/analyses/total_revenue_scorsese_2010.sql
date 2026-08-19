-- Sum of worldwide revenue for all movies Martin Scorsese worked on (any credit) in the 2010s
SELECT
    SUM(fp.revenue_worldwide_usd) AS total_revenue
FROM main_marts.fct_movie_credit fc
JOIN main_marts.dim_person p ON fc.person_key = p.person_key
JOIN main_marts.fct_movie_performance fp ON fc.movie_key = fp.movie_key
JOIN main_marts.dim_date d ON fc.release_date_key = d.date_key
WHERE p.person_name = 'Martin Scorsese'
  AND d.decade = 2010;
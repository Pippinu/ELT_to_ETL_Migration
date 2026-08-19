-- Shows the actor with the most distinct films in each decade
WITH actor_movies AS (
    SELECT
        p.person_name,
        d.decade,
        COUNT(DISTINCT f.movie_key) AS movie_count
    FROM main_marts.fct_movie_credit f
    JOIN main_marts.dim_person p ON f.person_key = p.person_key
    JOIN main_marts.dim_credit_role cr ON f.credit_role_key = cr.credit_role_key
    JOIN main_marts.dim_date d ON f.release_date_key = d.date_key
    WHERE cr.credit_type = 'CAST'
    GROUP BY p.person_name, d.decade
),
ranked AS (
    SELECT
        person_name,
        decade,
        movie_count,
        ROW_NUMBER() OVER (PARTITION BY decade ORDER BY movie_count DESC) AS rank
    FROM actor_movies
)
SELECT
    decade,
    person_name,
    movie_count
FROM ranked
WHERE rank = 1  -- change to e.g. <= 3 for top‑3 per decade
ORDER BY decade;
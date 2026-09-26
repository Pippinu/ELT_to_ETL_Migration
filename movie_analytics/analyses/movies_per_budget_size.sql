WITH movies_with_year AS (
    SELECT 
        budget_tier,
        year(release_date) AS release_year,
        movie_key
    FROM main_marts.dim_movie
),
pivoted AS (
    PIVOT movies_with_year
    ON budget_tier
    USING count(distinct movie_key)
    GROUP BY release_year
)
SELECT *
FROM pivoted
WHERE "Low Budget" > 0
  AND "Mid Budget" > 0
  AND "Blockbuster" > 0
ORDER BY release_year
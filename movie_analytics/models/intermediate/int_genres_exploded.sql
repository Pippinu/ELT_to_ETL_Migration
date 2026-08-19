-- dbt Best Practice Note: Explosion in Intermediate. 

-- We unnest the parsed JSON arrays in the intermediate layer to convert the array into rows. 

-- This maintains a clean separation of concerns: staging handles parsing, intermediate handles granularization. 
-- Using UNNEST with a CROSS JOIN LATERAL is the idiomatic DuckDB way to flatten JSON arrays without creating 
-- a performance bottleneck for downstream joins.

with stg_movies as (
    select
        tmdb_movie_id,
        title,
        genres_parsed
    from {{ ref('stg_tmdb_movies') }}
),

exploded as (
    select
        tmdb_movie_id,
        genre.id as genre_id,
        genre.name as genre_name
    from stg_movies
    cross join lateral unnest(genres_parsed) as genre(genre)
)

select * from exploded
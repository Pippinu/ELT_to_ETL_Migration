-- dbt Best Practice Note: Bridge Table for Many-to-Many Relationships. 

-- In Kimball modeling, a bridge table is the canonical solution for a M:N relationship 
-- between a fact and a dimension (or two dimensions). 

-- Unlike allocating weights, we use "full attribution", a movie contributes its full financial value to each associated genre. 
-- This bridge must never be joined directly to the performance fact for global totals (to avoid double-counting), 
-- but it is essential for filtering analysis (e.g., "revenue of Sci-Fi movies").

with exploded as (
    select
        tmdb_movie_id,
        genre_name
    from {{ ref('int_genres_exploded') }}
),

movie_dim as (
    select
        movie_key,
        tmdb_movie_id
    from {{ ref('dim_movie') }}
),

genre_dim as (
    select
        genre_key,
        genre_name
    from {{ ref('dim_genre') }}
)

select
    md.movie_key,
    gd.genre_key
from exploded e
inner join movie_dim md on e.tmdb_movie_id = md.tmdb_movie_id
inner join genre_dim gd on e.genre_name = gd.genre_name
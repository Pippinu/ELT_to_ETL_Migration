-- dbt Best Practice Note: Conformed Dimension for Slowly Changing Attributes. 

-- Genre names are relatively static but can evolve. 
-- By isolating them into their own dimension, we enable easy updates (e.g., renaming "Science Fiction" to "Sci-Fi") 
-- without touching the massive bridge or fact tables. 

-- This design follows the Kimball "Dimension Conformance" rule, ensuring all genre-based reports share the same authoritative list.

with genres as (
    select distinct
        genre_name
    from {{ ref('int_genres_exploded') }}
    where genre_name is not null
)

select
    row_number() over (order by genre_name) as genre_key,
    genre_name
from genres
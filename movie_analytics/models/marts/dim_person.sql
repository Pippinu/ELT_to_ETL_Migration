-- dbt Best Practice Note: Handling NULL Natural Keys. 

-- Since many persons in TMDB lack an IMDb imdb_person_id, we must generate a consistent surrogate key. 
-- However, we must also ensure person_key is deterministic. 
-- By ordering by imdb_person_id first (non-null) and then the TMDB name, 
-- we prevent duplicate keys for the same person, even if their IMDb ID is missing. 

-- This model also demonstrates dbt's "Single Source of Truth" rule—biographical data flows 
-- from the intermediate matching layer, keeping the mart layer clean.

with matched as (
    select
        tmdb_person_name,
        imdb_person_id,
        birth_year,
        death_year
    from {{ ref('int_person_matching') }}
),

final as (
    select
        row_number() over (order by coalesce(imdb_person_id, tmdb_person_name)) as person_key,
        tmdb_person_name as person_name,
        imdb_person_id,  -- Business key (can be NULL)
        birth_year,
        death_year
    from matched
)

select * from final
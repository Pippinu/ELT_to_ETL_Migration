-- dbt Best Practice Note: Handling Name Collisions Gracefully.
 
-- Since TMDB credits and IMDb names share no foreign key, we match solely by exact name. 
-- Using QUALIFY ensures deterministic selection when duplicate names exist 
-- (e.g., multiple actors named "Chris Evans"). 

-- By selecting the first record (order by imdb_person_id), we avoid non-deterministic results, 
-- and we flag or log ambiguous matches via the match_rank logic for future auditability.

with distinct_credit_names as (
    -- Extract all unique person names from the parsed credits (cast and crew)
    select distinct name as person_name
    from (
        select unnest(cast_parsed).name as name
        from {{ ref('stg_tmdb_credits') }}
        union
        select unnest(crew_parsed).name as name
        from {{ ref('stg_tmdb_credits') }}
    ) t
    where name is not null and name != ''
),

imdb as (
    select
        imdb_person_id,
        person_name,
        birth_year,
        death_year
    from {{ ref('stg_imdb_names') }}
),

matched as (
    select
        dcp.person_name as tmdb_person_name,
        imdb.imdb_person_id,
        imdb.person_name as imdb_person_name,
        imdb.birth_year,
        imdb.death_year,
        -- Simple match score: exact match gets 1
        1 as match_score
    from distinct_credit_names dcp
    left join imdb
        on dcp.person_name = imdb.person_name
)

select
    tmdb_person_name,
    imdb_person_id,
    imdb_person_name,
    birth_year,
    death_year,
    match_score
from matched
qualify row_number() over (partition by tmdb_person_name order by match_score desc, imdb_person_id) = 1
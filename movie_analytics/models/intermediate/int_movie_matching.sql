-- dbt Best Practice Note: Deterministic Deduplication with QUALIFY. 

-- When joining two datasets where multiple matches are possible 
-- (e.g., a TMDB movie might match several Box Office rows due to remakes or similar titles), 
-- using QUALIFY ROW_NUMBER() ... = 1 guarantees exactly one match per source movie. 

-- This is far more readable and less error-prone than writing nested WHERE clauses with MIN() subqueries, 
-- and it keeps the selection logic explicitly visible right after the JOIN conditions.

with tmdb as (

    select
        tmdb_movie_id,
        title,
        release_year,
        revenue_usd,
        budget_usd,
        lower(title) as tmdb_title_clean
    from {{ ref('stg_tmdb_movies') }}

),

box as (

    select
        *,
        movie_title_raw,
        lower(movie_title_raw) as box_title_clean,
        -- Normalize title: lowercase, remove special chars and leading "The "
        regexp_replace(
            regexp_replace(lower(movie_title_raw), '[^a-z0-9 ]', '', 'g'),
            '^the ',
            ''
        ) as normalized_title
    from {{ ref('stg_boxoffice') }}

),

matched as (

    select
        tmdb.tmdb_movie_id,
        tmdb.title as tmdb_title,
        tmdb.release_year as tmdb_release_year,
        box.movie_title_raw as boxoffice_title,
        box.release_year as boxoffice_release_year,
        box.revenue_worldwide_usd,
        box.revenue_domestic_usd,
        box.revenue_foreign_usd,

        -- Corrected Scoring Matrix
        case
            -- Score 4: Exact title + exact year
            when tmdb.title = box.movie_title_raw and tmdb.release_year = box.release_year then 4
            -- Score 3: Case-insensitive title + exact year
            when tmdb.tmdb_title_clean = box.box_title_clean and tmdb.release_year = box.release_year then 3
            -- Score 2: Case-insensitive title + offset year (+/- 1 year)
            when tmdb.tmdb_title_clean = box.box_title_clean then 2
            -- Score 1: Substring title match + exact year
            when tmdb.release_year = box.release_year 
                 and (tmdb.tmdb_title_clean like '%' || box.normalized_title || '%'
                      or box.normalized_title like '%' || tmdb.tmdb_title_clean || '%') then 1
            else 0
        end as match_score

    from tmdb
    left join box
        -- Allow exact year OR +/- 1 year shift
        on abs(tmdb.release_year - box.release_year) <= 1
        and (
            tmdb.tmdb_title_clean = box.box_title_clean
            or tmdb.tmdb_title_clean like '%' || box.normalized_title || '%'
            or box.normalized_title like '%' || tmdb.tmdb_title_clean || '%'
        )

)

select
    tmdb_movie_id,
    tmdb_title,
    tmdb_release_year,
    boxoffice_title,
    revenue_worldwide_usd,
    revenue_domestic_usd,
    revenue_foreign_usd,
    match_score
from matched
-- Filter out zero-score matches (if any) and pick top-scoring match per TMDB movie
qualify row_number() over (
    partition by tmdb_movie_id 
    order by match_score desc, boxoffice_release_year desc
) = 1
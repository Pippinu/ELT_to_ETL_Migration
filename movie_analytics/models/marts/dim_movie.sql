-- dbt Best Practice Note: Surrogate Keys in Dimensions. 

-- Using ROW_NUMBER() to generate a stable, integer surrogate key (movie_key) decouples the business key (tmdb_movie_id)
-- from the analytical model. 

-- If a movie is updated in the source (e.g., budget correction), the surrogate key remains unchanged, 
-- preserving historical relationships in fact tables. 
-- budget_tier is a classic derived attribute, computing it here centralizes the business rule, ensuring consistency across all reports.

with merged as (
    select
        tmdb_movie_id,
        title,
        release_date,
        release_year,
        budget_usd
    from {{ ref('int_merged_movie') }}
),

final as (
    select
        row_number() over (order by tmdb_movie_id) as movie_key,
        tmdb_movie_id,  -- Business key
        title,
        release_date,
        budget_usd,
        case
            when budget_usd < 10000000 then 'Low Budget'
            when budget_usd <= 50000000 then 'Mid Budget'
            else 'Blockbuster'
        end as budget_tier
    from merged
)

select * from final
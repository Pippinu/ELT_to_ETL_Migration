-- dbt Best Practice Note: Single Source of Truth for Financials. 

-- This model consolidates TMDB and Box Office data into a single, authoritative source of truth. 
-- By applying a COALESCE priority (Box Office > TMDB), we transparently document the data hierarchy. 

-- This centralized integration layer is critical because it prevents downstream fact tables 
-- from making inconsistent decisions about which financial metric to use, 
-- significantly improving data reliability and reducing duplicate logic.

with movies as (
    select
        tmdb_movie_id,
        title,
        release_date,
        release_year,
        budget_usd,
        revenue_usd as tmdb_revenue_usd,
        vote_avg,
        vote_count
    from {{ ref('stg_tmdb_movies') }}
),

boxoffice as (
    select
        tmdb_movie_id,
        revenue_worldwide_usd,
        revenue_domestic_usd,
        revenue_foreign_usd
    from {{ ref('int_movie_matching') }}
    where revenue_worldwide_usd is not null  -- Keep only movies with a Box Office match
),

merged as (
    select
        m.tmdb_movie_id,
        m.title,
        m.release_date,
        m.release_year,

        -- Priority: Box Office > TMDB
        coalesce(b.revenue_worldwide_usd, m.tmdb_revenue_usd) as revenue_worldwide_usd,

        b.revenue_domestic_usd,
        b.revenue_foreign_usd,
        m.budget_usd,
        m.vote_avg,
        m.vote_count

    from movies m
    left join boxoffice b on m.tmdb_movie_id = b.tmdb_movie_id
    where m.release_year is not null  -- Keep only movies with a release year
),

cleaned as (
    select
        tmdb_movie_id,
        title,
        release_date,
        release_year,

        -- Treat 0 as NULL for all revenue columns
        case when m.revenue_worldwide_usd = 0 then null else m.revenue_worldwide_usd end as revenue_worldwide_usd,
        case when m.revenue_domestic_usd = 0 then null else m.revenue_domestic_usd end as revenue_domestic_usd,
        case when m.revenue_foreign_usd = 0 then null else m.revenue_foreign_usd end as revenue_foreign_usd,
        case when m.budget_usd = 0 then null else m.budget_usd end as budget_usd,

        vote_avg,
        vote_count

    from merged m
)

select * from cleaned
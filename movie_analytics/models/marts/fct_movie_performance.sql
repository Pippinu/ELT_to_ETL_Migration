-- dbt Best Practice Note: Pre-Calculated Derived Measures in Facts. 

--Computing profit, weighted_score, and roi_ratio directly inside the fact table encapsulates complex business logic in one place. 

-- This ensures that all downstream BI tools simply aggregate these fields 
-- without needing to replicate these formulas. 

-- Furthermore, placing weighted_score in the fact table enables correct weighted averages 
-- (e.g., SUM(weighted_score)/SUM(vote_count)) for grouped analyses, solving the non-additive nature of vote_avg.

with merged as (
    select
        tmdb_movie_id,
        title,
        release_date,
        budget_usd,
        revenue_worldwide_usd,
        revenue_domestic_usd,
        revenue_foreign_usd,
        vote_avg,
        vote_count
    from {{ ref('int_merged_movie') }}
),

movie_dim as (
    select
        movie_key,
        tmdb_movie_id
    from {{ ref('dim_movie') }}
),

date_dim as (
    select
        date_key,
        full_date
    from {{ ref('dim_date') }}
),

final as (
    select
        md.movie_key,
        dd.date_key as release_date_key,
        -- Financials
        coalesce(m.revenue_worldwide_usd, 0) as revenue_worldwide_usd,
        coalesce(m.revenue_domestic_usd, 0) as revenue_domestic_usd,
        coalesce(m.revenue_worldwide_usd, 0) - coalesce(m.revenue_domestic_usd, 0) as revenue_foreign_usd,
        coalesce(m.budget_usd, 0) as budget_usd,
        -- Derived Measures
        (coalesce(m.revenue_worldwide_usd, 0) - coalesce(m.budget_usd, 0)) as profit_usd,
        coalesce(m.vote_count, 0) as vote_count,
        m.vote_avg,
        (coalesce(m.vote_count, 0) * coalesce(m.vote_avg, 0)) as weighted_score,
        -- ROI (Non-additive, but stored for point-in-time queries)
        case
            when coalesce(m.budget_usd, 0) = 0 then null
            else (coalesce(m.revenue_worldwide_usd, 0) - coalesce(m.budget_usd, 0)) / nullif(m.budget_usd, 0)
        end as roi_ratio
    from merged m
    inner join movie_dim md on m.tmdb_movie_id = md.tmdb_movie_id
    inner join date_dim dd on m.release_date = dd.full_date
)

select * from final
with merged as (
    select
        tmdb_movie_id,
        release_date,
        budget_usd,
        revenue_worldwide_usd,
        revenue_domestic_usd,
        revenue_foreign_usd,
        vote_avg,
        vote_count
    from {{ ref('int_merged_movie') }}  -- Already cleaned!
),

movie_dim as (
    select movie_key, tmdb_movie_id from {{ ref('dim_movie') }}
),

date_dim as (
    select date_key, full_date from {{ ref('dim_date') }}
),

final as (
    select
        md.movie_key,
        dd.date_key as release_date_key,

        m.revenue_worldwide_usd,
        m.revenue_domestic_usd,

        case
            when m.revenue_worldwide_usd is not null and m.revenue_domestic_usd is not null
            then m.revenue_worldwide_usd - m.revenue_domestic_usd
            else null
        end as revenue_international_usd,

        m.budget_usd,

        case
            when m.revenue_worldwide_usd is not null and m.budget_usd is not null
            then m.revenue_worldwide_usd - m.budget_usd
            else null
        end as profit_usd,

        m.vote_count,
        m.vote_avg,

        case
            when m.vote_count is not null and m.vote_avg is not null
            then m.vote_count * m.vote_avg
            else null
        end as weighted_score,

        case
            when profit_usd is not null and m.budget_usd > 0
            then profit_usd / m.budget_usd
            else null
        end as roi_ratio

    from merged m
    inner join movie_dim md on m.tmdb_movie_id = md.tmdb_movie_id
    inner join date_dim dd on m.release_date = dd.full_date
)

select * from final
-- 💡 dbt Best Practice Note: Single Responsibility for Staging. 
-- Staging models act purely as a "clean interface" to the raw data. 
-- By parsing JSON into structured arrays (from_json(...)) here, we shield downstream models from raw JSON parsing complexities. 
-- This keeps CTE code in intermediate layers lean and focused on business logic, 
-- and allows the database to cache the parsed structure efficiently.

with source as (
    select * from {{ source('raw', 'tmdb_movies') }}
),

renamed as (
    select
        -- Primary identifier
        -- For primary keys, foreign keys, and event identifiers, defaulting to BIGINT is standard practice for two main reasons:
        -- 1. If an INT primary key goes over 2B (upper bound for INT) the database will throw an overflow. BIGINT upperbound is way larger.
        -- 2. Modern Columnar Compression Nullifies the Storage Penalty.
        id::bigint as tmdb_movie_id,

        -- Titles
        title,
        original_title,

        -- Financials 
        -- Kept as fallback if boxoffice data is missing
        budget::double as budget_usd,
        revenue::double as revenue_usd,

        -- Dates
        release_date::date as release_date,
        extract(year from release_date::date)::int as release_year,

        -- Ratings
        vote_average::double as vote_avg,
        vote_count::bigint as vote_count,

        -- JSON: Parse genres into an array of structs for downstream explosion
        from_json(
            genres,
            '[{"id":"INTEGER", "name":"VARCHAR"}]'
        ) as genres_parsed,

        runtime::int,

        -- DROPPED: homepage, keywords, original_language, overview,
        -- popularity, production_companies, production_countries, spoken_languages,
        -- status, tagline
    from source
)

select * from renamed
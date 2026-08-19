-- dbt Best Practice Note: Declarative Column Cleaning. 

-- Instead of using complex regex later in every query, we clean string-based financial and percentage columns 
-- at the staging layer using DuckDB's replace and nullif.

-- This ensures downstream numeric aggregations are safe and the business logic 
-- (e.g., revenue_international = worldwide - domestic) operates on pristine data types.

-- dbt Best Practice Note: *"Select *" is an Anti-Pattern. 

-- Explicitly selecting only the columns needed downstream reduces the data processed by dbt, 
-- improves query performance, and makes the lineage crystal clear. 
-- Dropping irrelevant columns like Rank, % metrics, and raw Genres (which we source from TMDB) 
-- ensures our staging layer remains lightweight and focused.

with source as (

    select * from {{ source('raw', 'box_office') }}

),

renamed as (

    select
        -- Clean title (remove surrounding whitespace)
        trim("Release Group") as movie_title_raw,

        -- Cast to exact BIGINT dollars
        try_cast("$Worldwide" as bigint) as revenue_worldwide_usd,
        try_cast("$Domestic" as bigint) as revenue_domestic_usd,
        try_cast("$Foreign" as bigint) as revenue_foreign_usd,

        -- Release year
        try_cast("Year" as integer) as release_year

        -- DROPPED: "Domestic %", "Foreign %", "Rank", "Genres", "Rating"

    from source

)

select * from renamed
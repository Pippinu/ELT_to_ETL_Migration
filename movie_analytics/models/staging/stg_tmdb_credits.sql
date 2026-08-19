-- dbt Best Practice Note: Preserving Raw Granularity in Staging. 
-- We parse the JSON cast and crew arrays into structured columns without filtering or unnaming. 
-- This keeps the staging model at the same grain as the raw file (one row per movie). 
-- By deferring the UNNEST and whitelist filtering to the intermediate layer, we allow future analysts 
-- to reuse this clean staging model for other purposes (e.g., full cast lists), adhering to the DRY (Don't Repeat Yourself) principle.

with source as (
    select * from {{ source('raw', 'tmdb_credits') }}
),

renamed as (
    select
        movie_id::bigint as tmdb_movie_id,
        title,

        -- Parse cast JSON into an array of structs
        from_json(
            "cast",
            '[{"cast_id":"INTEGER", "character":"VARCHAR", "name":"VARCHAR", "order":"INTEGER"}]'
        ) as cast_parsed,

        -- Parse crew JSON into an array of structs
        from_json(
            crew,
            '[{"job":"VARCHAR", "name":"VARCHAR", "department":"VARCHAR"}]'
        ) as crew_parsed
    from source
)

select * from renamed
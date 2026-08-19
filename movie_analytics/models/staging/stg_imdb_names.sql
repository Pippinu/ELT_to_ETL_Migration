-- dbt Best Practice Note: Explicit Null Handling. 
-- Using nullif(trim(...), '') ensures that empty strings (common in CSVs) are correctly converted to NULL in the database. 
-- This is critical for fact tables where missing death years are expected, preventing downstream calculations (e.g., age) 
-- from interpreting blank strings as zero or causing errors.

with source as (
    select * from {{ source('raw', 'imdb_names') }}
),

renamed as (
    select
        nconst as imdb_person_id,
        primaryName as person_name,

        -- Handle birth/death year: empty strings should become NULL
        try_cast(nullif(trim(birthYear), '\N') as integer) as birth_year,
        try_cast(nullif(trim(deathYear), '\N') as integer) as death_year

        -- DROPPED: primaryProfession, knownForTitles
    from source
)

select * from renamed
-- dbt Best Practice Note: Factless Fact Table for Coverage Analysis. 

-- This table contains no numeric measures but allows powerful counting queries 
-- (COUNT(*), COUNT(DISTINCT movie_key)). 

-- The grain is "per credit occurrence"—a person can have both a cast and crew credit for the same movie. 

-- By joining to the dim_date dimension via the movie's release date, we enable time-series filmography analysis. 

-- This pattern is the standard for answering "which movies did this person work on?" without double-counting movie financials.

with credits as (
    select
        tmdb_movie_id,
        person_name,
        credit_type,
        job,
        department
    from {{ ref('int_credits_union') }}
),

movie_dim as (
    select
        movie_key,
        tmdb_movie_id,
        release_date
    from {{ ref('dim_movie') }}
),

person_dim as (
    select
        person_key,
        person_name
    from {{ ref('dim_person') }}
),

role_dim as (
    select
        credit_role_key,
        credit_type,
        job,
        department
    from {{ ref('dim_credit_role') }}
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
        pd.person_key,
        dd.date_key as release_date_key,
        rd.credit_role_key
    from credits c
    inner join movie_dim md on c.tmdb_movie_id = md.tmdb_movie_id
    inner join person_dim pd on c.person_name = pd.person_name
    inner join role_dim rd on c.credit_type = rd.credit_type
                           and c.job = rd.job
                           and c.department = rd.department
    inner join date_dim dd on md.release_date = dd.full_date
)

select * from final
-- dbt Best Practice Note: Strategic Business Filtering in Intermediate. 

-- The crew whitelist is a strict business rule (defining "top production roles"). 
-- Applying it in the intermediate layer, rather than staging, ensures our staging data remains a pristine raw copy. 
-- Additionally, we explicitly hardcode the cast roles (CAST/Actor/Acting) 
-- and the whitelist in a CTE called top_roles, making the filter easily maintainable i
-- if the business definition changes later.

with stg_credits as (
    select
        tmdb_movie_id,
        cast_parsed,
        crew_parsed
    from {{ ref('stg_tmdb_credits') }}
),

-- Define the whitelist of top production roles
top_roles as (
    select 'Director' as job union all
    select 'Writer' union all
    select 'Producer' union all
    select 'Executive Producer' union all
    select 'Director of Photography' union all
    select 'Original Music Composer'
),

cast_unnested as (
    select
        tmdb_movie_id,
        cast_member.name as person_name,
        'CAST' as credit_type,
        'Actor' as job,
        'Acting' as department,
        cast_member.character as character_name
    from stg_credits
    cross join lateral unnest(cast_parsed) as cast_member(cast_member)
    where cast_member.name is not null
),

crew_unnested as (
    select
        tmdb_movie_id,
        crew_member.name as person_name,
        'CREW' as credit_type,
        crew_member.job as job,
        crew_member.department as department,
        null as character_name
    from stg_credits
    cross join lateral unnest(crew_parsed) as crew_member(crew_member)
    where crew_member.name is not null
),

-- Apply the whitelist filter on crew
filtered_crew as (
    select
        cu.*
    from crew_unnested cu
    inner join top_roles tr on cu.job = tr.job
),

-- Union cast (all) and filtered crew
union_credits as (
    select * from cast_unnested
    union all
    select * from filtered_crew
)

-- Deduplicate by taking one row per (tmdb_movie_id, person_name, credit_type, job, department). 
-- Keep the first character_name if multiple exist.
select
    tmdb_movie_id,
    person_name,
    credit_type,
    job,
    department,
    character_name
from union_credits
qualify row_number() over (
    partition by tmdb_movie_id, person_name, credit_type, job, department
    order by character_name
) = 1
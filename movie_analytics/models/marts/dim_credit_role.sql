-- dbt Best Practice Note: Conformed Small Dimensions. 

-- Credit roles are a classic "junk dimension, small, stable, and low-cardinality. 
-- By building a distinct list here, we ensure that fct_movie_credit joins to a single, consistent table. 

-- This pattern prevents the "slowly changing dimension" headache; 
-- if a new job appears (e.g., "Virtual Production Supervisor"), the dimension simply grows, and all existing keys remain valid.

with credit_roles as (
    select distinct
        credit_type,
        job,
        department
    from {{ ref('int_credits_union') }}
    where credit_type is not null and job is not null
),

final as (
    select
        row_number() over (order by credit_type, job, department) as credit_role_key,
        credit_type,
        job,
        department
    from credit_roles
)

select * from final
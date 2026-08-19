-- dbt Best Practice Note: Build a Complete Date Dimension. 

-- Manually generating a date spine (1900–2050) guarantees that every possible reporting date has a row, 
-- even if no movie was released on that day. 

-- This ensures that LEFT JOINs to the date dimension never produce NULL keys in downstream reports. 
-- Pre-calculating attributes like decade, month_name, and day_of_week shifts computational cost 
-- from query time to build time, significantly speeding up BI tools.

with date_spine as (
    select
        (date '1900-01-01' + interval (n) day)::date as full_date
    from unnest(generate_series(0, datediff('day', date '1900-01-01', date '2050-12-31'))) as t(n)
),

final as (
    select
        -- Surrogate key: YYYYMMDD integer (standard for date dimensions)
        cast(strftime(full_date, '%Y%m%d') as integer) as date_key,
        full_date,
        date_part('day', full_date)::int as day,
        date_part('month', full_date)::int as month_number,
        monthname(full_date) as month_name,
        date_part('year', full_date)::int as year,
        (floor(date_part('year', full_date) / 10) * 10)::int as decade
    from date_spine
)

select * from final
with month_numbers as (
    select
        row_number() over (order by seq4()) - 1 as month_offset -- seq4() is used to sort the generated rows from 'generator'
        -- Use both seq4() and row_number() ensure the numbers are consistent.
    from table(generator(rowcount => 120))-- generate 120 rows for this table 

),

month_spine as (
    select 
        dateadd(
            month,
            month_offset,
            '2015-10-01'::date 
        ) as month_date

    from month_numbers

)

select
    month_date,

    last_day(month_date) as month_end_date,

    year(month_date) * 100
        +month(month_date) as month_key,

    year(month_date) as year_number,

    month(month_date) as month_number,
    --transfer month number be eng
    to_char(month_date, 'Mon') as month_name_short,

    -- Show how many days in this month
    day(last_day(month_date)) as day_in_month

from month_spine

where month_date <= '2023-11-01'::date 
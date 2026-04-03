
    
    

with all_values as (

    select
        credit_tier as value_field,
        count(*) as n_records

    from `silver`.`users_silver`
    group by credit_tier

)

select *
from all_values
where value_field not in (
    'standard','premium','vip'
)



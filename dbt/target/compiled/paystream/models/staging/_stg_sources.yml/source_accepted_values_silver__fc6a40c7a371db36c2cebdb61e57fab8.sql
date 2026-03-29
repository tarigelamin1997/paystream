
    
    

with all_values as (

    select
        status as value_field,
        count(*) as n_records

    from `silver`.`transactions_silver`
    group by status

)

select *
from all_values
where value_field not in (
    'approved','declined','pending','cancelled'
)



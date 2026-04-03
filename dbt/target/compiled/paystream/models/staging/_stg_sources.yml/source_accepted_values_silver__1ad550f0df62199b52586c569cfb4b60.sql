
    
    

with all_values as (

    select
        status as value_field,
        count(*) as n_records

    from `silver`.`installments_silver`
    group by status

)

select *
from all_values
where value_field not in (
    'active','completed','defaulted'
)



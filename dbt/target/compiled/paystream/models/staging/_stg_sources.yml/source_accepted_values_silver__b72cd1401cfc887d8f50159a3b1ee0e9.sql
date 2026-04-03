
    
    

with all_values as (

    select
        kyc_status as value_field,
        count(*) as n_records

    from `silver`.`users_silver`
    group by kyc_status

)

select *
from all_values
where value_field not in (
    'approved','pending','rejected'
)



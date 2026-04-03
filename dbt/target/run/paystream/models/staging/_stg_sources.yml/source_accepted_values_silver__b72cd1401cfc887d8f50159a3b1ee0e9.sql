
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

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



    ) dbt_internal_test
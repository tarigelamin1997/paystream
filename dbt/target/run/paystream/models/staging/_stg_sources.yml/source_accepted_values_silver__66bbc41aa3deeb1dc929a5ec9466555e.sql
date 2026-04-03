
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

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



    ) dbt_internal_test
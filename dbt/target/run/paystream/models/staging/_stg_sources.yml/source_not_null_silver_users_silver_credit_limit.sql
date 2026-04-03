
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select credit_limit
from `silver`.`users_silver`
where credit_limit is null



    ) dbt_internal_test
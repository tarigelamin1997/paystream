
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select merchant_category
from `silver`.`merchants_silver`
where merchant_category is null



    ) dbt_internal_test

    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select transaction_id
from `silver`.`repayments_silver`
where transaction_id is null



    ) dbt_internal_test
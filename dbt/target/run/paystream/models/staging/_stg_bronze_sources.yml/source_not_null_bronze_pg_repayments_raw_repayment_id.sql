
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select repayment_id
from `bronze`.`pg_repayments_raw`
where repayment_id is null



    ) dbt_internal_test
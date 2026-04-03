
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select schedule_id
from `silver`.`installments_silver`
where schedule_id is null



    ) dbt_internal_test
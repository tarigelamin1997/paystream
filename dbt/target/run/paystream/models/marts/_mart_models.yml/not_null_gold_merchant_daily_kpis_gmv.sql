
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select gmv
from `gold`.`gold_merchant_daily_kpis`
where gmv is null



    ) dbt_internal_test
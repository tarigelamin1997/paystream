
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select event_id
from `bronze`.`mongo_app_events_raw`
where event_id is null



    ) dbt_internal_test
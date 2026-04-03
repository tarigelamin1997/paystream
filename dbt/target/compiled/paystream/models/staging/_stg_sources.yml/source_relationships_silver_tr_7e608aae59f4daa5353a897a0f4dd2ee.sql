
    
    

with child as (
    select merchant_id as from_field
    from `silver`.`transactions_silver`
    where merchant_id is not null
),

parent as (
    select merchant_id as to_field
    from `silver`.`merchants_silver`
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null
-- end_of_sql
settings join_use_nulls = 1



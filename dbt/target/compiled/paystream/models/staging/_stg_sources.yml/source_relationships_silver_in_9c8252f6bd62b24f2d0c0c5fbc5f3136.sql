
    
    

with child as (
    select transaction_id as from_field
    from `silver`.`installments_silver`
    where transaction_id is not null
),

parent as (
    select transaction_id as to_field
    from `silver`.`transactions_silver`
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null
-- end_of_sql
settings join_use_nulls = 1



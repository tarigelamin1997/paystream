
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      with relation_columns as (

        
        select
            cast('TRANSACTION_ID' as String) as relation_column,
            cast('INT64' as String) as relation_column_type
        union all
        
        select
            cast('USER_ID' as String) as relation_column,
            cast('INT64' as String) as relation_column_type
        union all
        
        select
            cast('MERCHANT_ID' as String) as relation_column,
            cast('INT32' as String) as relation_column_type
        union all
        
        select
            cast('AMOUNT' as String) as relation_column,
            cast('DECIMAL(12, 2)' as String) as relation_column_type
        union all
        
        select
            cast('CURRENCY' as String) as relation_column,
            cast('STRING' as String) as relation_column_type
        union all
        
        select
            cast('STATUS' as String) as relation_column,
            cast('STRING' as String) as relation_column_type
        union all
        
        select
            cast('DECISION_LATENCY_MS' as String) as relation_column,
            cast('INT16' as String) as relation_column_type
        union all
        
        select
            cast('INSTALLMENT_COUNT' as String) as relation_column,
            cast('INT16' as String) as relation_column_type
        union all
        
        select
            cast('CREATED_AT' as String) as relation_column,
            cast('DATETIME64(3)' as String) as relation_column_type
        union all
        
        select
            cast('_INGESTED_AT' as String) as relation_column,
            cast('DATETIME' as String) as relation_column_type
        
        
    ),
    test_data as (

        select
            *
        from
            relation_columns
        where
            relation_column = 'AMOUNT'
            and
            relation_column_type not in ('DECIMAL(18, 2)')

    )
    select *
    from test_data
    ) dbt_internal_test
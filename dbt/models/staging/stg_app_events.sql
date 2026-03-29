-- Staging: app events — extract known JSON fields
SELECT
    event_id,
    user_id,
    event_type,
    merchant_id,
    session_id,
    device_type,
    event_data,
    created_at
FROM {{ source('silver', 'app_events_silver') }}

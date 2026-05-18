SELECT
    run_id,
    fetched_at,
    source_name,
    forecast_days,
    status
FROM staging.pipeline_runs
ORDER BY fetched_at DESC
LIMIT 5;

SELECT
    location_id,
    location_name,
    county,
    latitude,
    longitude
FROM mart.dim_location
WHERE is_active
ORDER BY display_order, location_name;

SELECT
    location_name,
    window_start,
    window_end,
    avg_combined_score,
    avg_temperature_c,
    total_precipitation_mm,
    max_precipitation_probability_pct,
    max_wind_speed_ms,
    recommendation_label,
    main_reason
FROM mart.latest_outdoor_activity_windows
ORDER BY avg_combined_score DESC, window_start
LIMIT 10;

SELECT
    test_name,
    status,
    failed_rows,
    message
FROM quality.test_results
ORDER BY test_name;
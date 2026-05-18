TRUNCATE TABLE quality.test_results;

WITH latest_run AS (
    SELECT run_id
    FROM staging.pipeline_runs
    WHERE status = 'success'
    ORDER BY fetched_at DESC
    LIMIT 1
),
test_cases AS (
    SELECT
        'dim_location_has_active_rows' AS test_name,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM mart.dim_location
                WHERE is_active
            )
                THEN 0
            ELSE 1
        END AS failed_rows,
        'Asukohtade dimensioonis peab olema vähemalt üks aktiivne rida.' AS message

    UNION ALL

    SELECT
        'active_locations_have_coordinates' AS test_name,
        COUNT(*)::integer AS failed_rows,
        'Aktiivsetel asukohtadel peavad olema koordinaadid.' AS message
    FROM mart.dim_location
    WHERE is_active
      AND (
          latitude IS NULL
          OR longitude IS NULL
          OR latitude < 57
          OR latitude > 60
          OR longitude < 21
          OR longitude > 29
      )

    UNION ALL

    SELECT
        'weather_raw_has_rows' AS test_name,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM staging.weather_hourly_raw AS w
                INNER JOIN latest_run AS r ON w.run_id = r.run_id
            )
                THEN 0
            ELSE 1
        END AS failed_rows,
        'Viimasel edukal laadimisel peab olema vähemalt üks ilmarida.' AS message

    UNION ALL

    SELECT
        'latest_run_has_active_locations' AS test_name,
        COUNT(*)::integer AS failed_rows,
        'Viimasel edukal laadimisel peavad olema kõik aktiivsed asukohad dimensioonitabelist.' AS message
    FROM mart.dim_location AS l
    LEFT JOIN latest_run AS r
        ON TRUE
    LEFT JOIN staging.weather_hourly_raw AS w
        ON r.run_id = w.run_id
       AND l.location_id = w.location_id
    WHERE l.is_active
      AND w.location_id IS NULL

    UNION ALL

    SELECT
        'forecast_time_not_null' AS test_name,
        COUNT(*)::integer AS failed_rows,
        'Prognoosi aeg ei tohi puududa.' AS message
    FROM staging.weather_hourly_raw AS w
    INNER JOIN latest_run AS r ON w.run_id = r.run_id
    WHERE w.forecast_time IS NULL

    UNION ALL

    SELECT
        'unique_location_time_per_run' AS test_name,
        COUNT(*)::integer AS failed_rows,
        'Sama käivituse, asukoha ja tunni kohta tohib olla üks rida.' AS message
    FROM (
        SELECT
            w.run_id,
            w.location_id,
            w.forecast_time,
            COUNT(*) AS row_count
        FROM staging.weather_hourly_raw AS w
        INNER JOIN latest_run AS r ON w.run_id = r.run_id
        GROUP BY
            w.run_id,
            w.location_id,
            w.forecast_time
        HAVING COUNT(*) > 1
    ) AS duplicates

    UNION ALL

    SELECT
        'temperature_reasonable' AS test_name,
        COUNT(*)::integer AS failed_rows,
        'Temperatuur peab jääma vahemikku -50 kuni 50 kraadi.' AS message
    FROM staging.weather_hourly_raw AS w
    INNER JOIN latest_run AS r ON w.run_id = r.run_id
    WHERE w.temperature_c IS NULL
       OR w.temperature_c < -50
       OR w.temperature_c > 50

    UNION ALL

    SELECT
        'precipitation_not_negative' AS test_name,
        COUNT(*)::integer AS failed_rows,
        'Sademed ei tohi olla negatiivsed.' AS message
    FROM staging.weather_hourly_raw AS w
    INNER JOIN latest_run AS r ON w.run_id = r.run_id
    WHERE w.precipitation_mm IS NULL
       OR w.precipitation_mm < 0

    UNION ALL

    SELECT
        'precipitation_probability_range' AS test_name,
        COUNT(*)::integer AS failed_rows,
        'Sademete tõenäosus peab jääma vahemikku 0 kuni 100 protsenti.' AS message
    FROM staging.weather_hourly_raw AS w
    INNER JOIN latest_run AS r ON w.run_id = r.run_id
    WHERE w.precipitation_probability_pct IS NULL
       OR w.precipitation_probability_pct < 0
       OR w.precipitation_probability_pct > 100

    UNION ALL

    SELECT
        'wind_speed_reasonable' AS test_name,
        COUNT(*)::integer AS failed_rows,
        'Tuulekiirus peab jääma vahemikku 0 kuni 60 m/s.' AS message
    FROM staging.weather_hourly_raw AS w
    INNER JOIN latest_run AS r ON w.run_id = r.run_id
    WHERE w.wind_speed_ms IS NULL
       OR w.wind_speed_ms < 0
       OR w.wind_speed_ms > 60

    UNION ALL

    SELECT
        'is_day_valid' AS test_name,
        COUNT(*)::integer AS failed_rows,
        'Päevavalguse tunnus peab olema 0 või 1.' AS message
    FROM staging.weather_hourly_raw AS w
    INNER JOIN latest_run AS r ON w.run_id = r.run_id
    WHERE w.is_day IS NULL
       OR w.is_day NOT IN (0, 1)

    UNION ALL

    SELECT
        'combined_score_range' AS test_name,
        COUNT(*)::integer AS failed_rows,
        'Kombineeritud sobivuse skoor peab jääma vahemikku 0 kuni 100.' AS message
    FROM mart.hourly_weather_score AS h
    INNER JOIN latest_run AS r ON h.run_id = r.run_id
    WHERE h.combined_score < 0
       OR h.combined_score > 100

    UNION ALL

    SELECT
        'mart_daily_summary_has_rows' AS test_name,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM mart.latest_daily_weather_summary
            )
                THEN 0
            ELSE 1
        END AS failed_rows,
        'Päevane koondtabel peab sisaldama näidikulaua ridu.' AS message

    UNION ALL

    SELECT
        'mart_outdoor_windows_has_rows' AS test_name,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM mart.latest_outdoor_activity_windows
            )
                THEN 0
            ELSE 1
        END AS failed_rows,
        'Ajaakende tabel peab sisaldama välitegevuste soovitusi.' AS message
)
INSERT INTO quality.test_results (
    test_name,
    status,
    failed_rows,
    message
)
SELECT
    test_name,
    CASE WHEN failed_rows = 0 THEN 'passed' ELSE 'failed' END AS status,
    failed_rows,
    message
FROM test_cases
ORDER BY test_name;
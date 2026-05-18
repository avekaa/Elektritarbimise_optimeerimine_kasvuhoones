TRUNCATE TABLE
    mart.outdoor_activity_windows,
    mart.hourly_weather_score,
    mart.daily_weather_summary,
    mart.fact_weather_forecast;

INSERT INTO mart.fact_weather_forecast (
    run_id,
    location_id,
    forecast_time,
    forecast_date,
    temperature_c,
    precipitation_mm,
    precipitation_probability_pct,
    wind_speed_ms,
    is_day,
    fetched_at
)
SELECT
    run_id,
    location_id,
    forecast_time,
    forecast_time::date AS forecast_date,
    temperature_c,
    precipitation_mm,
    precipitation_probability_pct,
    wind_speed_ms,
    is_day,
    fetched_at
FROM staging.weather_hourly_raw;

INSERT INTO mart.hourly_weather_score (
    run_id,
    location_id,
    location_name,
    forecast_time,
    forecast_date,
    forecast_hour,
    temperature_c,
    precipitation_mm,
    precipitation_probability_pct,
    wind_speed_ms,
    is_day,
    temperature_score,
    precipitation_score,
    wind_score,
    daylight_score,
    combined_score,
    suitability_label,
    main_reason
)
WITH scored AS (
    SELECT
        f.run_id,
        f.location_id,
        l.location_name,
        f.forecast_time,
        f.forecast_date,
        EXTRACT(HOUR FROM f.forecast_time)::integer AS forecast_hour,
        f.temperature_c,
        f.precipitation_mm,
        f.precipitation_probability_pct,
        f.wind_speed_ms,
        f.is_day,
        CASE
            WHEN f.temperature_c IS NULL THEN 0
            WHEN f.temperature_c BETWEEN 16 AND 24 THEN 30
            WHEN f.temperature_c BETWEEN 12 AND 28 THEN 22
            WHEN f.temperature_c BETWEEN 8 AND 30 THEN 12
            ELSE 0
        END AS temperature_score,
        CASE
            WHEN f.precipitation_mm IS NULL
              OR f.precipitation_probability_pct IS NULL THEN 0
            WHEN f.precipitation_mm = 0
              AND f.precipitation_probability_pct <= 20 THEN 35
            WHEN f.precipitation_mm <= 0.2
              AND f.precipitation_probability_pct <= 35 THEN 28
            WHEN f.precipitation_mm <= 0.5
              AND f.precipitation_probability_pct <= 50 THEN 18
            WHEN f.precipitation_mm <= 1.0
              AND f.precipitation_probability_pct <= 70 THEN 8
            ELSE 0
        END AS precipitation_score,
        CASE
            WHEN f.wind_speed_ms IS NULL THEN 0
            WHEN f.wind_speed_ms <= 4 THEN 25
            WHEN f.wind_speed_ms <= 6 THEN 18
            WHEN f.wind_speed_ms <= 8 THEN 10
            WHEN f.wind_speed_ms <= 10 THEN 4
            ELSE 0
        END AS wind_score,
        CASE
            WHEN f.is_day = 1 THEN 10
            ELSE 0
        END AS daylight_score
    FROM mart.fact_weather_forecast AS f
    INNER JOIN mart.dim_location AS l
        ON f.location_id = l.location_id
),
combined AS (
    SELECT
        *,
        temperature_score + precipitation_score + wind_score + daylight_score AS combined_score
    FROM scored
)
SELECT
    run_id,
    location_id,
    location_name,
    forecast_time,
    forecast_date,
    forecast_hour,
    temperature_c,
    precipitation_mm,
    precipitation_probability_pct,
    wind_speed_ms,
    is_day,
    temperature_score,
    precipitation_score,
    wind_score,
    daylight_score,
    combined_score,
    CASE
        WHEN combined_score >= 80 THEN 'Väga sobiv'
        WHEN combined_score >= 60 THEN 'Sobiv'
        WHEN combined_score >= 40 THEN 'Piiripealne'
        ELSE 'Ebasoodne'
    END AS suitability_label,
    CASE
        WHEN is_day <> 1 THEN 'Pime aeg'
        WHEN precipitation_score <= 8 THEN 'Sademete risk'
        WHEN wind_score <= 10 THEN 'Tuuline'
        WHEN temperature_score <= 12 THEN 'Temperatuur ei ole mugav'
        WHEN combined_score >= 80 THEN 'Kuiv, valge ja rahulik'
        ELSE 'Tingimused on osaliselt sobivad'
    END AS main_reason
FROM combined;

INSERT INTO mart.outdoor_activity_windows (
    run_id,
    location_id,
    location_name,
    window_start,
    window_end,
    duration_hours,
    avg_temperature_c,
    total_precipitation_mm,
    max_precipitation_probability_pct,
    max_wind_speed_ms,
    daylight_hours,
    avg_combined_score,
    min_combined_score,
    recommendation_label,
    main_reason
)
WITH windows AS (
    SELECT
        h1.run_id,
        h1.location_id,
        h1.location_name,
        h1.forecast_time AS window_start,
        h1.forecast_time + INTERVAL '3 hours' AS window_end,
        COUNT(h2.forecast_time)::integer AS duration_hours,
        ROUND(AVG(h2.temperature_c), 2) AS avg_temperature_c,
        ROUND(SUM(COALESCE(h2.precipitation_mm, 0)), 2) AS total_precipitation_mm,
        MAX(h2.precipitation_probability_pct)::integer AS max_precipitation_probability_pct,
        MAX(h2.wind_speed_ms) AS max_wind_speed_ms,
        SUM(CASE WHEN h2.is_day = 1 THEN 1 ELSE 0 END)::integer AS daylight_hours,
        ROUND(AVG(h2.combined_score), 1) AS avg_combined_score,
        MIN(h2.combined_score)::integer AS min_combined_score
    FROM mart.hourly_weather_score AS h1
    INNER JOIN mart.hourly_weather_score AS h2
        ON h1.run_id = h2.run_id
       AND h1.location_id = h2.location_id
       AND h2.forecast_time >= h1.forecast_time
       AND h2.forecast_time < h1.forecast_time + INTERVAL '3 hours'
    GROUP BY
        h1.run_id,
        h1.location_id,
        h1.location_name,
        h1.forecast_time
    HAVING COUNT(h2.forecast_time) = 3
)
SELECT
    run_id,
    location_id,
    location_name,
    window_start,
    window_end,
    duration_hours,
    avg_temperature_c,
    total_precipitation_mm,
    max_precipitation_probability_pct,
    max_wind_speed_ms,
    daylight_hours,
    avg_combined_score,
    min_combined_score,
    CASE
        WHEN avg_combined_score >= 80
          AND min_combined_score >= 60
          AND daylight_hours = 3 THEN 'Väga sobiv'
        WHEN avg_combined_score >= 65
          AND min_combined_score >= 45
          AND daylight_hours >= 2 THEN 'Sobiv'
        WHEN avg_combined_score >= 45 THEN 'Piiripealne'
        ELSE 'Ebasoodne'
    END AS recommendation_label,
    CASE
        WHEN daylight_hours < 3 THEN 'Osa aknast on pime'
        WHEN total_precipitation_mm > 0.5
          OR max_precipitation_probability_pct > 50 THEN 'Sademete risk'
        WHEN max_wind_speed_ms > 8 THEN 'Liiga tuuline'
        WHEN avg_temperature_c < 8
          OR avg_temperature_c > 30 THEN 'Temperatuur ei ole mugav'
        WHEN avg_combined_score >= 80 THEN 'Hea aken: kuiv, valge ja rahulik'
        ELSE 'Sobib ettevaatusega'
    END AS main_reason
FROM windows;

INSERT INTO mart.daily_weather_summary (
    run_id,
    location_id,
    location_name,
    forecast_date,
    forecast_hours,
    avg_temp_c,
    max_temp_c,
    total_precipitation_mm,
    max_wind_speed_ms,
    hours_with_precipitation,
    weather_risk_level
)
SELECT
    f.run_id,
    f.location_id,
    l.location_name,
    f.forecast_date,
    COUNT(*)::integer AS forecast_hours,
    ROUND(AVG(f.temperature_c), 2) AS avg_temp_c,
    MAX(f.temperature_c) AS max_temp_c,
    ROUND(SUM(COALESCE(f.precipitation_mm, 0)), 2) AS total_precipitation_mm,
    MAX(f.wind_speed_ms) AS max_wind_speed_ms,
    SUM(CASE WHEN COALESCE(f.precipitation_mm, 0) > 0 THEN 1 ELSE 0 END)::integer AS hours_with_precipitation,
    CASE
        WHEN SUM(COALESCE(f.precipitation_mm, 0)) >= 10
          OR MAX(COALESCE(f.wind_speed_ms, 0)) >= 14
            THEN 'Kõrgem tähelepanu'
        WHEN SUM(COALESCE(f.precipitation_mm, 0)) >= 2
          OR MAX(COALESCE(f.wind_speed_ms, 0)) >= 8
            THEN 'Mõõdukas tähelepanu'
        ELSE 'Tavaline'
    END AS weather_risk_level
FROM mart.fact_weather_forecast AS f
INNER JOIN mart.dim_location AS l
    ON f.location_id = l.location_id
GROUP BY
    f.run_id,
    f.location_id,
    l.location_name,
    f.forecast_date;

CREATE OR REPLACE VIEW mart.latest_pipeline_run AS
SELECT
    run_id,
    fetched_at,
    source_name,
    forecast_days,
    status,
    message
FROM staging.pipeline_runs
WHERE status = 'success'
ORDER BY fetched_at DESC
LIMIT 1;

CREATE OR REPLACE VIEW mart.latest_weather_forecast AS
SELECT f.*
FROM mart.fact_weather_forecast AS f
INNER JOIN mart.latest_pipeline_run AS r
    ON f.run_id = r.run_id;

CREATE OR REPLACE VIEW mart.latest_daily_weather_summary AS
SELECT d.*
FROM mart.daily_weather_summary AS d
INNER JOIN mart.latest_pipeline_run AS r
    ON d.run_id = r.run_id;

CREATE OR REPLACE VIEW mart.latest_hourly_weather_score AS
SELECT h.*
FROM mart.hourly_weather_score AS h
INNER JOIN mart.latest_pipeline_run AS r
    ON h.run_id = r.run_id;

CREATE OR REPLACE VIEW mart.latest_outdoor_activity_windows AS
SELECT w.*
FROM mart.outdoor_activity_windows AS w
INNER JOIN mart.latest_pipeline_run AS r
    ON w.run_id = r.run_id;
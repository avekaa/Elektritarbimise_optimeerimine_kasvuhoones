CREATE SCHEMA IF NOT EXISTS mart;

CREATE TABLE IF NOT EXISTS mart.dim_location (
    location_id text PRIMARY KEY,
    location_name text NOT NULL,
    country text NOT NULL,
    county text NOT NULL,
    location_type text NOT NULL,
    latitude numeric(9, 4) NOT NULL,
    longitude numeric(9, 4) NOT NULL,
    display_order integer NOT NULL,
    is_active boolean NOT NULL DEFAULT true
);

ALTER TABLE mart.dim_location
    ADD COLUMN IF NOT EXISTS county text;

ALTER TABLE mart.dim_location
    ADD COLUMN IF NOT EXISTS location_type text;

ALTER TABLE mart.dim_location
    ADD COLUMN IF NOT EXISTS display_order integer;

ALTER TABLE mart.dim_location
    ADD COLUMN IF NOT EXISTS is_active boolean;

DROP TABLE IF EXISTS tmp_seed_location;

CREATE TEMP TABLE tmp_seed_location (
    location_id text PRIMARY KEY,
    location_name text NOT NULL,
    country text NOT NULL,
    county text NOT NULL,
    location_type text NOT NULL,
    latitude numeric(9, 4) NOT NULL,
    longitude numeric(9, 4) NOT NULL,
    display_order integer NOT NULL,
    is_active boolean NOT NULL
) ON COMMIT DROP;

INSERT INTO tmp_seed_location (
    location_id,
    location_name,
    country,
    county,
    location_type,
    latitude,
    longitude,
    display_order,
    is_active
)
VALUES
    ('tallinn', 'Tallinn', 'Eesti', 'Harju maakond', 'asula', 59.4370, 24.7536, 10, true),
    ('tartu', 'Tartu', 'Eesti', 'Tartu maakond', 'asula', 58.3776, 26.7290, 20, true),
    ('parnu', 'Pärnu', 'Eesti', 'Pärnu maakond', 'asula', 58.3859, 24.4971, 30, true),
    ('narva', 'Narva', 'Eesti', 'Ida-Viru maakond', 'asula', 59.3797, 28.1791, 40, true),
    ('rakvere', 'Rakvere', 'Eesti', 'Lääne-Viru maakond', 'asula', 59.3464, 26.3558, 50, true),
    ('otepaa', 'Otepää', 'Eesti', 'Valga maakond', 'asula', 58.0583, 26.4967, 60, true),
    ('kohtla-jarve', 'Kohtla-Järve', 'Eesti', 'Ida-Viru maakond', 'asula', 59.3986, 27.2731, 70, true),
    ('viljandi', 'Viljandi', 'Eesti', 'Viljandi maakond', 'asula', 58.3639, 25.5900, 80, true),
    ('voru', 'Võru', 'Eesti', 'Võru maakond', 'asula', 57.8428, 27.0194, 90, true),
    ('kuressaare', 'Kuressaare', 'Eesti', 'Saare maakond', 'asula', 58.2520, 22.4869, 100, true),
    ('haapsalu', 'Haapsalu', 'Eesti', 'Lääne maakond', 'asula', 58.9431, 23.5414, 110, true),
    ('valga', 'Valga', 'Eesti', 'Valga maakond', 'asula', 57.7778, 26.0473, 120, true),
    ('paide', 'Paide', 'Eesti', 'Järva maakond', 'asula', 58.8856, 25.5572, 130, true),
    ('johvi', 'Jõhvi', 'Eesti', 'Ida-Viru maakond', 'asula', 59.3592, 27.4211, 140, true);

INSERT INTO mart.dim_location (
    location_id,
    location_name,
    country,
    county,
    location_type,
    latitude,
    longitude,
    display_order,
    is_active
)
SELECT
    location_id,
    location_name,
    country,
    county,
    location_type,
    latitude,
    longitude,
    display_order,
    is_active
FROM tmp_seed_location
ON CONFLICT (location_id) DO UPDATE SET
    location_name = EXCLUDED.location_name,
    country = EXCLUDED.country,
    county = EXCLUDED.county,
    location_type = EXCLUDED.location_type,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    display_order = EXCLUDED.display_order,
    is_active = EXCLUDED.is_active;

UPDATE mart.dim_location AS location
SET is_active = false
WHERE NOT EXISTS (
    SELECT 1
    FROM tmp_seed_location AS seed
    WHERE seed.location_id = location.location_id
);

UPDATE mart.dim_location
SET
    country = COALESCE(NULLIF(country, ''), 'Eesti'),
    county = COALESCE(NULLIF(county, ''), 'Täpsustamata'),
    location_type = COALESCE(NULLIF(location_type, ''), 'asula'),
    display_order = COALESCE(display_order, 999),
    is_active = COALESCE(is_active, false);

ALTER TABLE mart.dim_location
    ALTER COLUMN county SET NOT NULL,
    ALTER COLUMN location_type SET NOT NULL,
    ALTER COLUMN display_order SET NOT NULL,
    ALTER COLUMN is_active SET NOT NULL;
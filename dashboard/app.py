from __future__ import annotations

import os

import altair as alt
import pandas as pd
import psycopg2
import streamlit as st

try:
    from streamlit_autorefresh import st_autorefresh
except ImportError:
    st_autorefresh = None


st.set_page_config(
    page_title="Ilmaandmete näidikulaud",
    page_icon=None,
    layout="wide",
)

LABEL_DOMAIN = ["Väga sobiv", "Sobiv", "Piiripealne", "Ebasoodne"]
LABEL_COLORS = ["#2f9e44", "#f2c94c", "#f2994a", "#d64545"]
WEEKDAY_LABELS = ["E", "T", "K", "N", "R", "L", "P"]
DEFAULT_LOCATION_NAMES = ["Tallinn", "Tartu", "Pärnu", "Narva", "Rakvere", "Otepää"]


def get_int_env(name: str, default: int) -> int:
    try:
        return int(os.environ.get(name, str(default)))
    except ValueError:
        return default


auto_refresh_seconds = get_int_env("DASHBOARD_AUTOREFRESH_SECONDS", 15)
if auto_refresh_seconds > 0 and st_autorefresh is not None:
    st_autorefresh(
        interval=auto_refresh_seconds * 1000,
        key="dashboard_autorefresh",
    )
elif auto_refresh_seconds > 0:
    st.sidebar.info("Automaatvärskendus aktiveerub pärast dashboardi konteineri rebuild'i.")

if st.sidebar.button("Värskenda vaade"):
    st.rerun()


def get_connection():
    return psycopg2.connect(
        host=os.environ.get("DB_HOST", "db"),
        port=os.environ.get("DB_PORT", "5432"),
        user=os.environ.get("DB_USER", "praktikum"),
        password=os.environ.get("DB_PASSWORD", "praktikum"),
        dbname=os.environ.get("DB_NAME", "praktikum"),
    )


def load_dataframe(query: str) -> pd.DataFrame:
    with get_connection() as conn:
        return pd.read_sql_query(query, conn)


def prepare_time_columns(df: pd.DataFrame, column: str) -> pd.DataFrame:
    result = df.copy()
    result[column] = pd.to_datetime(result[column])
    return result


def coerce_numeric_columns(df: pd.DataFrame, columns: list[str]) -> pd.DataFrame:
    result = df.copy()
    for column in columns:
        result[column] = pd.to_numeric(result[column], errors="coerce")
    return result


def suitability_color() -> alt.Color:
    return alt.Color(
        "suitability_label:N",
        title="Sobivus",
        scale=alt.Scale(domain=LABEL_DOMAIN, range=LABEL_COLORS),
        legend=alt.Legend(orient="bottom"),
    )


def format_date_label(value: pd.Timestamp) -> str:
    return f"{WEEKDAY_LABELS[value.weekday()]} {value:%d.%m}"


def make_background(df: pd.DataFrame) -> alt.Chart:
    return (
        alt.Chart(df)
        .mark_rect(opacity=0.18)
        .encode(
            x=alt.X("forecast_time:T", title=None),
            x2="forecast_end:T",
            color=suitability_color(),
            tooltip=[
                alt.Tooltip("forecast_time:T", title="Aeg"),
                alt.Tooltip("combined_score:Q", title="Skoor"),
                alt.Tooltip("suitability_label:N", title="Sobivus"),
                alt.Tooltip("main_reason:N", title="Põhjus"),
            ],
        )
    )


def make_metric_chart(
    df: pd.DataFrame,
    *,
    y_field: str,
    y_title: str,
    line_color: str,
    height: int,
    mark: str = "line",
) -> alt.Chart:
    background = make_background(df)

    base = alt.Chart(df).encode(
        x=alt.X("forecast_time:T", title=None),
        y=alt.Y(f"{y_field}:Q", title=y_title),
        tooltip=[
            alt.Tooltip("forecast_time:T", title="Aeg"),
            alt.Tooltip("temperature_c:Q", title="Temp °C", format=".1f"),
            alt.Tooltip("wind_speed_ms:Q", title="Tuul m/s", format=".1f"),
            alt.Tooltip("precipitation_probability_pct:Q", title="Sademete tõenäosus %"),
            alt.Tooltip("precipitation_mm:Q", title="Sademed mm", format=".1f"),
            alt.Tooltip("combined_score:Q", title="Skoor"),
            alt.Tooltip("main_reason:N", title="Põhjus"),
        ],
    )

    if mark == "bar":
        foreground = base.mark_bar(color=line_color, opacity=0.75)
    else:
        foreground = base.mark_line(color=line_color, strokeWidth=2)

    return (background + foreground).properties(height=height)


def make_timeline(df: pd.DataFrame) -> alt.VConcatChart:
    score_strip = (
        alt.Chart(df)
        .mark_rect()
        .encode(
            x=alt.X("forecast_time:T", title=None),
            x2="forecast_end:T",
            y=alt.value(0),
            y2=alt.value(22),
            color=suitability_color(),
            tooltip=[
                alt.Tooltip("forecast_time:T", title="Aeg"),
                alt.Tooltip("combined_score:Q", title="Skoor"),
                alt.Tooltip("suitability_label:N", title="Sobivus"),
                alt.Tooltip("main_reason:N", title="Põhjus"),
            ],
        )
        .properties(height=28)
    )

    temperature = make_metric_chart(
        df,
        y_field="temperature_c",
        y_title="Temperatuur °C",
        line_color="#1f77b4",
        height=135,
    )
    wind = make_metric_chart(
        df,
        y_field="wind_speed_ms",
        y_title="Tuul m/s",
        line_color="#6f42c1",
        height=120,
    )
    precipitation = make_metric_chart(
        df,
        y_field="precipitation_probability_pct",
        y_title="Sademete tõenäosus %",
        line_color="#2f80ed",
        height=120,
        mark="bar",
    )

    return alt.vconcat(score_strip, temperature, wind, precipitation).resolve_scale(x="shared")


st.title("Eesti asulate ilmaotsuse näidik")

hourly = load_dataframe(
    """
    SELECT
        h.location_id,
        h.location_name,
        l.county,
        l.display_order,
        h.forecast_time,
        h.forecast_time + INTERVAL '1 hour' AS forecast_end,
        h.forecast_date,
        h.forecast_hour,
        h.temperature_c,
        h.precipitation_mm,
        h.precipitation_probability_pct,
        h.wind_speed_ms,
        h.is_day,
        h.temperature_score,
        h.precipitation_score,
        h.wind_score,
        h.daylight_score,
        h.combined_score,
        h.suitability_label,
        h.main_reason
    FROM mart.latest_hourly_weather_score AS h
    INNER JOIN mart.dim_location AS l
        ON h.location_id = l.location_id
    ORDER BY l.display_order, h.forecast_time
    """
)

windows = load_dataframe(
    """
    SELECT
        w.location_id,
        w.location_name,
        l.county,
        l.display_order,
        w.window_start,
        w.window_end,
        w.duration_hours,
        w.avg_temperature_c,
        w.total_precipitation_mm,
        w.max_precipitation_probability_pct,
        w.max_wind_speed_ms,
        w.daylight_hours,
        w.avg_combined_score,
        w.min_combined_score,
        w.recommendation_label,
        w.main_reason
    FROM mart.latest_outdoor_activity_windows AS w
    INNER JOIN mart.dim_location AS l
        ON w.location_id = l.location_id
    ORDER BY w.avg_combined_score DESC, w.window_start
    """
)

latest_run = load_dataframe(
    """
    SELECT
        run_id::text AS run_id,
        fetched_at,
        forecast_days,
        status,
        message
    FROM mart.latest_pipeline_run
    """
)

quality = load_dataframe(
    """
    SELECT
        test_name,
        status,
        failed_rows,
        message
    FROM quality.test_results
    ORDER BY test_name
    """
)

if hourly.empty or windows.empty:
    st.warning(
        "Andmeid ei ole veel laaditud. Oota scheduler'i esimest käivitust või käivita terminalis "
        "`docker compose exec pipeline python scripts/run_pipeline.py run-all`. Kui käivitasid töövoo just "
        "käsitsi, vajuta küljeribal `Värskenda vaade` või oota automaatvärskendust."
    )
    st.stop()

hourly = prepare_time_columns(hourly, "forecast_time")
hourly = prepare_time_columns(hourly, "forecast_end")
hourly = coerce_numeric_columns(
    hourly,
    [
        "temperature_c",
        "precipitation_mm",
        "precipitation_probability_pct",
        "wind_speed_ms",
        "temperature_score",
        "precipitation_score",
        "wind_score",
        "daylight_score",
        "combined_score",
        "display_order",
    ],
)
windows = prepare_time_columns(windows, "window_start")
windows = prepare_time_columns(windows, "window_end")
windows = coerce_numeric_columns(
    windows,
    [
        "duration_hours",
        "avg_temperature_c",
        "total_precipitation_mm",
        "max_precipitation_probability_pct",
        "max_wind_speed_ms",
        "daylight_hours",
        "avg_combined_score",
        "min_combined_score",
        "display_order",
    ],
)
hourly["forecast_date_label"] = hourly["forecast_time"].map(format_date_label)

locations = (
    hourly[["location_name", "display_order"]]
    .drop_duplicates()
    .sort_values(["display_order", "location_name"])["location_name"]
    .tolist()
)
default_locations = [name for name in DEFAULT_LOCATION_NAMES if name in locations]
if not default_locations:
    default_locations = locations[:6]
selected_locations = st.sidebar.multiselect(
    "Asukohad",
    options=locations,
    default=default_locations,
    key="selected_locations",
)
min_window_score = st.sidebar.slider(
    "Ajaakna minimaalne skoor",
    min_value=0,
    max_value=100,
    value=60,
    step=5,
    key="min_window_score",
)

if not selected_locations:
    st.info("Vali vähemalt üks asukoht.")
    st.stop()

if st.session_state.get("detail_location") not in selected_locations:
    st.session_state["detail_location"] = selected_locations[0]

detail_location = st.sidebar.selectbox(
    "Detailvaate asukoht",
    options=selected_locations,
    key="detail_location",
)

filtered_hourly = hourly[hourly["location_name"].isin(selected_locations)].copy()
selected_windows = windows[windows["location_name"].isin(selected_locations)].copy()
filtered_windows = windows[
    (windows["location_name"].isin(selected_locations))
    & (windows["avg_combined_score"] >= min_window_score)
].copy()

if latest_run.empty:
    st.info("Viimase laadimise infot ei leitud.")
else:
    run = latest_run.iloc[0]
    st.caption(f"Viimane laadimine: {run['fetched_at']} | {run['message']}")

if selected_windows.empty:
    st.info("Valitud asukohtade kohta ei ole ajaaknaid.")
    st.stop()

best_window = selected_windows.iloc[0]
very_good_count = int((selected_windows["recommendation_label"] == "Väga sobiv").sum())
good_count = int(selected_windows["recommendation_label"].isin(["Väga sobiv", "Sobiv"]).sum())

metric_1, metric_2, metric_3, metric_4 = st.columns(4)
metric_1.metric("Parim skoor", f"{best_window['avg_combined_score']:.1f}")
metric_2.metric("Väga sobivaid 3h aknaid", very_good_count)
metric_3.metric("Sobivaid 3h aknaid", good_count)
metric_4.metric("Parim asukoht", str(best_window["location_name"]))

st.subheader("Parimad ajaaknad")

window_table = filtered_windows.head(15).copy()
if window_table.empty:
    st.info("Valitud filtritega sobivaid ajaaknaid ei leitud.")
else:
    window_table["Aken"] = (
        window_table["window_start"].dt.strftime("%d.%m %H:%M")
        + " - "
        + window_table["window_end"].dt.strftime("%H:%M")
    )
    st.dataframe(
        window_table[
            [
                "location_name",
                "county",
                "Aken",
                "avg_combined_score",
                "recommendation_label",
                "avg_temperature_c",
                "total_precipitation_mm",
                "max_precipitation_probability_pct",
                "max_wind_speed_ms",
                "main_reason",
            ]
        ].rename(
            columns={
                "location_name": "Asukoht",
                "county": "Maakond",
                "avg_combined_score": "Skoor",
                "recommendation_label": "Soovitus",
                "avg_temperature_c": "Keskmine temp °C",
                "total_precipitation_mm": "Sademed mm",
                "max_precipitation_probability_pct": "Sademete tõenäosus %",
                "max_wind_speed_ms": "Suurim tuul m/s",
                "main_reason": "Põhjus",
            }
        ),
        use_container_width=True,
        hide_index=True,
    )

st.subheader("Sobivuse kalender")

for location_name in selected_locations:
    location_calendar = filtered_hourly[filtered_hourly["location_name"] == location_name].copy()
    if location_calendar.empty:
        continue

    day_count = location_calendar["forecast_date_label"].nunique()
    calendar = (
        alt.Chart(location_calendar)
        .mark_rect(stroke="white", strokeWidth=0.7)
        .encode(
            x=alt.X(
                "forecast_hour:O",
                title="Tund",
                axis=alt.Axis(labelAngle=0, values=[0, 3, 6, 9, 12, 15, 18, 21]),
            ),
            y=alt.Y(
                "forecast_date_label:N",
                title="Päev",
                sort=alt.SortField("forecast_time", order="ascending"),
            ),
            color=suitability_color(),
            tooltip=[
                alt.Tooltip("location_name:N", title="Asukoht"),
                alt.Tooltip("forecast_time:T", title="Aeg"),
                alt.Tooltip("combined_score:Q", title="Skoor"),
                alt.Tooltip("temperature_c:Q", title="Temp °C", format=".1f"),
                alt.Tooltip("wind_speed_ms:Q", title="Tuul m/s", format=".1f"),
                alt.Tooltip("precipitation_probability_pct:Q", title="Sademete tõenäosus %"),
                alt.Tooltip("main_reason:N", title="Põhjus"),
            ],
        )
        .properties(title=location_name, height=max(180, 32 * day_count))
    )
    st.altair_chart(calendar, use_container_width=True)

location_hourly = filtered_hourly[filtered_hourly["location_name"] == detail_location].copy()
if not location_hourly.empty:
    st.subheader(f"Ilmategurid: {detail_location}")
    st.altair_chart(make_timeline(location_hourly), use_container_width=True)

st.subheader("Andmekvaliteedi kontrollid")
st.dataframe(quality, use_container_width=True, hide_index=True)
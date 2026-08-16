-- ============================================================
-- Tari'ak Traffic Analysis — SQL Queries
-- Notebook: 01_sql_traffic_analysis.ipynb
--
-- Purpose:
-- Analyze cleaned Tari'ak traffic observations in SQLite. The
-- analysis moves from broad hourly patterns to repeated,
-- segment-relative slowdowns, a shortlist of candidate mobility
-- bottlenecks, and the SQL queries supporting segment feature
-- engineering for clustering.
--
-- Main tables:
-- 1. traffic_observations (raw observations at observation grain)
-- 2. daily_segment_hour (materialized summary at segment-date-hour grain)
-- ============================================================


-- ============================================================
-- Section 2: Verify the Processed Table
--
-- Goal:
-- Confirm that the SQLite import preserves the expected row count
-- and temporal coverage from the processed dataset.
-- ============================================================

SELECT
    COUNT(*) AS total_row_count,
    MIN(timestamp) AS min_timestamp,
    MAX(timestamp) AS max_timestamp
FROM traffic_observations;


-- ============================================================
-- Section 3: Hourly Velocity Patterns
--
-- Goal:
-- Describe recorded velocity by hour while retaining the number of
-- observations supporting each hourly average.
-- ============================================================

SELECT
    hour,
    COUNT(*) AS total_row_count,
    ROUND(AVG(velocity), 2) AS average_velocity
FROM traffic_observations
GROUP BY hour
ORDER BY hour ASC;


-- ============================================================
-- Section 4: Road-Segment Profiles
--
-- Goal:
-- Identify frequently observed OpenStreetMap road segments and
-- describe their observed velocity range.
-- ============================================================

SELECT
    osm_id,
    COUNT(*) AS total_row_count,
    ROUND(AVG(velocity), 2) AS average_velocity,
    ROUND(MIN(velocity), 2) AS minimum_velocity,
    ROUND(MAX(velocity), 2) AS maximum_velocity
FROM traffic_observations
GROUP BY osm_id
ORDER BY total_row_count DESC
LIMIT 20;


-- ============================================================
-- Section 5: Absolute Velocity Screening
--
-- Goal:
-- Screen well-observed segments with low average velocity. These are
-- not confirmed congestion hotspots because road type, capacity, and
-- speed-limit information are unavailable.
-- ============================================================

SELECT
    osm_id,
    COUNT(*) AS total_row_count,
    ROUND(AVG(velocity), 2) AS average_velocity,
    ROUND(MIN(velocity), 2) AS minimum_velocity,
    ROUND(MAX(velocity), 2) AS maximum_velocity
FROM traffic_observations
GROUP BY osm_id
HAVING COUNT(*) >= 5000
ORDER BY AVG(velocity) ASC
LIMIT 20;


-- ============================================================
-- Section 6: Relative Segment Slowdowns
--
-- Goal:
-- Compare each segment-hour velocity with the overall baseline for
-- that same segment. A negative difference means that the segment is
-- slower than its typical recorded level at that hour.
-- ============================================================

WITH segment_baseline AS (
    SELECT
        osm_id,
        AVG(velocity) AS baseline_velocity
    FROM traffic_observations
    GROUP BY osm_id
),
segment_hourly AS (
    SELECT
        osm_id,
        hour,
        COUNT(*) AS observation_count,
        AVG(velocity) AS hourly_velocity
    FROM traffic_observations
    GROUP BY osm_id, hour
    HAVING COUNT(*) >= 100
)
SELECT
    sh.osm_id,
    sh.hour,
    sh.observation_count,
    ROUND(sh.hourly_velocity, 2) AS hourly_velocity,
    ROUND(sb.baseline_velocity, 2) AS baseline_velocity,
    ROUND(sh.hourly_velocity - sb.baseline_velocity, 2)
        AS velocity_difference
FROM segment_hourly AS sh
JOIN segment_baseline AS sb
    ON sh.osm_id = sb.osm_id
ORDER BY sh.hourly_velocity - sb.baseline_velocity ASC
LIMIT 50;


-- ============================================================
-- Section 7: Recurring Daily Slowdowns
--
-- Goal:
-- Give each date equal weight by calculating daily segment-hour
-- averages before summarizing them. The variance is returned here;
-- the notebook converts it to a standard deviation in Pandas because
-- the local SQLite build does not provide SQRT().
-- ============================================================

WITH daily_segment_hour AS (
    SELECT
        osm_id,
        DATE(timestamp) AS observation_date,
        hour,
        COUNT(*) AS daily_observation_count,
        AVG(velocity) AS daily_average_velocity
    FROM traffic_observations
    GROUP BY osm_id, observation_date, hour
    HAVING COUNT(*) >= 5
),
segment_baseline AS (
    SELECT
        osm_id,
        AVG(velocity) AS baseline_velocity
    FROM traffic_observations
    GROUP BY osm_id
),
recurring_slowdowns AS (
    SELECT
        osm_id,
        hour,
        COUNT(*) AS observed_days,
        SUM(daily_observation_count) AS total_observations,
        AVG(daily_average_velocity) AS average_daily_velocity,
        MIN(daily_average_velocity) AS minimum_daily_velocity,
        MAX(daily_average_velocity) AS maximum_daily_velocity,
        AVG(daily_average_velocity * daily_average_velocity) -
            AVG(daily_average_velocity) * AVG(daily_average_velocity)
            AS daily_velocity_variance
    FROM daily_segment_hour
    GROUP BY osm_id, hour
    HAVING COUNT(*) >= 5
)
SELECT
    rs.osm_id,
    rs.hour,
    rs.observed_days,
    rs.total_observations,
    ROUND(rs.average_daily_velocity, 2) AS average_daily_velocity,
    ROUND(sb.baseline_velocity, 2) AS baseline_velocity,
    ROUND(rs.average_daily_velocity - sb.baseline_velocity, 2)
        AS velocity_difference,
    ROUND(MAX(rs.daily_velocity_variance, 0), 2)
        AS daily_velocity_variance,
    ROUND(rs.maximum_daily_velocity, 2) AS maximum_daily_velocity
FROM recurring_slowdowns AS rs
JOIN segment_baseline AS sb
    ON rs.osm_id = sb.osm_id
ORDER BY velocity_difference ASC
LIMIT 50;


-- ============================================================
-- Section 8: Materialize the Daily Summary
--
-- Goal:
-- Rebuild the reusable daily segment-hour table from the raw SQLite
-- observations. Dropping the table first ensures a clean rerun after
-- the source data changes.
-- ============================================================

DROP TABLE IF EXISTS daily_segment_hour;

CREATE TABLE daily_segment_hour AS
SELECT
    osm_id,
    DATE(timestamp) AS observation_date,
    hour,
    COUNT(*) AS daily_observation_count,
    AVG(velocity) AS daily_average_velocity
FROM traffic_observations
GROUP BY osm_id, observation_date, hour
HAVING COUNT(*) >= 5;

CREATE INDEX IF NOT EXISTS idx_daily_segment_hour
ON daily_segment_hour (osm_id, hour);

SELECT
    COUNT(*) AS summary_rows,
    COUNT(DISTINCT osm_id) AS segments,
    MIN(observation_date) AS first_date,
    MAX(observation_date) AS last_date
FROM daily_segment_hour;


-- ============================================================
-- Section 9: Weekday and Weekend Segment Patterns
--
-- Goal:
-- Match each segment-hour across weekdays and weekends. Both groups
-- require at least 10 observed dates before comparison.
-- ============================================================

WITH daily_by_type AS (
    SELECT
        osm_id,
        hour,
        CASE
            WHEN STRFTIME('%w', observation_date) IN ('0', '6')
                THEN 'weekend'
            ELSE 'weekday'
        END AS day_type,
        COUNT(*) AS observed_days,
        AVG(daily_average_velocity) AS average_daily_velocity
    FROM daily_segment_hour
    GROUP BY osm_id, hour, day_type
    HAVING COUNT(*) >= 10
),
matched_profiles AS (
    SELECT
        weekday.osm_id,
        weekday.hour,
        weekday.observed_days AS weekday_days,
        weekend.observed_days AS weekend_days,
        weekday.average_daily_velocity AS weekday_velocity,
        weekend.average_daily_velocity AS weekend_velocity
    FROM daily_by_type AS weekday
    JOIN daily_by_type AS weekend
        ON weekday.osm_id = weekend.osm_id
        AND weekday.hour = weekend.hour
    WHERE weekday.day_type = 'weekday'
        AND weekend.day_type = 'weekend'
)
SELECT
    osm_id,
    hour,
    weekday_days,
    weekend_days,
    ROUND(weekday_velocity, 2) AS weekday_velocity,
    ROUND(weekend_velocity, 2) AS weekend_velocity,
    ROUND(weekday_velocity - weekend_velocity, 2)
        AS weekday_minus_weekend
FROM matched_profiles
ORDER BY weekday_velocity - weekend_velocity ASC
LIMIT 30;


-- ============================================================
-- Section 10: Candidate Mobility-Bottleneck Ranking
--
-- Goal:
-- Create a shortlist from recurring relative slowdowns. Candidates
-- need at least 30 dates and 200 raw observations. The variance is
-- returned for the notebook to convert to a standard deviation.
-- ============================================================

WITH segment_baseline AS (
    SELECT
        osm_id,
        AVG(daily_average_velocity) AS baseline_velocity
    FROM daily_segment_hour
    GROUP BY osm_id
),
segment_hour_profile AS (
    SELECT
        osm_id,
        hour,
        COUNT(*) AS observed_days,
        SUM(daily_observation_count) AS total_observations,
        AVG(daily_average_velocity) AS average_daily_velocity,
        AVG(daily_average_velocity * daily_average_velocity) -
            AVG(daily_average_velocity) * AVG(daily_average_velocity)
            AS daily_velocity_variance
    FROM daily_segment_hour
    GROUP BY osm_id, hour
    HAVING COUNT(*) >= 30
        AND SUM(daily_observation_count) >= 200
)
SELECT
    shp.osm_id,
    shp.hour,
    shp.observed_days,
    shp.total_observations,
    ROUND(shp.average_daily_velocity, 2) AS average_daily_velocity,
    ROUND(sb.baseline_velocity, 2) AS baseline_velocity,
    ROUND(sb.baseline_velocity - shp.average_daily_velocity, 2)
        AS velocity_drop,
    ROUND(
        100.0 * (sb.baseline_velocity - shp.average_daily_velocity)
        / sb.baseline_velocity,
        2
    ) AS slowdown_percentage,
    ROUND(MAX(shp.daily_velocity_variance, 0), 2)
        AS daily_velocity_variance
FROM segment_hour_profile AS shp
JOIN segment_baseline AS sb
    ON shp.osm_id = sb.osm_id
WHERE shp.average_daily_velocity < sb.baseline_velocity
    AND sb.baseline_velocity > 0
ORDER BY slowdown_percentage DESC, observed_days DESC
LIMIT 30;


-- ============================================================
-- Section 11: Segment Features for Clustering
--
-- Note:
-- The full segment_features build in Notebook 01 combines the SQL
-- queries below with Pandas processing (calculating per-segment
-- median velocity and standard deviation, merging feature sets,
-- calculating relative slowdown differences, and filtering to
-- segments with >= 100 observations and >= 10 active days).
-- ============================================================

-- ------------------------------------------------------------
-- 11.1 Observation Coverage and Threshold Selection
--
-- Goal:
-- Extract per-segment observation count and distinct active days
-- to analyze distribution shape and determine qualification cutoffs.
-- ------------------------------------------------------------

SELECT
    osm_id,
    COUNT(*) AS observation_count,
    COUNT(DISTINCT DATE(timestamp)) AS active_days
FROM traffic_observations
GROUP BY osm_id;


-- ------------------------------------------------------------
-- 11.2 Moving Velocity Observations (Excluding Near-Zero < 0.1 m/s)
--
-- Goal:
-- Extract non-stationary velocity observations per segment. The
-- notebook computes median_velocity and velocity_std from these
-- rows in Pandas.
-- ------------------------------------------------------------

SELECT osm_id, velocity
FROM traffic_observations
WHERE velocity >= 0.1;


-- ------------------------------------------------------------
-- 11.3 Segment Counts, Active Days, and Zero-Velocity Diagnostic
--
-- Goal:
-- Compute total observations, distinct active dates, and near-zero
-- velocity count (< 0.1 m/s) for each segment.
-- ------------------------------------------------------------

SELECT
    osm_id,
    COUNT(*) AS observation_count,
    COUNT(DISTINCT DATE(timestamp)) AS active_days,
    SUM(CASE WHEN velocity < 0.1 THEN 1 ELSE 0 END) AS zero_velocity_observation_count
FROM traffic_observations
GROUP BY osm_id;


-- ------------------------------------------------------------
-- 11.4 AM Peak Velocity (Hours 7–9)
--
-- Goal:
-- Calculate mean daily average velocity during morning peak hours
-- from the materialized daily_segment_hour table.
-- ------------------------------------------------------------

SELECT
    osm_id,
    AVG(daily_average_velocity) AS am_velocity
FROM daily_segment_hour
WHERE hour IN (7, 8, 9)
GROUP BY osm_id;


-- ------------------------------------------------------------
-- 11.5 PM Peak Velocity (Hours 17–19)
--
-- Goal:
-- Calculate mean daily average velocity during evening peak hours
-- from the materialized daily_segment_hour table.
-- ------------------------------------------------------------

SELECT
    osm_id,
    AVG(daily_average_velocity) AS pm_velocity
FROM daily_segment_hour
WHERE hour IN (17, 18, 19)
GROUP BY osm_id;


-- ------------------------------------------------------------
-- 11.6 Non-AM Baseline Velocity (Hours NOT IN 7–9)
--
-- Goal:
-- Calculate non-morning baseline velocity to prevent circular
-- dilution when evaluating morning peak slowdowns.
-- ------------------------------------------------------------

SELECT
    osm_id,
    AVG(daily_average_velocity) AS non_am_baseline_velocity
FROM daily_segment_hour
WHERE hour NOT IN (7, 8, 9)
GROUP BY osm_id;


-- ------------------------------------------------------------
-- 11.7 Non-PM Baseline Velocity (Hours NOT IN 17–19)
--
-- Goal:
-- Calculate non-evening baseline velocity to prevent circular
-- dilution when evaluating evening peak slowdowns.
-- ------------------------------------------------------------

SELECT
    osm_id,
    AVG(daily_average_velocity) AS non_pm_baseline_velocity
FROM daily_segment_hour
WHERE hour NOT IN (17, 18, 19)
GROUP BY osm_id;


-- ------------------------------------------------------------
-- 11.8 AM Slowdown Frequency Against Non-AM Baseline
--
-- Goal:
-- Measure the fraction of AM segment-hours that fall below the
-- segment's own non-AM baseline velocity.
-- ------------------------------------------------------------

SELECT
    dsh.osm_id,
    AVG(CASE WHEN dsh.daily_average_velocity < sb.non_am_baseline_velocity THEN 1.0 ELSE 0.0 END)
        AS am_slowdown_frequency
FROM daily_segment_hour dsh
JOIN (
    SELECT osm_id, AVG(daily_average_velocity) AS non_am_baseline_velocity
    FROM daily_segment_hour
    WHERE hour NOT IN (7, 8, 9)
    GROUP BY osm_id
) sb ON dsh.osm_id = sb.osm_id
WHERE dsh.hour IN (7, 8, 9)
GROUP BY dsh.osm_id;


-- ------------------------------------------------------------
-- 11.9 PM Slowdown Frequency Against Non-PM Baseline
--
-- Goal:
-- Measure the fraction of PM segment-hours that fall below the
-- segment's own non-PM baseline velocity.
-- ------------------------------------------------------------

SELECT
    dsh.osm_id,
    AVG(CASE WHEN dsh.daily_average_velocity < sb.non_pm_baseline_velocity THEN 1.0 ELSE 0.0 END)
        AS pm_slowdown_frequency
FROM daily_segment_hour dsh
JOIN (
    SELECT osm_id, AVG(daily_average_velocity) AS non_pm_baseline_velocity
    FROM daily_segment_hour
    WHERE hour NOT IN (17, 18, 19)
    GROUP BY osm_id
) sb ON dsh.osm_id = sb.osm_id
WHERE dsh.hour IN (17, 18, 19)
GROUP BY dsh.osm_id;

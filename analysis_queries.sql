-- ============================================================
--  Nitaqat Workforce Compliance Analysis
--  Database: nitaqat_workforce.db  (SQLite)
--  Period:   January – December 2023
--  Scope:    18 companies, Eastern Province, Saudi Arabia
-- ============================================================
--
--  Nitaqat is Saudi Arabia's Saudization quota system managed
--  by the Ministry of Human Resources and Social Development.
--  Companies are classified into bands (Platinum, High Green,
--  Green, Yellow, Red) based on what percentage of their
--  workforce is Saudi national. Thresholds vary by economic
--  sector and establishment size.
--
--  This script runs analytical queries in five progressive
--  sections:
--
--   1. Basic workforce counts
--   2. Saudization rates and band classification
--   3. Compliance gap analysis
--   4. Sector-level aggregations
--   5. Trend analysis (month-over-month, 2023)
--
-- ============================================================


-- ============================================================
-- SECTION 1 — BASIC WORKFORCE COUNTS
-- ============================================================

-- 1a. Current headcount snapshot (December 2023)
--     Shows total vs Saudi vs expat staff per company
SELECT
    c.company_name,
    c.city,
    s.sector_name,
    ms.total_headcount,
    ms.saudi_headcount,
    (ms.total_headcount - ms.saudi_headcount)  AS expat_headcount,
    ROUND(ms.saudi_pct * 100, 1)               AS saudi_pct
FROM monthly_snapshots ms
JOIN companies c USING (company_id)
JOIN sectors   s USING (sector_id)
WHERE ms.snapshot_month = '2023-12-01'
ORDER BY ms.total_headcount DESC;


-- 1b. Total workforce by city (December 2023)
SELECT
    c.city,
    COUNT(DISTINCT c.company_id)               AS num_companies,
    SUM(ms.total_headcount)                    AS total_workers,
    SUM(ms.saudi_headcount)                    AS saudi_workers,
    ROUND(
        100.0 * SUM(ms.saudi_headcount) / SUM(ms.total_headcount),
        1
    )                                          AS overall_saudi_pct
FROM monthly_snapshots ms
JOIN companies c USING (company_id)
WHERE ms.snapshot_month = '2023-12-01'
GROUP BY c.city
ORDER BY total_workers DESC;


-- 1c. Smallest and largest employers in the dataset
SELECT
    c.company_name,
    c.size_cat,
    s.sector_name,
    ms.total_headcount
FROM monthly_snapshots ms
JOIN companies c USING (company_id)
JOIN sectors   s USING (sector_id)
WHERE ms.snapshot_month = '2023-12-01'
ORDER BY ms.total_headcount DESC
LIMIT 5;


-- ============================================================
-- SECTION 2 — SAUDIZATION RATES AND BAND CLASSIFICATION
-- ============================================================

-- 2a. Current Nitaqat band for every company (December 2023)
SELECT
    c.company_name,
    c.city,
    s.sector_name,
    ROUND(ms.saudi_pct * 100, 1)  AS saudi_pct,
    ms.nitaqat_band
FROM monthly_snapshots ms
JOIN companies c USING (company_id)
JOIN sectors   s USING (sector_id)
WHERE ms.snapshot_month = '2023-12-01'
ORDER BY
    CASE ms.nitaqat_band
        WHEN 'Platinum'   THEN 1
        WHEN 'High Green' THEN 2
        WHEN 'Green'      THEN 3
        WHEN 'Yellow'     THEN 4
        WHEN 'Red'        THEN 5
    END;


-- 2b. Band distribution across all companies (December 2023)
SELECT
    nitaqat_band,
    COUNT(*)                                   AS num_companies,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM monthly_snapshots
WHERE snapshot_month = '2023-12-01'
GROUP BY nitaqat_band
ORDER BY
    CASE nitaqat_band
        WHEN 'Platinum'   THEN 1
        WHEN 'High Green' THEN 2
        WHEN 'Green'      THEN 3
        WHEN 'Yellow'     THEN 4
        WHEN 'Red'        THEN 5
    END;


-- 2c. Average Saudization rate per sector (December 2023)
--     Useful for benchmarking a company against its sector peers
SELECT
    s.sector_name,
    COUNT(DISTINCT c.company_id)               AS num_companies,
    ROUND(AVG(ms.saudi_pct) * 100, 1)          AS avg_saudi_pct,
    ROUND(MIN(ms.saudi_pct) * 100, 1)          AS min_saudi_pct,
    ROUND(MAX(ms.saudi_pct) * 100, 1)          AS max_saudi_pct
FROM monthly_snapshots ms
JOIN companies c USING (company_id)
JOIN sectors   s USING (sector_id)
WHERE ms.snapshot_month = '2023-12-01'
GROUP BY s.sector_name
ORDER BY avg_saudi_pct DESC;


-- ============================================================
-- SECTION 3 — COMPLIANCE GAP ANALYSIS
-- ============================================================

-- 3a. Saudi hires needed to reach Green band (December 2023)
--     For companies in Yellow or Red, how many Saudi hires
--     would push them into Green?
SELECT
    c.company_name,
    c.city,
    s.sector_name,
    ms.total_headcount,
    ms.saudi_headcount,
    ROUND(ms.saudi_pct * 100, 1)               AS current_saudi_pct,
    ROUND(s.green_threshold * 100, 1)          AS green_threshold_pct,
    ms.nitaqat_band,
    -- Minimum Saudi headcount required for Green
    CEIL(ms.total_headcount * s.green_threshold) AS saudi_needed_for_green,
    -- Gap: how many additional Saudi hires required
    MAX(0,
        CEIL(ms.total_headcount * s.green_threshold) - ms.saudi_headcount
    )                                          AS hire_gap
FROM monthly_snapshots ms
JOIN companies c USING (company_id)
JOIN sectors   s USING (sector_id)
WHERE ms.snapshot_month = '2023-12-01'
  AND ms.nitaqat_band IN ('Yellow', 'Red')
ORDER BY hire_gap DESC;


-- 3b. Companies at risk of band downgrade
--     Identify companies whose Saudi % dropped month-over-month
--     and are within 2 percentage points of the next lower threshold
WITH dec_data AS (
    SELECT
        ms.company_id,
        ms.saudi_pct                           AS dec_pct,
        ms.nitaqat_band                        AS dec_band,
        s.green_threshold,
        s.yellow_threshold
    FROM monthly_snapshots ms
    JOIN companies c USING (company_id)
    JOIN sectors   s USING (sector_id)
    WHERE ms.snapshot_month = '2023-12-01'
),
nov_data AS (
    SELECT company_id, saudi_pct AS nov_pct
    FROM   monthly_snapshots
    WHERE  snapshot_month = '2023-11-01'
)
SELECT
    c.company_name,
    c.city,
    ROUND(n.nov_pct * 100, 1)                  AS nov_saudi_pct,
    ROUND(d.dec_pct * 100, 1)                  AS dec_saudi_pct,
    ROUND((d.dec_pct - n.nov_pct) * 100, 2)   AS mom_change_pp,
    d.dec_band,
    CASE
        WHEN d.dec_band = 'Green'  AND d.dec_pct - d.yellow_threshold < 0.02 THEN 'At risk: near Yellow'
        WHEN d.dec_band = 'Yellow' AND d.dec_pct - d.yellow_threshold < 0.01 THEN 'At risk: near Red'
        ELSE 'Stable'
    END                                        AS risk_flag
FROM dec_data d
JOIN nov_data  n USING (company_id)
JOIN companies c USING (company_id)
WHERE d.dec_pct < n.nov_pct          -- Saudi % fell month-over-month
ORDER BY mom_change_pp ASC;


-- 3c. Compliance summary: how many companies are compliant
--     (Green and above) vs non-compliant (Yellow/Red)?
SELECT
    CASE
        WHEN nitaqat_band IN ('Platinum', 'High Green', 'Green') THEN 'Compliant'
        ELSE 'Non-Compliant'
    END                          AS compliance_status,
    COUNT(*)                     AS num_companies,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM monthly_snapshots WHERE snapshot_month = '2023-12-01'), 1) AS pct
FROM monthly_snapshots
WHERE snapshot_month = '2023-12-01'
GROUP BY compliance_status;


-- ============================================================
-- SECTION 4 — SECTOR-LEVEL AGGREGATIONS
-- ============================================================

-- 4a. Total Saudi vs expat workforce by sector (December 2023)
SELECT
    s.sector_name,
    SUM(ms.total_headcount)                    AS total_workers,
    SUM(ms.saudi_headcount)                    AS saudi_workers,
    SUM(ms.total_headcount - ms.saudi_headcount) AS expat_workers,
    ROUND(
        100.0 * SUM(ms.saudi_headcount) / SUM(ms.total_headcount),
        1
    )                                          AS sector_saudi_pct
FROM monthly_snapshots ms
JOIN companies c USING (company_id)
JOIN sectors   s USING (sector_id)
WHERE ms.snapshot_month = '2023-12-01'
GROUP BY s.sector_name
ORDER BY sector_saudi_pct DESC;


-- 4b. Non-compliant companies per sector (any month in 2023)
--     Shows which sectors had the most Yellow/Red appearances
SELECT
    s.sector_name,
    COUNT(*)                                   AS non_compliant_appearances,
    COUNT(DISTINCT ms.company_id)              AS distinct_companies
FROM monthly_snapshots ms
JOIN companies c USING (company_id)
JOIN sectors   s USING (sector_id)
WHERE ms.nitaqat_band IN ('Yellow', 'Red')
GROUP BY s.sector_name
ORDER BY non_compliant_appearances DESC;


-- 4c. Sector compliance rate across all 12 months
--     What % of monthly records per sector were Green or above?
SELECT
    s.sector_name,
    COUNT(*)                                   AS total_observations,
    SUM(CASE WHEN ms.nitaqat_band IN ('Platinum','High Green','Green') THEN 1 ELSE 0 END)
                                               AS compliant_months,
    ROUND(
        100.0 * SUM(CASE WHEN ms.nitaqat_band IN ('Platinum','High Green','Green') THEN 1 ELSE 0 END)
        / COUNT(*),
        1
    )                                          AS compliance_rate_pct
FROM monthly_snapshots ms
JOIN companies c USING (company_id)
JOIN sectors   s USING (sector_id)
GROUP BY s.sector_name
ORDER BY compliance_rate_pct DESC;


-- ============================================================
-- SECTION 5 — TREND ANALYSIS (MONTH-OVER-MONTH, 2023)
-- ============================================================

-- 5a. Monthly Saudization rate for the full dataset
--     Shows the aggregate Saudi % across all 18 companies per month
SELECT
    snapshot_month,
    SUM(total_headcount)                       AS total_workers,
    SUM(saudi_headcount)                       AS saudi_workers,
    ROUND(
        100.0 * SUM(saudi_headcount) / SUM(total_headcount),
        2
    )                                          AS monthly_saudi_pct
FROM monthly_snapshots
GROUP BY snapshot_month
ORDER BY snapshot_month;


-- 5b. Month-over-month Saudization change per company
--     Uses LAG() to compare each month to the prior month
SELECT
    c.company_name,
    ms.snapshot_month,
    ROUND(ms.saudi_pct * 100, 1)               AS saudi_pct,
    ROUND(
        (ms.saudi_pct - LAG(ms.saudi_pct) OVER (
            PARTITION BY ms.company_id ORDER BY ms.snapshot_month
        )) * 100,
        2
    )                                          AS mom_change_pp,
    ms.nitaqat_band
FROM monthly_snapshots ms
JOIN companies c USING (company_id)
ORDER BY c.company_name, ms.snapshot_month;


-- 5c. Companies that improved their Nitaqat band over 2023
--     Compares January band to December band
WITH jan AS (
    SELECT company_id, nitaqat_band AS jan_band, saudi_pct AS jan_pct
    FROM   monthly_snapshots WHERE snapshot_month = '2023-01-01'
),
dec AS (
    SELECT company_id, nitaqat_band AS dec_band, saudi_pct AS dec_pct
    FROM   monthly_snapshots WHERE snapshot_month = '2023-12-01'
),
-- Band rank helper (inline CASE avoids SQLite VALUES-as-table limitation)
band_rank_jan AS (
    SELECT company_id,
        CASE jan_band
            WHEN 'Platinum'   THEN 1
            WHEN 'High Green' THEN 2
            WHEN 'Green'      THEN 3
            WHEN 'Yellow'     THEN 4
            WHEN 'Red'        THEN 5
        END AS rank_jan
    FROM jan
),
band_rank_dec AS (
    SELECT company_id,
        CASE dec_band
            WHEN 'Platinum'   THEN 1
            WHEN 'High Green' THEN 2
            WHEN 'Green'      THEN 3
            WHEN 'Yellow'     THEN 4
            WHEN 'Red'        THEN 5
        END AS rank_dec
    FROM dec
)
SELECT
    c.company_name,
    c.city,
    s.sector_name,
    j.jan_band,
    d.dec_band,
    ROUND(j.jan_pct * 100, 1)                  AS jan_saudi_pct,
    ROUND(d.dec_pct * 100, 1)                  AS dec_saudi_pct,
    CASE
        WHEN brj.rank_jan > brd.rank_dec THEN 'Improved'
        WHEN brj.rank_jan < brd.rank_dec THEN 'Declined'
        ELSE 'Unchanged'
    END                                        AS band_movement
FROM jan   j
JOIN dec          d   USING (company_id)
JOIN companies    c   USING (company_id)
JOIN sectors      s   USING (sector_id)
JOIN band_rank_jan brj USING (company_id)
JOIN band_rank_dec brd USING (company_id)
ORDER BY band_movement, c.company_name;


-- 5d. Best and worst performing months for each company
--     (highest and lowest Saudi % across 2023)
SELECT
    c.company_name,
    MAX(CASE WHEN rn_best  = 1 THEN snapshot_month END)  AS best_month,
    ROUND(MAX(CASE WHEN rn_best  = 1 THEN saudi_pct END) * 100, 1) AS best_pct,
    MAX(CASE WHEN rn_worst = 1 THEN snapshot_month END)  AS worst_month,
    ROUND(MAX(CASE WHEN rn_worst = 1 THEN saudi_pct END) * 100, 1) AS worst_pct
FROM (
    SELECT
        company_id,
        snapshot_month,
        saudi_pct,
        ROW_NUMBER() OVER (PARTITION BY company_id ORDER BY saudi_pct DESC) AS rn_best,
        ROW_NUMBER() OVER (PARTITION BY company_id ORDER BY saudi_pct ASC)  AS rn_worst
    FROM monthly_snapshots
) ranked
JOIN companies c USING (company_id)
WHERE rn_best = 1 OR rn_worst = 1
GROUP BY c.company_name
ORDER BY c.company_name;

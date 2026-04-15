"""
Nitaqat Workforce Compliance Database
Generates a realistic SQLite database modeling Saudi Nitaqat compliance
across 18 Eastern Province companies, 12 months (Jan–Dec 2023).
"""

import sqlite3
import random
from datetime import date, timedelta

random.seed(42)

DB_PATH = "nitaqat_workforce.db"

# -------------------------------------------------------------------
# Reference data
# -------------------------------------------------------------------

SECTORS = [
    (1, "Construction",         "C",  0.06, 0.10, 0.18),  # (id, name, code, yellow_thresh, green_thresh, high_green_thresh)
    (2, "Manufacturing",        "M",  0.05, 0.10, 0.18),
    (3, "Retail",               "R",  0.20, 0.30, 0.40),
    (4, "Information Technology","IT", 0.15, 0.20, 0.30),
    (5, "Healthcare",           "H",  0.10, 0.15, 0.25),
    (6, "Logistics & Transport","L",  0.08, 0.12, 0.20),
    (7, "Finance & Insurance",  "F",  0.25, 0.35, 0.45),
]

# company_size categories: Small (<50), Medium (50-499), Large (500+)
COMPANIES = [
    # (id, name, city, sector_id, size_cat, target_saudi_pct, volatility)
    (1,  "Al-Rajhi Contracting Co.",        "Dammam",  1, "Large",  0.10, 0.02),
    (2,  "Gulf Steel Industries",           "Jubail",  2, "Large",  0.08, 0.015),
    (3,  "Eastern Trading Co.",             "Khobar",  3, "Medium", 0.35, 0.03),
    (4,  "Nakheel Markets",                 "Dammam",  3, "Large",  0.42, 0.025),
    (5,  "Dhahran Tech Solutions",          "Dhahran", 4, "Medium", 0.28, 0.04),
    (6,  "Khobar Systems & Networks",       "Khobar",  4, "Small",  0.18, 0.05),
    (7,  "Al-Shifa Medical Center",         "Dammam",  5, "Medium", 0.20, 0.025),
    (8,  "Gulf Coast Clinic",               "Khobar",  5, "Small",  0.14, 0.03),
    (9,  "Saudi Express Logistics",         "Dammam",  6, "Large",  0.11, 0.015),
    (10, "Al-Amal Transport",               "Jubail",  6, "Medium", 0.09, 0.02),
    (11, "Eastern Province Finance",        "Khobar",  7, "Medium", 0.40, 0.02),
    (12, "Tawuniya Insurance Branch",       "Dammam",  7, "Small",  0.52, 0.025),
    (13, "Jubail Industrial Builders",      "Jubail",  1, "Large",  0.07, 0.015),
    (14, "Petroline Engineering",           "Dhahran", 1, "Large",  0.12, 0.02),
    (15, "Al-Mawrid Retail Group",          "Khobar",  3, "Large",  0.38, 0.025),
    (16, "Eastern Digital Services",        "Dammam",  4, "Medium", 0.22, 0.035),
    (17, "Gulf Pharma Supply",              "Jubail",  5, "Medium", 0.16, 0.02),
    (18, "Dammam Clearance & Freight",      "Dammam",  6, "Medium", 0.10, 0.02),
]

# Total headcount ranges per size category
HEADCOUNT_RANGE = {
    "Small":  (20,  49),
    "Medium": (60,  250),
    "Large":  (400, 1200),
}

MONTHS = [date(2023, m, 1) for m in range(1, 13)]


def band(saudi_pct, yellow_t, green_t, high_green_t):
    if saudi_pct >= 0.40:
        return "Platinum"
    elif saudi_pct >= high_green_t:
        return "High Green"
    elif saudi_pct >= green_t:
        return "Green"
    elif saudi_pct >= yellow_t:
        return "Yellow"
    else:
        return "Red"


def build_db():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    # ------------------------------------------------------------------
    # DDL
    # ------------------------------------------------------------------
    cur.executescript("""
    DROP TABLE IF EXISTS monthly_snapshots;
    DROP TABLE IF EXISTS companies;
    DROP TABLE IF EXISTS sectors;

    CREATE TABLE sectors (
        sector_id        INTEGER PRIMARY KEY,
        sector_name      TEXT    NOT NULL,
        sector_code      TEXT    NOT NULL,
        yellow_threshold REAL    NOT NULL,   -- minimum Saudi % before Red
        green_threshold  REAL    NOT NULL,   -- minimum Saudi % for Green
        high_green_threshold REAL NOT NULL   -- minimum Saudi % for High Green
    );

    CREATE TABLE companies (
        company_id   INTEGER PRIMARY KEY,
        company_name TEXT    NOT NULL,
        city         TEXT    NOT NULL,
        sector_id    INTEGER NOT NULL REFERENCES sectors(sector_id),
        size_cat     TEXT    NOT NULL CHECK(size_cat IN ('Small','Medium','Large'))
    );

    CREATE TABLE monthly_snapshots (
        snapshot_id    INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id     INTEGER NOT NULL REFERENCES companies(company_id),
        snapshot_month DATE    NOT NULL,
        total_headcount  INTEGER NOT NULL,
        saudi_headcount  INTEGER NOT NULL,
        saudi_pct        REAL    GENERATED ALWAYS AS
                            (ROUND(CAST(saudi_headcount AS REAL) / total_headcount, 4)) STORED,
        nitaqat_band     TEXT    NOT NULL
    );
    """)

    # ------------------------------------------------------------------
    # Seed sectors
    # ------------------------------------------------------------------
    cur.executemany(
        "INSERT INTO sectors VALUES (?,?,?,?,?,?)",
        SECTORS
    )

    # ------------------------------------------------------------------
    # Seed companies
    # ------------------------------------------------------------------
    cur.executemany(
        "INSERT INTO companies VALUES (?,?,?,?,?)",
        [(c[0], c[1], c[2], c[3], c[4]) for c in COMPANIES]
    )

    # ------------------------------------------------------------------
    # Generate monthly snapshots
    # ------------------------------------------------------------------
    sector_thresholds = {s[0]: (s[3], s[4], s[5]) for s in SECTORS}
    snapshots = []

    for c in COMPANIES:
        cid, _, _, sector_id, size_cat, base_pct, vol = c
        yt, gt, hgt = sector_thresholds[sector_id]
        low_hc, high_hc = HEADCOUNT_RANGE[size_cat]

        # Start headcount, drift slightly month-to-month
        hc = random.randint(low_hc, high_hc)
        pct = base_pct

        for month in MONTHS:
            # Natural headcount fluctuation
            hc = max(low_hc, hc + random.randint(-8, 10))

            # Saudi % drifts with some noise; slight upward trend mid-year (hiring cycle)
            seasonal_bump = 0.005 if month.month in (4, 5, 9, 10) else 0.0
            pct = max(0.01, min(0.75, pct + random.gauss(0, vol) + seasonal_bump))

            saudi_hc = max(1, round(hc * pct))
            actual_pct = saudi_hc / hc
            b = band(actual_pct, yt, gt, hgt)

            snapshots.append((cid, str(month), hc, saudi_hc, b))

    cur.executemany(
        "INSERT INTO monthly_snapshots (company_id, snapshot_month, total_headcount, saudi_headcount, nitaqat_band) VALUES (?,?,?,?,?)",
        snapshots
    )

    conn.commit()
    conn.close()
    print(f"Database built: {DB_PATH}")
    print(f"  Sectors:           {len(SECTORS)}")
    print(f"  Companies:         {len(COMPANIES)}")
    print(f"  Snapshot records:  {len(snapshots)}")


if __name__ == "__main__":
    build_db()

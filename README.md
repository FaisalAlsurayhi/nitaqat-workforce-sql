# Nitaqat Workforce Compliance — SQL Analysis

Saudi Arabia's Nitaqat system requires private-sector employers to meet sector-specific Saudization quotas. Companies are classified into five bands — **Platinum, High Green, Green, Yellow, Red** — based on the share of Saudi nationals in their workforce. Thresholds vary by sector; a construction firm and a retail chain face very different targets.

This project models 18 fictional companies across the Eastern Province (Dammam, Khobar, Dhahran, Jubail) over 12 months of 2023 and uses SQL to answer the kinds of questions an HR analytics or workforce planning team would actually need answered.

## Why I Built This

This is the main SQL project in my portfolio. I wanted something closer to the kind of workforce or HR reporting question a company in Saudi Arabia might actually care about: who is compliant, who is falling behind, and how many Saudi hires would close the gap.

The SQL work here includes:

- Relational database design with sector, company, and monthly snapshot tables
- SQL joins across normalized tables
- Aggregations by city, sector, company, and compliance status
- CTEs for reusable query logic
- Window functions for month-over-month trend analysis
- Writing up the results in plain business language, not just showing query output

---

## Files

| File | Description |
|------|-------------|
| `setup_database.py` | Builds `nitaqat_workforce.db` — generates schema and populates all tables |
| `analysis_queries.sql` | 16 analytical queries across 5 sections |
| `nitaqat_workforce.db` | SQLite database (auto-generated, not tracked in git) |

---

## Schema

```
sectors                companies               monthly_snapshots
---------              ----------              -----------------
sector_id (PK)         company_id (PK)         snapshot_id (PK)
sector_name            company_name            company_id (FK)
sector_code            city                    snapshot_month
yellow_threshold       sector_id (FK)          total_headcount
green_threshold        size_cat                saudi_headcount
high_green_threshold                           saudi_pct (computed)
                                               nitaqat_band
```

**7 sectors · 18 companies · 216 monthly records (Jan–Dec 2023)**

---

## Setup

```bash
# Requires Python 3.x — no external libraries needed
python setup_database.py

# Open nitaqat_workforce.db in DB Browser for SQLite
# Paste queries from analysis_queries.sql and run them
```

---

## SQL Analysis Sections

The SQL file is split into five parts:

1. **Basic workforce counts**: total headcount, Saudi headcount, expat headcount, and city totals.
2. **Saudization rates and band classification**: Nitaqat band by company and sector benchmarks.
3. **Compliance gap analysis**: Saudi hires needed to reach Green band and downgrade-risk flags.
4. **Sector-level aggregations**: compliance rates and non-compliant appearances by sector.
5. **Trend analysis**: month-over-month Saudization changes and January-to-December band movement.

## Analysis & Findings

### Query 1 — Workforce Snapshot (December 2023)
**Question:** Who are the biggest employers, and what does their workforce composition look like?

The three largest employers are all in heavy industry — Gulf Steel Industries (1,169 workers), Al-Rajhi Contracting (1,042), and Petroline Engineering (915). These companies are also among the most expat-heavy, with Saudi nationals making up less than 14% of their workforce. In contrast, smaller Finance and IT firms like Tawuniya Insurance (44 workers) and Khobar Systems & Networks (39 workers) have Saudi ratios above 47% and 61% respectively. The pattern is consistent: the bigger the industrial employer, the lower the Saudization rate.

---

### Query 2 — Nitaqat Band Classification (December 2023)
**Question:** What compliance band is each company in right now?

| Band | Companies |
|------|-----------|
| Platinum | Nakheel Markets, Khobar Systems & Networks, Eastern Province Finance, Tawuniya Insurance |
| High Green | Al-Shifa Medical Center, Eastern Digital Services, Gulf Pharma Supply |
| Green | Dhahran Tech Solutions, Saudi Express Logistics, Petroline Engineering, Al-Mawrid Retail Group, Dammam Clearance & Freight |
| Yellow | Al-Rajhi Contracting, Gulf Steel Industries, Eastern Trading Co., Al-Amal Transport, Jubail Industrial Builders |
| Red | Gulf Coast Clinic |

Finance and IT companies dominate the top bands. All five Yellow companies are in Construction, Manufacturing, or Logistics — sectors where large expat workforces are the norm. Gulf Coast Clinic is the only Red-band company, sitting at 6.0% Saudi against a 15% sector threshold.

---

### Query 3 — Compliance Gap: Saudi Hires Needed for Green
**Question:** For non-compliant companies, exactly how many Saudi hires would bring them into Green band?

| Company | Current Saudi % | Green Threshold | Hires Needed |
|---------|----------------|-----------------|--------------|
| Jubail Industrial Builders | 6.3% | 10% | 28 |
| Al-Rajhi Contracting Co. | 8.2% | 10% | 20 |
| Gulf Steel Industries | 8.4% | 10% | 19 |
| Gulf Coast Clinic | 6.0% | 15% | 5 |
| Al-Amal Transport | 8.6% | 12% | 4 |
| Eastern Trading Co. | 28.4% | 30% | 3 |

The three Jubail and Dammam industrial companies account for the bulk of the compliance gap. Eastern Trading Co. is the most fixable — just 3 Saudi hires would move them from Yellow to Green. Jubail Industrial Builders faces the largest absolute gap at 28 hires, partly because of its large 758-person workforce.

---

### Query 4 — Sector Compliance Rate (Full Year 2023)
**Question:** Which sectors were consistently compliant all year, and which struggled?

| Sector | Compliance Rate |
|--------|----------------|
| Finance & Insurance | 100% |
| Information Technology | 94.4% |
| Retail | 86.1% |
| Healthcare | 83.3% |
| Logistics & Transport | 52.8% |
| Construction | 47.2% |
| Manufacturing | 33.3% |

Finance & Insurance was compliant every single month across both companies. Manufacturing was the worst performer — compliant in only 1 out of 3 months on average. Construction and Logistics both spent more time below Green than above it. The top four sectors all have higher white-collar employment ratios, which naturally supports higher Saudization rates.

---

### Query 5 — Band Movement: January vs December 2023
**Question:** Which companies improved or declined over the full year?

**Improved (4 companies)**
- Khobar Systems & Networks: Green → Platinum (25.0% → 61.5%)
- Al-Shifa Medical Center: Green → High Green (22.7% → 28.4%)
- Eastern Digital Services: Green → High Green (22.4% → 30.8%)
- Gulf Pharma Supply: Green → High Green (19.9% → 30.2%)

**Declined (2 companies)**
- Al-Rajhi Contracting: Green → Yellow (11.6% → 8.2%)
- Eastern Trading Co.: Green → Yellow (39.1% → 28.4%)

**Unchanged (12 companies)**
Most companies held their band throughout the year. Notably, Gulf Coast Clinic remained Red all year — starting at 9.5% and ending at 6.0%, actually worsening. Khobar Systems & Networks had the most dramatic improvement, more than doubling its Saudi ratio from 25% to 61.5%.

---

## Key Takeaways

- **Sector matters more than company size** for Nitaqat compliance. Finance and IT firms consistently outperform regardless of headcount, while industrial sectors struggle structurally.
- **Three companies account for most of the compliance gap** — Jubail Industrial Builders, Al-Rajhi Contracting, and Gulf Steel together need 67 Saudi hires to reach Green band.
- **Two companies backslid in 2023** — Al-Rajhi Contracting and Eastern Trading Co. both dropped from Green to Yellow, showing that compliance is not just about reaching a band but maintaining it.
- **Gulf Coast Clinic is the most at-risk** — the only Red-band company, and its Saudi ratio declined over the year rather than improving.

---

## Notes on Data

All company names, headcount figures, and Saudization rates are **fictional and modeled for analytical purposes**. Nitaqat thresholds used here are simplified approximations; actual thresholds are published by the Ministry of Human Resources and Social Development and vary across dozens of economic activity sub-categories.

---

## Tools

`SQL` · `SQLite` · `Python 3` · `DB Browser for SQLite`

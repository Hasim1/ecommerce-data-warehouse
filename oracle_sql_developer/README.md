# Oracle SQL Developer Version

This folder contains the complete **Oracle Database port** of the E-commerce
Data Warehouse project — same star schema, same mock-data logic, same seven
analytical queries, translated to Oracle SQL / PL/SQL.

The PostgreSQL version in the repository root remains the primary version;
this port exists so the project can also be run end-to-end in
**Oracle SQL Developer**.

## Requirements

- **Oracle Database 12c R2 or newer** — tested syntax targets 19c / 21c XE;
  Oracle 23ai also works.
  - No database yet? Free options: [Oracle Database XE](https://www.oracle.com/database/technologies/xe-downloads.html)
    (local install), the [Oracle Cloud Free Tier](https://www.oracle.com/cloud/free/)
    Autonomous Database, or a `container-registry.oracle.com` Docker image.
- **Oracle SQL Developer** (any recent version) connected to that database
  as a normal user (e.g. `hr` or your own user) — **do not run as SYS/SYSTEM**.

## Folder contents

```text
oracle_sql_developer/
├── README.md                          ← this file (run order + differences)
├── schema/
│   └── create_tables_oracle.sql       ← star schema DDL (Oracle SQL)
├── data/
│   └── sample_data_oracle.sql         ← dimensions + PL/SQL fact generator
└── queries/
    ├── 01_monthly_sales_growth.sql
    ├── 02_customer_lifetime_value.sql
    ├── 03_category_performance.sql
    ├── 04_top_products.sql
    ├── 05_sales_by_location.sql
    ├── 06_discount_impact.sql
    └── 07_monthly_kpi_report.sql
```

## Run order (SQL Developer)

Run the scripts **in this exact order** — the data script needs the tables,
and the queries need the data:

| Step | File | How to run | What it does |
|------|------|-----------|--------------|
| 1 | `schema/create_tables_oracle.sql` | Open the file, **Run Script (F5)** | Drops any previous version of the 7 tables, then creates the full star schema with constraints, indexes and comments |
| 2 | `data/sample_data_oracle.sql` | **Run Script (F5)** | Loads the 730-day date dimension, all dimension rows, then generates ~5,000 fact rows via a PL/SQL block (takes a few seconds) and commits |
| 3 | any file in `queries/` | **Run Script (F5)**, or click inside one statement and **Run Statement (Ctrl+Enter)** for a grid view | The seven analyses (MoM growth, CLV, categories, top products, geography, discounts, monthly KPIs) |

Notes:

- **Use Run Script (F5), not Run Statement, for steps 1 and 2** — those files
  contain multiple statements and PL/SQL blocks.
- Both scripts are **re-runnable**: step 1 drops and recreates the tables, so
  re-running step 1 + step 2 always gives a clean, identical dataset.
- Always re-run step 1 before re-running step 2. The generator expects
  freshly created tables (identity keys starting from 1 and empty facts).

## Reproducibility

The fact generator seeds Oracle's random generator with
`DBMS_RANDOM.SEED(42)`, so **every run on a fresh schema produces the same
dataset**. The exact numbers differ from the PostgreSQL dataset (the two
engines use different random-number generators), but the statistical patterns
are identical: Nov–Dec holiday peak, weekend uplift, skewed bestsellers and
heavy-buyer customers, ~35% of order lines discounted 5–25%.

## PostgreSQL → Oracle: what changed

| PostgreSQL (root folders) | Oracle (this folder) |
|---|---|
| `VARCHAR(n)` / `NUMERIC(p,s)` / `BOOLEAN` | `VARCHAR2(n CHAR)` / `NUMBER(p,s)` / `NUMBER(1)` with a `CHECK (col IN (0,1))` |
| `DROP TABLE IF EXISTS` | PL/SQL block over `user_tables` with `EXECUTE IMMEDIATE` |
| Multi-row `INSERT ... VALUES (…), (…)` | One `INSERT` per row |
| `generate_series(...)` | `CONNECT BY LEVEL` on `dual` |
| `setseed(0.42)` / `random()` | `DBMS_RANDOM.SEED(42)` / `DBMS_RANDOM.VALUE` |
| SQL-level fact generator (CTEs + `LATERAL`) | PL/SQL anonymous block with loops (idiomatic Oracle) |
| `LIMIT 10` | `FETCH FIRST 10 ROWS ONLY` |
| `EXTRACT(ISODOW ...)` | `TRUNC(d) - TRUNC(d,'IW') + 1` (NLS-independent ISO weekday) |
| `TO_CHAR(d,'Month')` | `TO_CHAR(d,'Month','NLS_DATE_LANGUAGE=ENGLISH')` (locale-safe) |

Everything analytical — CTEs, `LAG`, `RANK`, `DENSE_RANK`, window aggregates,
`GROUPING SETS`, `NULLS FIRST` — is identical in both dialects, which is
exactly the point: the star schema and the analyses are engine-independent.

## Scaling the data

To generate more data, raise the base orders-per-day constant inside the
PL/SQL generator in `data/sample_data_oracle.sql`. For CSV-based loading at
scale (e.g. data from [Mockaroo](https://mockaroo.com)), use SQL Developer's
**Import Data** wizard (right-click a table → Import Data…) or SQL*Loader.

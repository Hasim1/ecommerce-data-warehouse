# E-commerce Data Warehouse & BI Analytics — Project Report

> Personal / academic portfolio project. All data is simulated (mock data);
> this project is not based on any real company's data.

---

## 1. Project Overview

### What the project is

This project designs and implements a **dimensional data warehouse** for a
fictional international e-commerce retailer. It collects sales, customer,
product, store, payment, shipping and calendar data into a **Star Schema**
optimized for analytics, and delivers a suite of **advanced analytical SQL
queries** that answer real business questions: revenue growth, customer
lifetime value, category performance, discount effectiveness and monthly KPIs.

### What problem it solves

Operational (OLTP) e-commerce databases are designed for fast, small
transactions — placing an order, updating stock. They are **not** designed for
questions like *"How did revenue grow month over month in every market last
year?"*. Answering that on an OLTP schema means joining many normalized
tables, which is slow, complex and risks disturbing the live shop.

A data warehouse solves this by restructuring the data around **analysis**
instead of transactions:

- Historical data is stored in a shape optimized for aggregation.
- Business logic (net revenue, profit, calendar attributes) is calculated
  once at load time, not re-derived in every report.
- Analysts and BI tools query a simple, well-documented star schema instead
  of dozens of operational tables.

### Why an e-commerce company needs this

- **Decision support** — management needs trends and KPIs, not raw order rows.
- **Single source of truth** — every report calculates "revenue" the same way
  because the definition lives in the warehouse, not in each analyst's script.
- **Performance** — analytical queries scan millions of fact rows; a star
  schema with indexed surrogate keys keeps that fast.
- **BI tooling** — Power BI and Tableau are built to consume star schemas
  directly; the model maps 1:1 onto their semantic layers.

### What data is collected

| Data area | Warehouse table | Examples |
|---|---|---|
| Sales transactions | `fact_sales` | quantity, price, discount, revenue, profit |
| Customers | `dim_customer` | name, city, country, segment |
| Products | `dim_product` | SKU, category, brand, cost, price |
| Calendar | `dim_date` | year, quarter, month, weekday, weekend flag |
| Stores / channels | `dim_store` | online vs. retail, location |
| Payments | `dim_payment_method` | credit card, PayPal, COD… |
| Shipping | `dim_shipping_method` | standard, express, delivery days, fee |

### Business questions the project answers

1. Is revenue growing month over month, and by how much? (Query A)
2. Who are our highest-value customers? (Query B)
3. Which product categories drive revenue and profit? (Query C)
4. Which individual products are the bestsellers? (Query D)
5. Which countries and cities generate the most revenue? (Query E)
6. Do discounts increase sales enough to justify the margin they cost? (Query F)
7. How does the business perform on all core KPIs each month? (Query G)

### How this demonstrates BI and data analysis skills

The project covers the full analytical workflow: **modeling** (grain
definition, surrogate keys, fact/dimension separation), **implementation**
(DDL with constraints and indexes), **data engineering** (a reproducible data
generator with seasonality), **analysis** (window functions, CTEs, GROUPING
SETS), and **communication** (each query is tied to a business question and a
decision it supports).

---

## 2. Technology Choice: PostgreSQL (recommended) vs SQL Server

**Recommendation: PostgreSQL.**

| Criterion | PostgreSQL | SQL Server |
|---|---|---|
| Cost / licensing | Free, open source | Free only in Express/Developer editions |
| Platforms | macOS, Linux, Windows | Windows, Linux (no native macOS) |
| Analytical SQL | Full window functions, CTEs, GROUPING SETS, `generate_series()` | Full window functions, CTEs, GROUPING SETS |
| Portfolio value | Reviewers can clone and run in minutes (also via Docker) | Reviewer needs a SQL Server instance |
| Industry usage | Dominant in startups, analytics and cloud data stacks | Dominant in Microsoft-centric enterprises |

Both engines handle this project equally well — the deciding factors are
**zero cost, cross-platform availability, and ease of reproduction** for
anyone reviewing the GitHub repository. `generate_series()` also makes the
date dimension and the mock-data generator elegant.

The project remains **portable**: a complete T-SQL version of the schema is
provided in `schema/create_tables_sqlserver.sql`, and a full **Oracle port**
(schema, PL/SQL data generator and all seven queries, ready for SQL
Developer) is provided in `oracle_sql_developer/`. Every analytical query
runs on SQL Server with at most two mechanical changes:

| PostgreSQL | SQL Server |
|---|---|
| `LIMIT 10` | `SELECT TOP 10` |
| `ORDER BY ... NULLS FIRST` | remove (or emulate with a `CASE` sort key) |
| `generate_series(...)` (data generator only) | `GENERATE_SERIES(...)` (SQL Server 2022+) or a numbers table |
| `TO_CHAR(date, 'YYYYMMDD')` (data generator only) | `FORMAT(date, 'yyyyMMdd')` or `CONVERT(varchar, date, 112)` |

---

## 3. Star Schema Design and ERD Explanation

### Why a Star Schema

A star schema is the standard dimensional-modeling pattern (Kimball
methodology) for analytical databases:

- **One central fact table** holds the *measurable events* (order lines) as
  numbers plus foreign keys.
- **Dimension tables** hold the *descriptive context* (who, what, when,
  where, how) as denormalized, human-readable attributes.

Compared to a normalized (3NF) model, the star schema trades some storage
redundancy for **dramatically simpler and faster analytical queries**: every
report is the same shape — `fact JOIN dimension(s) GROUP BY attribute(s)` —
with at most one join per dimension and no join chains.

### Why `fact_sales` is the central table

The business process being measured is **selling**. Every measurable event
(an order line) becomes one fact row. The **grain** — one row per product per
order — is the most detailed level available, which means any coarser view
(daily, monthly, per category, per country) can be derived by aggregation,
but nothing is lost.

`fact_sales` contains three kinds of columns:

1. **Foreign keys** to the six dimensions (the "points of the star").
2. **Degenerate dimension** `order_id` — an identifier with no attributes of
   its own, kept directly in the fact table (standard Kimball technique) so
   that order-level metrics like Average Order Value can be computed with
   `COUNT(DISTINCT order_id)`.
3. **Measures** — additive numbers (`quantity`, `gross_amount`,
   `discount_amount`, `total_amount`, `profit_amount`) that can be summed
   across any combination of dimensions.

Note that `unit_cost` is **copied into the fact row at load time**. If the
product's cost changes next year, historical profit figures stay correct
because they were computed with the cost valid at the time of sale.

### How dimensions connect

Every relationship is **one-to-many**: one dimension row (e.g. customer
"Emma Müller") relates to many fact rows (all her order lines). The fact
table stores compact integer **surrogate keys**; the business keys
(`customer_id`, `sku`) live in the dimensions. Surrogate keys decouple the
warehouse from source systems and are the standard mechanism for handling
slowly changing dimensions later.

`dim_date` deserves special mention: pre-computing year, quarter, month name,
weekday and a weekend flag means **no date arithmetic in queries** — grouping
by fiscal or calendar periods is a simple equality join plus `GROUP BY`.

### How this improves analytical performance

- **Few, predictable joins** — always fact → dimension on an indexed integer key.
- **Narrow keys** — integer surrogate keys keep the (large) fact table small.
- **Indexed foreign keys** — every FK column on `fact_sales` is indexed,
  because they are the join/filter columns of every query.
- **Additive measures** — the engine can aggregate `SUM(total_amount)` over
  millions of rows without row-by-row logic.

### How this supports BI reporting

Power BI and Tableau model data as facts and dimensions internally. Pointing
either tool at this schema gives instant drag-and-drop analysis: dimensions
become slicers/axes, measures become values. No re-modeling is required —
which is precisely the point of building the warehouse this way.

### How to draw / present the ERD on GitHub

Three ready-made options are included in this repository:

1. **`diagrams/star_schema_erd.svg`** — a finished vector diagram that
   GitHub renders natively (referenced from the README).
2. **`diagrams/star_schema.dbml`** — paste into [dbdiagram.io](https://dbdiagram.io),
   auto-layout the tables with `fact_sales` in the middle, then
   *Export → PNG* to produce `star_schema_erd.png`.
3. **Mermaid ER diagram** embedded in the README — GitHub renders Mermaid
   code blocks automatically, so the diagram stays version-controlled as text.

Layout convention: place the fact table in the centre, dimensions around it,
draw one line per foreign key, and mark cardinality `1` on the dimension side
and `*` (many) on the fact side.

---

## 4. Business Intelligence Explanation of Each Query

### Query A — Month-over-Month Sales Growth (`queries/01_monthly_sales_growth.sql`)

- **Business question:** Is revenue growing or shrinking, month by month?
- **Why it matters:** MoM growth is the heartbeat metric of any e-commerce
  business. Absolute revenue hides direction; growth percentage exposes it.
- **Insight gained:** Seasonal peaks (the mock data shows a clear Nov–Dec
  holiday surge), post-holiday dips, and any months that underperform against
  their neighbors — the trigger for investigating campaigns, pricing or stock
  issues in that period.
- **BI connection:** This is the classic *time-series KPI* that anchors every
  executive dashboard. Technically it demonstrates CTEs and the `LAG()`
  window function — comparing each row with its predecessor without a
  self-join.

### Query B — Customer Lifetime Value (`queries/02_customer_lifetime_value.sql`)

- **Business question:** Which customers are worth the most to us?
- **Why it matters:** Acquiring a customer costs money; retention is cheaper.
  Knowing who the top customers are lets marketing target loyalty programs,
  VIP support and win-back campaigns where the return is highest.
- **Insight gained:** A ranked list of customers with total orders, lifetime
  revenue, lifetime profit and average order value — plus first/last order
  dates that hint at churn risk.
- **BI connection:** CLV is a core customer-analytics KPI and the starting
  point for segmentation (e.g. RFM analysis). Technically it demonstrates
  `COUNT(DISTINCT)`, multi-dimension joins and `DENSE_RANK()`.

### Query C — Category Performance (`queries/03_category_performance.sql`)

- **Business question:** Which product categories drive the business?
- **Why it matters:** Assortment, purchasing and marketing budgets are
  allocated by category. Revenue alone misleads — a high-revenue category
  with heavy discounting may earn less profit than a smaller, full-price one.
- **Insight gained:** Units, gross vs. net revenue (i.e. how much discounting
  the category absorbs), profit, margin percentage and each category's share
  of total revenue.
- **BI connection:** Contribution analysis — the basis of merchandising
  dashboards. Technically it demonstrates window functions over aggregates
  (`SUM(SUM(...)) OVER ()`) for share-of-total calculations.

### Query D — Top Products by Revenue (`queries/04_top_products.sql`)

- **Business question:** What are our bestsellers?
- **Why it matters:** Bestsellers must never go out of stock, deserve premium
  page placement, and are the products to feature in campaigns. The revenue
  share column also reveals concentration risk (how dependent the business is
  on a handful of products).
- **Insight gained:** Top-10 ranked products with units, revenue, profit and
  share of total revenue.
- **BI connection:** Pareto / "top-N" analysis, a standard BI pattern.
  Demonstrates `RANK()` and CTE composition.

### Query E — Sales by Country and City (`queries/05_sales_by_location.sql`)

- **Business question:** Which geographic markets generate the most revenue?
- **Why it matters:** Geography drives decisions about marketing spend,
  language support, shipping partners, warehouses and even legal entities.
  Average order value per country also reveals pricing-power differences.
- **Insight gained:** Country ranking with customers, orders, AOV and revenue
  share, plus a drill-down report (country → city) with subtotals and a
  grand total in a single result set.
- **BI connection:** Geographic analysis feeds map visuals in BI tools.
  Technically it demonstrates `GROUPING SETS` — multi-level aggregation in
  one pass, which is exactly what OLAP-style reports need.

### Query F — Discount Impact (`queries/06_discount_impact.sql`)

- **Business question:** Are discounts profitable, or are we buying revenue
  with margin?
- **Why it matters:** Discounts are the most common — and most commonly
  misused — growth lever in e-commerce. This analysis shows what discounting
  actually costs and whether discounted lines move more units.
- **Insight gained:** Order lines bucketed into discount bands (none / low /
  medium / high) with units, revenue given up, net revenue, profit and margin
  per band. If the high-discount band shows collapsing margin without higher
  units per line, promotions need rethinking.
- **BI connection:** Promotion-effectiveness analysis, a staple of retail BI.
  Demonstrates CASE-based bucketing inside a CTE — turning a continuous
  variable into an analyzable dimension.

### Query G — Monthly KPI Report (`queries/07_monthly_kpi_report.sql`)

- **Business question:** How did the business perform, per month, on all
  core KPIs at once?
- **Why it matters:** This is the consolidated management view: revenue,
  orders, average order value, units, active customers, profit and margin in
  one table. It is deliberately shaped like the dataset a Power BI/Tableau
  dashboard would sit on.
- **Insight gained:** A single scan reveals whether revenue growth comes from
  more orders, bigger baskets, or more active customers — three very
  different strategic situations.
- **BI connection:** KPI reporting is the definition of BI. Demonstrates
  clean KPI derivation from a star schema (e.g. AOV as
  `SUM(revenue) / COUNT(DISTINCT order_id)` — possible only because the
  degenerate dimension `order_id` was kept in the fact table).

---

## 5. Scaling the Mock Data

The included generator produces ≈5,000 order lines — enough for every query
to return meaningful, realistic results. To scale further:

- **SQL generator** (included): raise the base orders-per-day value in
  `data/sample_data.sql` (step 7a). Base 4 → ~5k lines/year; base 40 → ~32k
  (the seasonality and noise terms are additive, so volume does not scale
  linearly with the base).
- **Mockaroo** ([mockaroo.com](https://mockaroo.com)): design schemas that
  mirror each dimension, export CSV, and bulk-load with PostgreSQL `\copy`
  (or SQL Server `BULK INSERT`). Best for realistic names/emails at volume.
- Keep the load order: dimensions first, then facts, so foreign keys resolve.

---

## 6. Optional Extension: Power BI / Tableau Dashboard

The warehouse is deliberately BI-tool-ready. A natural extension (not
required for the core SQL project):

1. **Connect** Power BI Desktop (free) or Tableau Public (free) directly to
   the PostgreSQL database.
2. **Model:** both tools auto-detect the star relationships; mark `dim_date`
   as the date table.
3. **Build:**
   - **KPI cards** — total revenue, orders, AOV, active customers (Query G logic)
   - **Line chart** — monthly revenue with MoM growth (Query A)
   - **Bar charts** — top products and category performance (Queries C, D)
   - **Map** — revenue by country (Query E)
   - **Scatter / band chart** — discount band vs. margin (Query F)
   - **Table** — top customers by lifetime value (Query B)
4. **Publish** screenshots to the repository (e.g. `dashboards/` folder) —
   a dashboard screenshot in the README significantly strengthens the
   portfolio impression.

In Power BI, the SQL KPIs translate naturally into DAX measures (e.g.
`Total Revenue = SUM(fact_sales[total_amount])`), which demonstrates that the
warehouse model, not the tool, is doing the heavy lifting.

---

## 7. Honest Framing

This is a **personal/academic project on simulated data**. It demonstrates
data-warehouse design, advanced SQL and BI thinking — it does not claim
production scale, real customer data, or an ETL pipeline from live systems
(listed in the README as future improvements).

---

## 8. Final Delivery Checklist

- [x] **Star Schema design** — fact table at order-line grain + 6 dimensions
- [x] **Fact table** — `fact_sales` with FKs, degenerate dimension, additive measures
- [x] **Dimension tables** — `dim_date`, `dim_customer`, `dim_product`, `dim_store`, `dim_payment_method`, `dim_shipping_method`
- [x] **SQL schema scripts** — PKs, FKs, NOT NULL, CHECKs, DEFAULTs, indexes, comments in three dialects: PostgreSQL (`schema/create_tables.sql`), SQL Server (`schema/create_tables_sqlserver.sql`), Oracle (`oracle_sql_developer/schema/create_tables_oracle.sql`)
- [x] **Sample data** — reproducible seeded generator (~5,000 order lines with seasonality, skew and discounts) for PostgreSQL and Oracle, plus Mockaroo scaling instructions
- [x] **Advanced analytical queries** — A–G in `queries/` (PostgreSQL) and `oracle_sql_developer/queries/` (Oracle): MoM growth (LAG), CLV (DENSE_RANK), category performance, top products (RANK), geography (GROUPING SETS), discount impact, monthly KPI report
- [x] **Business explanations** — question / usefulness / insight / BI connection per query (section 4 above)
- [x] **ERD + explanation** — `diagrams/star_schema_erd.svg`, `diagrams/star_schema.dbml`, Mermaid diagram in README, design rationale (section 3 above)
- [x] **GitHub folder structure** — documented in README and matching the repository
- [x] **README.md** — overview, objectives, tools, schema, how to run (PostgreSQL / Docker / SQL Server / Oracle), insights, skills, future improvements
- [x] **Optional BI dashboard extension** — Power BI / Tableau plan (section 6 above)

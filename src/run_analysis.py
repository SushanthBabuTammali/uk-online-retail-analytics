"""Run the full UK online retail analysis.

1. Execute the SQL files in order inside DuckDB (an in-process SQL database).
2. Export each result table to outputs/*.csv.
3. Draw static charts (PNG) for the README and an interactive HTML dashboard.

Usage (from the project root):
    python src/download_data.py   # once, fetches the raw CSV
    python src/run_analysis.py
"""
from pathlib import Path

import duckdb
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import plotly.graph_objects as go
from plotly.subplots import make_subplots

ROOT = Path(__file__).resolve().parents[1]
SQL_DIR = ROOT / "sql"
OUT = ROOT / "outputs"
OUT.mkdir(exist_ok=True)

TABLES = ["data_quality", "kpi_summary", "monthly", "by_country", "top_products",
          "order_timing", "segment_summary", "cohort_retention", "retention_curve"]


def run_sql(con: duckdb.DuckDBPyConnection) -> None:
    for sql_file in sorted(SQL_DIR.glob("*.sql")):
        print(f"running {sql_file.name}")
        con.execute(sql_file.read_text())


def export(con) -> dict:
    frames = {}
    for t in TABLES:
        df = con.execute(f"SELECT * FROM {t}").df()
        df.to_csv(OUT / f"{t}.csv", index=False)
        frames[t] = df
    return frames


def static_charts(f: dict) -> None:
    plt.style.use("seaborn-v0_8-whitegrid")

    # 1. Monthly revenue trend
    m = f["monthly"]
    fig, ax = plt.subplots(figsize=(10, 4.5))
    full = m[~m["partial_month"]]
    ax.plot(full["month"], full["revenue_gbp"] / 1000, marker="o", color="#2563eb")
    ax.set_title("Monthly revenue (£k) — peaks before Christmas")
    ax.set_ylabel("£ thousands")
    fig.tight_layout()
    fig.savefig(OUT / "monthly_revenue.png", dpi=150)
    plt.close(fig)

    # 2. RFM segments: share of customers vs share of revenue
    s = f["segment_summary"]
    fig, ax = plt.subplots(figsize=(10, 4.5))
    x = range(len(s))
    ax.bar([i - 0.2 for i in x], s["pct_customers"], width=0.4, label="% of customers", color="#94a3b8")
    ax.bar([i + 0.2 for i in x], s["pct_revenue"], width=0.4, label="% of revenue", color="#2563eb")
    ax.set_xticks(list(x), s["segment"], rotation=15)
    ax.set_ylabel("%")
    ax.set_title("RFM segments — a small group of customers drives most revenue")
    ax.legend()
    fig.tight_layout()
    fig.savefig(OUT / "rfm_segments.png", dpi=150)
    plt.close(fig)

    # 3. Cohort retention heat map
    c = f["cohort_retention"].pivot(index="cohort_month", columns="months_since", values="retention_pct")
    c = c.drop(columns=0, errors="ignore")
    fig, ax = plt.subplots(figsize=(11, 5.5))
    ax.grid(False)
    im = ax.imshow(c.values, cmap="Blues", aspect="auto", vmin=0, vmax=50)
    ax.set_yticks(range(len(c.index)), [d.strftime("%b %Y") for d in c.index])
    ax.set_xticks(range(len(c.columns)), c.columns)
    ax.set_xlabel("Months since first purchase")
    ax.set_title("Cohort retention (% of each cohort buying again)")
    for i in range(c.shape[0]):
        for j in range(c.shape[1]):
            v = c.values[i, j]
            if v == v:  # not NaN
                ax.text(j, i, f"{v:.0f}", ha="center", va="center", fontsize=7,
                        color="white" if v > 30 else "black")
    fig.colorbar(im, ax=ax, label="%")
    fig.tight_layout()
    fig.savefig(OUT / "cohort_retention.png", dpi=150)
    plt.close(fig)


def dashboard(f: dict) -> None:
    k = f["kpi_summary"].iloc[0]
    m = f["monthly"]
    s = f["segment_summary"]
    ctry = f["by_country"].head(8)
    curve = f["retention_curve"]

    fig = make_subplots(
        rows=2, cols=2,
        subplot_titles=("Monthly revenue (£)", "Revenue by RFM segment (£)",
                        "Top countries outside the UK (£)", "Average retention by month (%)"),
        vertical_spacing=0.14,
    )
    fig.add_trace(go.Scatter(x=m["month"], y=m["revenue_gbp"], mode="lines+markers", name="Revenue"), 1, 1)
    fig.add_trace(go.Bar(x=s["segment"], y=s["revenue_gbp"], name="Segment revenue"), 1, 2)
    intl = ctry[ctry["country"] != "United Kingdom"]
    fig.add_trace(go.Bar(x=intl["country"], y=intl["revenue_gbp"], name="Country revenue"), 2, 1)
    fig.add_trace(go.Scatter(x=curve["months_since"], y=curve["avg_retention_pct"], mode="lines+markers",
                             name="Retention"), 2, 2)
    fig.update_layout(
        height=820, showlegend=False, template="plotly_white",
        title=(f"UK Online Retail — £{k.total_revenue_gbp:,.0f} revenue · {k.orders:,} orders · "
               f"{k.customers:,} customers · AOV £{k.avg_order_value_gbp:,.2f}"),
    )
    fig.write_html(OUT / "dashboard.html", include_plotlyjs="cdn")


def main() -> None:
    con = duckdb.connect()
    # SQL paths are relative to the project root
    import os
    os.chdir(ROOT)
    run_sql(con)
    frames = export(con)
    static_charts(frames)
    dashboard(frames)
    print("\nKPI summary")
    print(frames["kpi_summary"].T.to_string(header=False))
    print("\nSegments")
    print(frames["segment_summary"].to_string(index=False))


if __name__ == "__main__":
    main()

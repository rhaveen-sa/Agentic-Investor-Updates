"""Build the October 2026 investor update for the Reson8 demo.

Reads the same mock sources the app uses (demo/reson8-mock/*.json), computes
every figure from them, and writes october-2026.html next to this file.
Nothing is typed in by hand: each number in the report carries the id of the
source record it came from, the way the app's report does.

    python3 demo/investor-report/build.py

Print the HTML to PDF from a browser, or use the Chrome command in README.md.
"""

import html
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
MOCK = HERE.parent / "reson8-mock"


def load(name):
    return json.loads((MOCK / f"{name}.json").read_text(encoding="utf-8"))


def items(name):
    return {i["id"]: i for i in load(name)["items"]}


baseline = {f["metric"]: f for f in load("baseline")["facts"]}
stripe, hubspot, jamie = items("stripe"), items("hubspot"), items("jamie")
linkedin, github, packages = items("linkedin"), items("github"), items("packages")
replies = load("slack_replies")


def kpi(source, item_id, metric):
    for f in source[item_id]["facts"]:
        if f.get("metric") == metric:
            return f["value"]
    raise KeyError(metric)


oct_ = {
    "arr": kpi(stripe, "stripe-oct-close", "arr"),
    "nrr": kpi(stripe, "stripe-oct-close", "nrr"),
    "burn": kpi(stripe, "stripe-oct-close", "burn"),
    "cash": kpi(stripe, "stripe-oct-close", "cash"),
    "runway": kpi(stripe, "stripe-oct-close", "runway"),
    "customers": kpi(hubspot, "hs-oct-close", "customers"),
    "demos": kpi(hubspot, "hs-oct-close", "demos"),
}
sep = {k: baseline[k]["value"] for k in oct_}
ref_oct = {"arr": "stripe-oct-close", "nrr": "stripe-oct-close", "burn": "stripe-oct-close",
           "cash": "stripe-oct-close", "runway": "stripe-oct-close",
           "customers": "hs-oct-close", "demos": "hs-oct-close"}
ref_sep = {k: baseline[k]["ref"] for k in oct_}


# ---------------------------------------------------------------- default alive
# Same model as AppState.buildDefaultAlive in the app: expenses stay flat,
# revenue keeps growing at this month's rate, the gap is paid from cash.

REVENUE = oct_["arr"] / 12
GROWTH = oct_["arr"] / sep["arr"] - 1


def simulate(g, burn=oct_["burn"], cash=oct_["cash"], revenue=REVENUE, horizon=120):
    expenses = burn + revenue
    r, c = revenue, cash
    for m in range(horizon):
        if r >= expenses:
            return True, m, c
        c -= expenses - r
        if c <= 0:
            return False, m + 1, 0.0
        r *= 1 + g
    return False, horizon, c


def max_burn(g=None):
    g = GROWTH if g is None else g
    lo, hi = oct_["burn"], 2_000_000.0
    for _ in range(60):
        mid = (lo + hi) / 2
        if simulate(g, burn=mid)[0]:
            lo = mid
        else:
            hi = mid
    return lo


def min_growth(burn=oct_["burn"]):
    lo, hi = 0.0, 1.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if simulate(mid, burn=burn)[0]:
            hi = mid
        else:
            lo = mid
    return hi


ALIVE, BE_MONTH, CASH_LEFT = simulate(GROWTH)
MIN_G = min_growth()
MAX_BURN = max_burn()
EXPENSES = oct_["burn"] + REVENUE

MONTHS = ["Oct 2026", "Nov 2026", "Dec 2026", "Jan 2027", "Feb 2027", "Mar 2027", "Apr 2027",
          "May 2027", "Jun 2027", "Jul 2027", "Aug 2027", "Sep 2027", "Oct 2027", "Nov 2027",
          "Dec 2027", "Jan 2028"]


def projection(g, months=16):
    rows, r, c = [], REVENUE, oct_["cash"]
    for m in range(months):
        rows.append((m, r, EXPENSES, c))
        c += r - EXPENSES
        r *= 1 + g
    return rows


PROJ = projection(GROWTH)


# ---------------------------------------------------------------- formatting

def eur(v, digits=0):
    a = abs(v)
    sign = "−" if v < 0 else ""
    if a >= 1_000_000:
        return f"{sign}€{a / 1_000_000:.2f}M"
    if a >= 1000:
        return f"{sign}€{a / 1000:.{digits}f}k"
    return f"{sign}€{a:.0f}"


def esc(s):
    return html.escape(str(s), quote=True)


def src(*ids):
    return "".join(f'<a class="src" href="#{esc(i)}">{esc(i)}</a>' for i in ids)


def delta(cur, prev, kind):
    d = cur - prev
    if kind == "pct":
        txt = f"{d / prev * 100:+.1f}%"
    elif kind == "pp":
        txt = f"{d:+.0f}pp"
    elif kind == "eur":
        txt = ("+" if d >= 0 else "−") + eur(abs(d))
    else:
        txt = f"{d:+.0f}"
    return txt.replace("-", "−")


# ---------------------------------------------------------------- charts
# Static SVG. Colours: series blue/orange (validated pair), status green/red
# for alive/dead and up/down, always with a text label beside them.

BLUE, ORANGE = "#2a78d6", "#eb6834"
GOOD, BAD = "#0ca30c", "#d03b3b"
INK, INK2, MUTED, GRID = "#0f1419", "#2b3640", "#64748b", "#e2e8f0"


def svg_open(w, h, label):
    return (f'<svg viewBox="0 0 {w} {h}" width="100%" role="img" aria-label="{esc(label)}" '
            f'font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif">')


def chart_projection():
    w, h, l, r, t, b = 680, 270, 64, 128, 18, 40
    pw, ph = w - l - r, h - t - b
    ymax = 400_000
    n = len(PROJ) - 1
    x = lambda m: l + m / n * pw
    y = lambda v: t + ph - min(v, ymax) / ymax * ph
    out = [svg_open(w, h, "Monthly revenue against flat monthly expenses, October 2026 to January 2028")]
    for v in range(0, ymax + 1, 100_000):
        out.append(f'<line x1="{l}" x2="{l + pw}" y1="{y(v):.1f}" y2="{y(v):.1f}" stroke="{GRID}"/>')
        out.append(f'<text x="{l - 8}" y="{y(v) + 4:.1f}" font-size="11" fill="{MUTED}" text-anchor="end">{eur(v)}</text>')
    for m in range(0, n + 1, 3):
        out.append(f'<text x="{x(m):.1f}" y="{h - 18}" font-size="11" fill="{MUTED}" text-anchor="middle">{MONTHS[m]}</text>')
    # break-even marker
    bx = x(BE_MONTH)
    out.append(f'<line x1="{bx:.1f}" x2="{bx:.1f}" y1="{t}" y2="{t + ph}" stroke="{INK2}" stroke-dasharray="4 4"/>')
    out.append(f'<text x="{bx - 6:.1f}" y="{t + 12}" font-size="11.5" fill="{INK2}" text-anchor="end" font-weight="600">Break-even, {MONTHS[BE_MONTH]}</text>')
    rev = " ".join(f"{x(m):.1f},{y(rv):.1f}" for m, rv, _, _ in PROJ)
    exp = " ".join(f"{x(m):.1f},{y(ex):.1f}" for m, _, ex, _ in PROJ)
    out.append(f'<polyline points="{exp}" fill="none" stroke="{ORANGE}" stroke-width="2"/>')
    out.append(f'<polyline points="{rev}" fill="none" stroke="{BLUE}" stroke-width="2"/>')
    for m, rv, ex, _ in PROJ:
        out.append(f'<circle cx="{x(m):.1f}" cy="{y(rv):.1f}" r="5" fill="{BLUE}" stroke="#fff" stroke-width="2">'
                   f'<title>{MONTHS[m]}: revenue {eur(rv)}/mo, expenses {eur(ex)}/mo</title></circle>')
    # direct labels at the right edge
    last = PROJ[-1]
    out.append(f'<text x="{l + pw + 8}" y="{y(last[2]) + 4:.1f}" font-size="12" fill="{INK2}">Expenses, flat</text>')
    out.append(f'<text x="{l + pw + 10}" y="{y(last[1]) + 4:.1f}" font-size="12" fill="{INK2}">Revenue, +{GROWTH * 100:.1f}%/mo</text>')
    out.append("</svg>")
    return "".join(out)


def chart_cash():
    w, h, l, r, t, b = 680, 190, 64, 128, 14, 40
    pw, ph = w - l - r, h - t - b
    ymax = 4_000_000
    n = len(PROJ) - 1
    x = lambda m: l + m / n * pw
    y = lambda v: t + ph - max(v, 0) / ymax * ph
    out = [svg_open(w, h, "Projected cash balance, October 2026 to January 2028")]
    for v in range(0, ymax + 1, 1_000_000):
        out.append(f'<line x1="{l}" x2="{l + pw}" y1="{y(v):.1f}" y2="{y(v):.1f}" stroke="{GRID}"/>')
        out.append(f'<text x="{l - 8}" y="{y(v) + 4:.1f}" font-size="11" fill="{MUTED}" text-anchor="end">{eur(v) if v else "€0"}</text>')
    for m in range(0, n + 1, 3):
        out.append(f'<text x="{x(m):.1f}" y="{h - 18}" font-size="11" fill="{MUTED}" text-anchor="middle">{MONTHS[m]}</text>')
    pts = " ".join(f"{x(m):.1f},{y(c):.1f}" for m, _, _, c in PROJ)
    out.append(f'<polyline points="{pts}" fill="none" stroke="{BLUE}" stroke-width="2"/>')
    for m, _, _, c in PROJ:
        out.append(f'<circle cx="{x(m):.1f}" cy="{y(c):.1f}" r="4" fill="{BLUE}" stroke="#fff" stroke-width="2"><title>{MONTHS[m]}: cash {eur(c)}</title></circle>')
    bx, by = x(BE_MONTH), y(PROJ[BE_MONTH][3])
    out.append(f'<circle cx="{bx:.1f}" cy="{by:.1f}" r="6" fill="#fff" stroke="{INK}" stroke-width="2"/>')
    out.append(f'<text x="{bx:.1f}" y="{by - 12:.1f}" font-size="11.5" fill="{INK2}" text-anchor="middle" font-weight="600">Low point {eur(PROJ[BE_MONTH][3])}</text>')
    out.append("</svg>")
    return "".join(out)


def chart_map():
    """Default alive / default dead across monthly growth (x) and net burn (y)."""
    w, h, l, r, t, b = 680, 300, 74, 24, 16, 44
    pw, ph = w - l - r, h - t - b
    gmax, bmin, bmax = 0.25, 150_000, 350_000
    x = lambda g: l + min(g, gmax) / gmax * pw
    y = lambda v: t + ph - (v - bmin) / (bmax - bmin) * ph
    steps = 40
    edge = []
    for i in range(steps + 1):
        burn = bmin + (bmax - bmin) * i / steps
        edge.append((min_growth(burn), burn))
    edge_pts = [(x(g), y(bv)) for g, bv in edge]
    dead = [(l, y(bmin))] + edge_pts + [(l, y(bmax))]
    alive = edge_pts + [(l + pw, y(bmax)), (l + pw, y(bmin))]
    poly = lambda pts: " ".join(f"{px:.1f},{py:.1f}" for px, py in pts)
    out = [svg_open(w, h, "Map of default alive and default dead by monthly ARR growth and monthly net burn")]
    out.append(f'<polygon points="{poly(dead)}" fill="{BAD}" fill-opacity=".10"/>')
    out.append(f'<polygon points="{poly(alive)}" fill="{GOOD}" fill-opacity=".12"/>')
    out.append(f'<polyline points="{poly(edge_pts)}" fill="none" stroke="{INK2}" stroke-width="2"/>')
    for g in (0, 0.05, 0.10, 0.15, 0.20, 0.25):
        out.append(f'<text x="{x(g):.1f}" y="{t + ph + 18}" font-size="11" fill="{MUTED}" text-anchor="middle">{g * 100:.0f}%</text>')
    out.append(f'<text x="{l + pw / 2:.1f}" y="{h - 6}" font-size="11.5" fill="{INK2}" text-anchor="middle">Monthly ARR growth, held steady</text>')
    for bv in range(bmin, bmax + 1, 50_000):
        out.append(f'<text x="{l - 8}" y="{y(bv) + 4:.1f}" font-size="11" fill="{MUTED}" text-anchor="end">{eur(bv)}</text>')
    out.append(f'<text transform="translate(14 {t + ph / 2:.1f}) rotate(-90)" font-size="11.5" fill="{INK2}" text-anchor="middle">Monthly net burn</text>')
    out.append(f'<text x="{l + 14}" y="{t + 22}" font-size="13" font-weight="700" fill="{BAD}">✕ DEFAULT DEAD</text>')
    out.append(f'<text x="{l + pw - 14}" y="{t + ph - 14}" font-size="13" font-weight="700" fill="{GOOD}" text-anchor="end">✓ DEFAULT ALIVE</text>')
    # where Reson8 is, and the edge on the same row
    cx, cy = x(GROWTH), y(oct_["burn"])
    ex = x(MIN_G)
    out.append(f'<line x1="{ex:.1f}" x2="{cx:.1f}" y1="{cy:.1f}" y2="{cy:.1f}" stroke="{INK}" stroke-dasharray="3 3"/>')
    out.append(f'<circle cx="{ex:.1f}" cy="{cy:.1f}" r="5" fill="#fff" stroke="{INK}" stroke-width="2"><title>Edge at {eur(oct_["burn"])} burn: {MIN_G * 100:.1f}% a month</title></circle>')
    out.append(f'<text x="{ex:.1f}" y="{cy + 20:.1f}" font-size="11.5" fill="{INK2}" text-anchor="middle">edge {MIN_G * 100:.1f}%</text>')
    out.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="7" fill="{INK}" stroke="#fff" stroke-width="2"><title>October: {GROWTH * 100:.1f}% growth, {eur(oct_["burn"])} burn</title></circle>')
    out.append(f'<text x="{cx + 12:.1f}" y="{cy - 10:.1f}" font-size="12" font-weight="700" fill="{INK}">October: {GROWTH * 100:.1f}%, {eur(oct_["burn"])} burn</text>')
    out.append("</svg>")
    return "".join(out)


def bridge_rows():
    rows = [("September ARR", sep["arr"], "total", [ref_sep["arr"]])]
    for iid in ("hs-deal-1142", "hs-deal-1160", "hs-deal-1178"):
        f = hubspot[iid]["facts"][0]
        name = hubspot[iid]["title"].split(": ", 1)[1].split(" paid pilot")[0]
        rows.append((name, f["value"], "up", [iid]))
    f = hubspot["hs-churn-0231"]["facts"][0]
    rows.append(("Helder Notarissen (churn)", f["value"], "down", ["hs-churn-0231"]))
    rows.append(("October ARR", oct_["arr"], "total", [ref_oct["arr"]]))
    return rows


def chart_bridge(rows):
    w, l, r, t, rowh = 680, 250, 70, 6, 30
    h = t + rowh * len(rows) + 26
    vmin, vmax = 300_000, 420_000
    pw = w - l - r
    x = lambda v: l + (v - vmin) / (vmax - vmin) * pw
    out = [svg_open(w, h, "ARR bridge from September to October")]
    for v in range(vmin, vmax + 1, 20_000):
        out.append(f'<line x1="{x(v):.1f}" x2="{x(v):.1f}" y1="{t}" y2="{t + rowh * len(rows)}" stroke="{GRID}"/>')
        out.append(f'<text x="{x(v):.1f}" y="{h - 8}" font-size="11" fill="{MUTED}" text-anchor="middle">{eur(v)}</text>')
    run = 0
    for i, (label, v, kind, _) in enumerate(rows):
        yy = t + i * rowh + 5
        if kind == "total":
            a, z, col, txt = vmin, v, BLUE, eur(v)
            run = v
        else:
            a, z = sorted((run, run + v))
            col = GOOD if kind == "up" else BAD
            txt = ("+" if v > 0 else "−") + eur(abs(v))
            run += v
        out.append(f'<text x="{l - 10}" y="{yy + 15}" font-size="12.5" fill="{INK2}" text-anchor="end">{esc(label)}</text>')
        out.append(f'<rect x="{x(a):.1f}" y="{yy}" width="{max(x(z) - x(a), 3):.1f}" height="{rowh - 10}" rx="3" fill="{col}"><title>{esc(label)}: {txt}</title></rect>')
        out.append(f'<text x="{x(z) + 7:.1f}" y="{yy + 15}" font-size="12" fill="{INK}" font-weight="600">{txt}</text>')
    out.append(f'<text x="{x(vmin) - 2:.1f}" y="{t + rowh * len(rows) + 2}" font-size="0"> </text>')
    out.append("</svg>")
    return "".join(out)


def chart_demos():
    weeks = [("li-wk40", "Week 40"), ("li-wk41", "Week 41"), ("li-wk42", "Week 42"), ("li-wk43", "Week 43")]
    w, h, l, t, b = 330, 170, 34, 22, 30
    bw, gap = 46, 24
    vmax = 50
    ph = h - t - b
    out = [svg_open(w, h, "Demos booked per week in October")]
    for v in (0, 25, 50):
        yy = t + ph - v / vmax * ph
        out.append(f'<line x1="{l}" x2="{w - 6}" y1="{yy:.1f}" y2="{yy:.1f}" stroke="{GRID}"/>')
        out.append(f'<text x="{l - 6}" y="{yy + 4:.1f}" font-size="11" fill="{MUTED}" text-anchor="end">{v}</text>')
    for i, (iid, label) in enumerate(weeks):
        v = linkedin[iid]["data"]["demos"]
        xx = l + 14 + i * (bw + gap)
        bh = v / vmax * ph
        out.append(f'<rect x="{xx}" y="{t + ph - bh:.1f}" width="{bw}" height="{bh:.1f}" rx="4" fill="{BLUE}"><title>{label}: {v} demos</title></rect>')
        out.append(f'<text x="{xx + bw / 2}" y="{t + ph - bh - 6:.1f}" font-size="12" font-weight="600" fill="{INK}" text-anchor="middle">{v}</text>')
        out.append(f'<text x="{xx + bw / 2}" y="{h - 12}" font-size="11" fill="{MUTED}" text-anchor="middle">{label[5:]}</text>')
    v42 = linkedin["li-wk42"]["data"]["demos"]
    out.append(f'<text x="{l + 14 + 2 * (bw + gap) + bw / 2}" y="{t + ph - v42 / vmax * ph - 24:.1f}" font-size="11" fill="{BAD}" text-anchor="middle">ads paused</text>')
    out.append("</svg>")
    return "".join(out)


# ---------------------------------------------------------------- report body

new_arr = sum(hubspot[i]["facts"][0]["value"] for i in ("hs-deal-1142", "hs-deal-1160", "hs-deal-1178"))
churned = hubspot["hs-churn-0231"]["facts"][0]["value"]
pk = packages["pkg-oct-23"]["data"]
assert sep["arr"] + new_arr + churned == oct_["arr"], "ARR bridge does not reconcile"

kpi_rows = [
    ("ARR", eur(sep["arr"]), eur(oct_["arr"]), delta(oct_["arr"], sep["arr"], "pct"), "good", "arr"),
    ("Paying teams", sep["customers"], oct_["customers"], delta(oct_["customers"], sep["customers"], "n"), "good", "customers"),
    ("Net revenue retention (12 mo)", f'{sep["nrr"]}%', f'{oct_["nrr"]}%', delta(oct_["nrr"], sep["nrr"], "pp"), "good", "nrr"),
    ("Demos booked", sep["demos"], oct_["demos"], delta(oct_["demos"], sep["demos"], "n"), "good", "demos"),
    ("Net burn", eur(sep["burn"]), eur(oct_["burn"]), delta(oct_["burn"], sep["burn"], "eur"), "bad", "burn"),
    ("Cash", eur(sep["cash"]), eur(oct_["cash"]), delta(oct_["cash"], sep["cash"], "eur"), "bad", "cash"),
    ("Runway", f'{sep["runway"]} months', f'{oct_["runway"]} months', delta(oct_["runway"], sep["runway"], "n"), "bad", "runway"),
]

kpi_html = "".join(
    f'<tr><td>{esc(n)}</td><td class="num muted">{esc(a)}</td><td class="num strong">{esc(b)}</td>'
    f'<td class="num {"up" if tone == "good" else "down"}">{"▲" if tone == "good" else "▼"} {esc(d)}</td>'
    f'<td>{src(ref_oct[k])}</td></tr>'
    for n, a, b, d, tone, k in kpi_rows)

proj_table = "".join(
    f'<tr><td>{MONTHS[m]}</td><td class="num">{eur(rv)}</td><td class="num">{eur(ex)}</td><td class="num">{eur(c)}</td></tr>'
    for m, rv, ex, c in PROJ if m in (0, 3, 6, 9, 12, BE_MONTH))

customers_html = f"""
<tr><td><strong>Noorderlicht Zorggroep</strong></td><td>Healthcare. First healthcare customer.</td><td>Paid pilot, 9 clinics</td><td class="num">+{eur(41000)}</td><td>{src("hs-deal-1160")}</td></tr>
<tr><td><strong>Van Dijk Advocaten</strong> and <strong>Contactpunt BV</strong></td><td>Law firm and contact centre</td><td>Annual Growth contracts, up from Pro</td><td class="num">+{eur(19000)}<br><span class="muted small">combined</span></td><td>{src("hs-deal-1142")}</td></tr>
<tr><td><strong>Brugman Verzekeringen</strong></td><td>Insurance</td><td>Annual Growth contract</td><td class="num">+{eur(8000)}</td><td>{src("hs-deal-1178")}</td></tr>
<tr class="lost"><td><strong>Helder Notarissen</strong> (lost)</td><td>Notary practice</td><td>Acquired by a firm on another vendor</td><td class="num">{eur(churned)}</td><td>{src("hs-churn-0231")}</td></tr>
"""

alive_word = "Default alive" if ALIVE else "Default dead"
alive_cls = "alive" if ALIVE else "dead"
alive_icon = "✓" if ALIVE else "✕"

page = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Reson8 investor update, October 2026</title>
<style>
@page {{ size: A4; margin: 14mm 14mm 16mm; }}
:root {{ --ink:{INK}; --ink-2:{INK2}; --muted:{MUTED}; --rule:{GRID}; --wash:#f6f8fa; --accent:#1a56db;
        --good:#047857; --bad:#b91c1c; --flag:#b45309; --flag-bg:#fef3c7;
        --sans:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;
        --mono:ui-monospace,"SF Mono",Menlo,Consolas,monospace; }}
* {{ box-sizing:border-box; margin:0; padding:0; }}
body {{ font-family:var(--sans); color:var(--ink); background:#eef1f4; line-height:1.5; font-size:14px; }}
main {{ max-width:780px; margin:28px auto; background:#fff; padding:44px 50px 36px; border-radius:10px; }}
@media print {{ body {{ background:#fff; }} main {{ margin:0; padding:0; max-width:none; border-radius:0; }} }}
.demo {{ background:var(--flag-bg); border-left:4px solid var(--flag); padding:9px 13px; font-size:12.5px; color:#78350f; margin-bottom:26px; }}
header .eyebrow {{ font-size:12px; font-weight:700; letter-spacing:.14em; text-transform:uppercase; color:var(--accent); }}
header h1 {{ font-size:30px; line-height:1.15; letter-spacing:-.02em; margin:6px 0 4px; }}
header p {{ color:var(--muted); font-size:13px; }}
h2 {{ font-size:13px; font-weight:750; letter-spacing:.12em; text-transform:uppercase; color:var(--ink-2);
     border-bottom:2px solid var(--rule); padding-bottom:6px; margin:30px 0 12px; break-after:avoid; }}
h3 {{ font-size:15px; margin:14px 0 6px; }}
section {{ break-inside:avoid-page; }}
p + p {{ margin-top:8px; }}
ul {{ padding-left:18px; }} li {{ margin:5px 0; }}
.tldr {{ background:var(--wash); border-radius:8px; padding:14px 18px; margin-top:22px; }}
.tldr li {{ margin:4px 0; }}
.ask {{ border:2px solid var(--accent); border-radius:8px; padding:12px 16px; }}
table {{ width:100%; border-collapse:collapse; font-size:13px; }}
th {{ text-align:left; font-size:11px; letter-spacing:.08em; text-transform:uppercase; color:var(--muted); font-weight:700;
     border-bottom:2px solid var(--rule); padding:6px 8px; }}
td {{ border-bottom:1px solid var(--rule); padding:7px 8px; vertical-align:top; }}
.num {{ text-align:right; font-family:var(--mono); white-space:nowrap; }}
th.num {{ font-family:var(--sans); }}
.strong {{ font-weight:700; }} .muted {{ color:var(--muted); }} .small {{ font-size:11px; }}
.up {{ color:var(--good); }} .down {{ color:var(--bad); }}
tr.lost td {{ color:var(--ink-2); background:#fef2f2; }}
.src {{ display:inline-block; font-family:var(--mono); font-size:10.5px; color:var(--accent); background:#eff6ff;
       border-radius:4px; padding:0 5px; margin:1px 3px 1px 0; text-decoration:none; white-space:nowrap; }}
.verdict {{ display:flex; gap:16px; align-items:center; border-radius:10px; padding:14px 18px; margin-bottom:12px; }}
.verdict.alive {{ background:#ecfdf5; border:2px solid #0ca30c; }}
.verdict.dead {{ background:#fef2f2; border:2px solid #d03b3b; }}
.verdict .big {{ font-size:24px; font-weight:800; letter-spacing:-.01em; white-space:nowrap; }}
.verdict.alive .big {{ color:var(--good); }} .verdict.dead .big {{ color:var(--bad); }}
.verdict p {{ font-size:13.5px; color:var(--ink-2); }}
figure {{ margin:10px 0 4px; break-inside:avoid; }}
figcaption {{ font-size:12.5px; font-weight:650; color:var(--ink-2); margin-bottom:4px; }}
.note {{ font-size:12px; color:var(--muted); margin-top:4px; }}
.legend {{ display:flex; gap:16px; font-size:12px; color:var(--ink-2); margin:2px 0 4px; }}
.legend i {{ display:inline-block; width:14px; height:3px; vertical-align:middle; margin-right:6px; border-radius:2px; }}
.challenge {{ border-left:3px solid var(--bad); padding:2px 0 2px 12px; margin:12px 0; }}
.challenge .fix {{ color:var(--good); }}
.flagged {{ background:var(--flag-bg); border-left:4px solid var(--flag); padding:10px 14px; border-radius:0 6px 6px 0; }}
.two {{ display:grid; grid-template-columns:1fr 330px; gap:22px; align-items:start; }}
.sources td {{ font-size:12px; }}
.sources td:first-child {{ font-family:var(--mono); white-space:nowrap; }}
footer {{ margin-top:30px; font-size:11.5px; color:var(--muted); border-top:1px solid var(--rule); padding-top:10px; }}
</style>
</head>
<body>
<main>

<div class="demo"><strong>Demo report.</strong> Generated by Investor Update Agent from the Reson8 demo data.
Revenue, burn, cash, customers, deals and meeting notes are invented for a hackathon demo and are not
Reson8's real figures. The SDK download counts are real public data.</div>

<header>
  <div class="eyebrow">Reson8 · Investor update</div>
  <h1>October 2026</h1>
  <p>From Thomas (CEO) · Month closed 31 October 2026 · Every figure links to the record it came from (list at the end).</p>
</header>

<section class="tldr">
  <strong>In short</strong>
  <ul>
    <li>ARR reached <strong>{eur(oct_["arr"])}</strong>, up {GROWTH * 100:.1f}% on September, and we signed our first healthcare customer: a paid pilot with Noorderlicht Zorggroep across 9 clinics. {src("stripe-oct-close", "hs-deal-1160")}</li>
    <li><strong>{alive_word}.</strong> If ARR keeps growing at October's rate, revenue covers costs in {MONTHS[BE_MONTH]} with {eur(CASH_LEFT)} still in the bank. Below {MIN_G * 100:.1f}% a month we would be default dead.</li>
    <li>Lowlights: burn rose {eur(oct_["burn"] - sep["burn"])} after two speech engineers joined, runway fell from {sep["runway"]} to {oct_["runway"]} months, one customer churned, and demo bookings dropped for a week while our ad account was suspended. That is fixed.</li>
  </ul>
</section>

<section>
  <h2>Ask</h2>
  <div class="ask"><strong>Referrals for a senior speech scientist.</strong> We are interviewing, and our second candidate has a strong background
  in low-resource languages, but the pipeline for this role is thin. An intro to anyone strong in speech recognition for
  European languages would help most. {src("jamie-mtg-1019")}</div>
</section>

<section>
  <h2>Key numbers</h2>
  <table>
    <thead><tr><th>Metric</th><th class="num">September</th><th class="num">October</th><th class="num">Change</th><th>Source</th></tr></thead>
    <tbody>{kpi_html}</tbody>
  </table>
  <p class="note">Net revenue retention is new in this update. Our lead investor asked for it on our 3 October call. {src("jamie-mtg-1003")}
  ▲ and ▼ mark the direction that is good or bad for the business, not just up or down.</p>
</section>

<section>
  <h2>Default alive or default dead?</h2>
  <div class="verdict {alive_cls}">
    <div class="big">{alive_icon} {alive_word}</div>
    <p>Paul Graham's test: if costs stay flat and revenue keeps growing at this month's rate, do we reach profitability before
    the cash runs out? At {GROWTH * 100:.1f}% monthly growth, yes: break-even in {MONTHS[BE_MONTH]} ({BE_MONTH} months) with
    {eur(CASH_LEFT)} left. {src("stripe-oct-close", ref_sep["arr"])}</p>
  </div>
  <figure>
    <figcaption>Monthly revenue against monthly expenses</figcaption>
    <div class="legend"><span><i style="background:{BLUE}"></i>Revenue (ARR ÷ 12)</span><span><i style="background:{ORANGE}"></i>Expenses (net burn + revenue), held flat</span></div>
    {chart_projection()}
  </figure>
  <figure>
    <figcaption>Cash in the bank</figcaption>
    {chart_cash()}
  </figure>
  <figure>
    <figcaption>Dead or alive map: where October puts us, and how far we are from the edge</figcaption>
    {chart_map()}
    <p class="note">Each point is a steady monthly growth rate and a monthly net burn, starting from October's ARR and
    {eur(oct_["cash"])} cash. Left of the line, the cash runs out first. At today's burn the edge is {MIN_G * 100:.1f}% a month,
    so growth can roughly halve before we are default dead. At today's growth, net burn could rise to about
    {eur(round(MAX_BURN, -3))} a month before it flips.</p>
  </figure>
  <table style="margin-top:10px">
    <thead><tr><th>Month</th><th class="num">Revenue / mo</th><th class="num">Expenses / mo</th><th class="num">Cash</th></tr></thead>
    <tbody>{proj_table}</tbody>
  </table>
  <p class="note">This is a projection, not a forecast. It assumes October's growth holds and costs stay flat, which a
  hiring plan would change. The figures are computed in code from the confirmed facts, the same way the app does it.</p>
</section>

<section>
  <h2>Customers</h2>
  <p>Four new paying teams and one loss: net +{oct_["customers"] - sep["customers"]}, to {oct_["customers"]} paying teams. {src("hs-oct-close")}</p>
  <table style="margin-top:10px">
    <thead><tr><th>Customer</th><th>Who</th><th>Deal</th><th class="num">ARR</th><th>Source</th></tr></thead>
    <tbody>{customers_html}</tbody>
  </table>
  <figure style="margin-top:16px">
    <figcaption>How ARR got from September to October</figcaption>
    {chart_bridge(bridge_rows())}
  </figure>
  <p class="note">Noorderlicht's procurement team told us zero audio retention, EU-only processing and our ISO 27001
  certificate were what cleared their review. {src("hs-deal-1160", "jamie-mtg-1012")}</p>
</section>

<section>
  <h2>Pipeline we are not counting yet</h2>
  <div class="flagged"><strong>Noorderlicht wants all 14 clinics in Q1.</strong> Their clinical lead said this at the pilot
  review on 27 October, and clinicians report dictation is noticeably faster than their previous vendor on Dutch medical
  vocabulary. Nothing is signed and there is no written confirmation, so it is not in any number above. Procurement
  will revisit in December. {src("jamie-mtg-1027")}</div>
</section>

<section>
  <h2>Challenges</h2>
  <div class="challenge"><strong>Burn up {eur(oct_["burn"] - sep["burn"])} to {eur(oct_["burn"])}, runway down to {oct_["runway"]} months.</strong>
  Two speech engineers started on 5 October. Runway fell four months, from {sep["runway"]} to {oct_["runway"]}, at the new burn. {src("stripe-oct-close")}</div>
  <div class="challenge"><strong>Demo bookings fell from 41 to 11 in week 42.</strong> Our LinkedIn ad account was suspended on
  14 October because the company card on file had expired, and posting paused while Mirte was out sick for two days.
  <span class="fix">Fixed: the card is replaced, a backup payment method is on file, and ads have been delivering since
  21 October. Week 43 was back to 34.</span> {src("li-wk42", "li-wk43")}</div>
  <div class="challenge"><strong>We lost Helder Notarissen ({eur(churned)} ARR).</strong> They merged into a larger firm that
  had already standardised on another vendor. {src("hs-churn-0231")}</div>
  <div class="challenge"><strong>Hiring a senior speech scientist is slow.</strong> The candidate pipeline is thin. That is
  this month's ask. {src("jamie-mtg-1019")}</div>
</section>

<section>
  <h2>Product</h2>
  <ul>
    <li><strong>Frisian and Swedish are generally available</strong> (v1.8), taking the API to 10 European languages, with
    mid-conversation language switching across all of them. {src("gh-rel-1.8")}</li>
    <li><strong>Realtime latency down 38%</strong>: p95 from 410ms to 254ms on the EU cluster, after a streaming decoder rewrite. {src("gh-pr-349")}</li>
    <li><strong>Barge-in tuning for the Turns API</strong>: voice agents stop within 180ms (median) when a caller interrupts. {src("gh-pr-318")}</li>
    <li><strong>Diarization v2</strong> (v1.9) detects the number of speakers on its own and handles overlapping speech, at the same price. {src("gh-rel-1.9")}</li>
  </ul>
</section>

<section>
  <h2>Growth</h2>
  <div class="two">
    <ul style="margin-top:0">
      <li><strong>{oct_["demos"]} demos booked</strong>, up from {sep["demos"]}. The "Hear every word" campaign launched on 1 October for healthcare and legal teams in NL and DE. {src("hs-oct-close", "li-wk40")}</li>
      <li>Our <strong>word error rate benchmark</strong> on Dutch medical dictation reached 47,000 impressions and drove a record 41 demos in one week. {src("li-wk41")}</li>
      <li><strong>Free to Pro conversion rose to 6.4%</strong>, from 5.1% in September. {src("stripe-plg-oct")}</li>
      <li><strong>SDK downloads: {pk["total"]:,} in 1 to 23 October</strong>, already past September's {pk["sep_total"]:,}
      (PyPI {pk["pypi"]:,}, npm {pk["npm"]:,}). These include CI installs, so they track developer adoption rather than users.
      Real public data. {src("pkg-oct-23")}</li>
    </ul>
    <figure style="margin:0">
      <figcaption>Demos booked per week</figcaption>
      {chart_demos()}
    </figure>
  </div>
</section>

<section>
  <h2>Team</h2>
  <ul>
    <li>Two speech engineers joined on 5 October. {src("stripe-oct-close")}</li>
    <li>Jarno is running interviews for a senior speech scientist. The second candidate goes to a second round. {src("jamie-mtg-1019")}</li>
  </ul>
</section>

<section>
  <h2>Next month</h2>
  <ul>
    <li>Close the senior speech scientist search, or widen it with your referrals.</li>
    <li>Prepare for Noorderlicht's procurement review in December, where the 14-clinic rollout gets decided.</li>
    <li>Keep net revenue retention in every update from now on.</li>
  </ul>
</section>

<section>
  <h2>Sources</h2>
  <table class="sources">
    <thead><tr><th>Record</th><th>Date</th><th>What it is</th></tr></thead>
    <tbody>
    <tr id="{esc(ref_sep["arr"])}"><td>{esc(ref_sep["arr"])}</td><td>2026-09-30</td><td>September close, carried over from the September update</td></tr>
    {"".join(f'<tr id="{esc(i)}"><td>{esc(i)}</td><td>{esc(it["ts"][:10])}</td><td>{esc(it["title"].split(" (")[0] if i.startswith("jamie") else it["title"])}</td></tr>'
             for i, it in sorted({**stripe, **hubspot, **jamie, **linkedin, **github, **packages}.items(), key=lambda kv: kv[1]["ts"]))}
    </tbody>
  </table>
</section>

<footer>Generated by Investor Update Agent from facts the founder confirmed. Figures, charts and the default alive test are
computed in code from those facts. Commentary is written by the agent and checked by a second pass against the same facts.
Demo data: see the note at the top.</footer>

</main>
</body>
</html>
"""

out = HERE / "october-2026.html"
out.write_text(page, encoding="utf-8")
print(f"wrote {out}")
print(f"default alive: {ALIVE}, break-even month {BE_MONTH} ({MONTHS[BE_MONTH]}), cash left {eur(CASH_LEFT)}, edge {MIN_G * 100:.2f}%")

#!/usr/bin/env python3
"""Hand-authored architecture diagrams for images/prompts/01..10.

Text stays text: every label is an SVG <text> element, so nothing is ever
misspelled by a raster generator. One shared design system across all ten so
they read as a single set.

    python3 images/diagrams/render.py          # SVG + PNG
    python3 images/diagrams/render.py --svg    # SVG only (no Chrome needed)

PNG rendering shells out to headless Chrome at 2x device scale.
"""
from __future__ import annotations

import argparse
import html
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

OUT = Path(__file__).resolve().parent
W, H = 1600, 900

# ---------------------------------------------------------------- palette --
INK = "#0f1e3d"        # titles
BODY = "#1f2a44"       # node titles
MUTED = "#6b7280"      # sub-labels
FAINT = "#9aa3b2"      # captions
LINE = "#c9d1dc"       # connectors / borders
BG = "#ffffff"
PANEL = "#f6f8fb"

AWS = "#ec7211"
AWS_T = "#fdf0e4"      # tint
AZURE = "#0078d4"
AZURE_T = "#e8f2fc"
GCP = "#1a8b4c"
GCP_T = "#e8f5ee"
DBX = "#ff3621"
DBX_T = "#fdecea"
SNOW = "#29b5e8"
SNOW_T = "#e6f6fd"
GOV = "#7c3aed"        # governance accent
GOV_T = "#f1ecfe"
GREEN = "#16a34a"      # locked
AMBER = "#d97706"      # unlocked / public
RED = "#dc2626"

FONT = "Helvetica Neue, Helvetica, Arial, sans-serif"


def esc(s: str) -> str:
    return html.escape(str(s), quote=False)


# ------------------------------------------------------------- primitives --
def text(x, y, s, size=13, fill=BODY, weight="normal", anchor="middle", spacing=0):
    ls = f' letter-spacing="{spacing}"' if spacing else ""
    return (
        f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" '
        f'font-weight="{weight}" fill="{fill}" text-anchor="{anchor}"{ls}>{esc(s)}</text>'
    )


def lines(x, y, rows, size=11, fill=MUTED, weight="normal", anchor="middle", lh=14):
    return "".join(
        text(x, y + i * lh, r, size=size, fill=fill, weight=weight, anchor=anchor)
        for i, r in enumerate(rows)
    )


def node(x, y, w, h, title, sub=(), color=LINE, fill=BG, tsize=14, stroke=2):
    """Rounded card. `sub` is a tuple of sub-label rows."""
    sub = tuple(sub)
    block = 18 + 14 * len(sub)
    ty = y + (h - block) / 2 + 14
    out = (
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{fill}" '
        f'stroke="{color}" stroke-width="{stroke}" filter="url(#soft)"/>'
    )
    out += text(x + w / 2, ty, title, size=tsize, fill=BODY, weight="bold")
    if sub:
        out += lines(x + w / 2, ty + 18, sub)
    return out


def band(x, y, w, h, label=None, color=LINE, fill=PANEL, dash=None, lsize=12):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    out = (
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="{fill}" '
        f'stroke="{color}" stroke-width="1.5" opacity="0.95"{d}/>'
    )
    if label:
        out += text(x + 16, y + 22, label, size=lsize, fill=color, weight="bold", anchor="start")
    return out


def arrow(x1, y1, x2, y2, color="#6b7280", width=2, dash=None, marker="arrow"):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return (
        f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" '
        f'stroke-width="{width}"{d} marker-end="url(#{marker})"/>'
    )


def elbow(x1, y1, x2, y2, color="#6b7280", width=2, marker="arrow"):
    """Horizontal-then-vertical-then-horizontal connector."""
    mx = (x1 + x2) / 2
    return (
        f'<path d="M {x1} {y1} H {mx} V {y2} H {x2}" fill="none" stroke="{color}" '
        f'stroke-width="{width}" marker-end="url(#{marker})"/>'
    )


def padlock(x, y, locked=True, color=None, halo=True, r=11):
    """Small padlock centred on (x, y). Green = private, amber = open/public."""
    c = color or (GREEN if locked else AMBER)
    out = f'<circle cx="{x}" cy="{y}" r="{r}" fill="{BG}"/>' if halo else ""
    if locked:
        shackle = f'M {x-4} {y-2} v-3.2 a4 4 0 0 1 8 0 v3.2'
    else:
        shackle = f'M {x-4} {y-2} v-3.2 a4 4 0 0 1 8 0'
    out += f'<path d="{shackle}" fill="none" stroke="{c}" stroke-width="1.9"/>'
    out += f'<rect x="{x-6.5}" y="{y-2}" width="13" height="10" rx="2" fill="{c}"/>'
    return out


CLOUD = ("M -22 10 C -34 10 -34 -6 -21 -7 C -20 -21 0 -25 6 -13 "
         "C 15 -21 30 -12 24 1 C 31 3 30 10 23 10 Z")


def internet(x, y, s=1.0):
    """Public-internet cloud glyph — deliberately absent from every private diagram."""
    return (
        f'<g transform="translate({x},{y}) scale({s})">'
        f'<path d="{CLOUD}" fill="#eef2f7" stroke="{AMBER}" stroke-width="1.8" '
        f'stroke-linejoin="round"/>'
        f'</g>'
    )


def tunnel(x, y, w, label, color=GCP, h=26):
    """Padlocked pipe — the visual signature of a cross-cloud IPsec hop."""
    out = (
        f'<rect x="{x}" y="{y-h/2}" width="{w}" height="{h}" rx="{h/2}" fill="{color}" opacity="0.16"/>'
        f'<rect x="{x}" y="{y-h/2}" width="{w}" height="{h}" rx="{h/2}" fill="none" '
        f'stroke="{color}" stroke-width="2"/>'
        f'<ellipse cx="{x+w}" cy="{y}" rx="4.5" ry="{h/2}" fill="none" stroke="{color}" '
        f'stroke-width="2" opacity="0.65"/>'
    )
    out += padlock(x + w / 2, y - 1, halo=False)
    out += text(x + w / 2, y + h / 2 + 17, label, size=11, fill=color, weight="bold")
    return out


def cylinder(x, y, w, h, color, fill):
    ry = 7
    return (
        f'<path d="M {x} {y+ry} a {w/2} {ry} 0 0 1 {w} 0 v {h-2*ry} a {w/2} {ry} 0 0 1 {-w} 0 Z" '
        f'fill="{fill}" stroke="{color}" stroke-width="2"/>'
        f'<path d="M {x} {y+ry} a {w/2} {ry} 0 0 0 {w} 0" fill="none" stroke="{color}" stroke-width="2"/>'
    )


def db(x, y, w, h, title, sub=(), color=AWS, fill=BG, locked=None):
    """Database node: cylinder cap + card."""
    out = node(x, y, w, h, title, sub, color=color, fill=fill)
    out += cylinder(x + 14, y + 12, 26, 22, color, fill)
    if locked is not None:
        out += padlock(x + w - 18, y + 20, locked=locked, halo=False)
    return out


def tag(x, y, s, color=MUTED, fill="#eef1f6", size=10, pad=9):
    w = len(s) * 5.6 + pad * 2
    return (
        f'<rect x="{x-w/2}" y="{y-9}" width="{w}" height="18" rx="9" fill="{fill}"/>'
        + text(x, y + 3.5, s, size=size, fill=color, weight="bold")
    )


def alabel(x, y, rows, size=10.5, fill=MUTED, lh=13):
    """Label floating above a connector."""
    rows = rows if isinstance(rows, (list, tuple)) else [rows]
    return lines(x, y, rows, size=size, fill=fill, lh=lh)


def banner(y, s, color=INK, fill="#eef2f8", w=1360, size=12.5, h=32):
    x = (W - w) / 2
    return (
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{h/2}" fill="{fill}"/>'
        + text(W / 2, y + h / 2 + 4.5, s, size=size, fill=color, weight="bold")
    )


def footer(s, color="#ffffff", fill=INK, w=1180, y=846, size=12.5):
    x = (W - w) / 2
    return (
        f'<rect x="{x}" y="{y}" width="{w}" height="34" rx="17" fill="{fill}"/>'
        + text(W / 2, y + 22, s, size=size, fill=color, weight="bold")
    )


def title(s, sub=None):
    out = text(W / 2, 56, s, size=33, fill=INK, weight="bold", spacing="-0.4")
    if sub:
        out += text(W / 2, 82, sub, size=13.5, fill=FAINT)
    return out


def boundary(x, y1, y2, label="cloud boundary"):
    return (
        f'<line x1="{x}" y1="{y1}" x2="{x}" y2="{y2}" stroke="{FAINT}" stroke-width="1.6" '
        f'stroke-dasharray="7 6"/>'
        + text(x, y1 - 8, label, size=11, fill=FAINT, weight="bold")
    )


def doc(x, y, w, h, title_, sub=(), color=GOV, fill=GOV_T):
    """Document icon with a folded corner."""
    f = 18
    out = (
        f'<path d="M {x} {y+8} q0-8 8-8 h {w-f-8} l {f} {f} v {h-f-8} q0 8 -8 8 h {-(w-8)} '
        f'q-8 0 -8 -8 Z" fill="{fill}" stroke="{color}" stroke-width="2"/>'
        f'<path d="M {x+w-f} {y} v {f} h {f}" fill="none" stroke="{color}" stroke-width="2"/>'
    )
    out += text(x + w / 2, y + 40, title_, size=14, fill=BODY, weight="bold")
    out += lines(x + w / 2, y + 58, sub)
    return out


def svg(body: str) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs>
  <!-- context-stroke: every arrowhead inherits the colour of its own line, so a
       red line can never end in a grey head. The ids are kept as aliases. -->
  <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
    <path d="M 0 1 L 9 5 L 0 9 z" fill="context-stroke"/>
  </marker>
  <marker id="arrowg" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
    <path d="M 0 1 L 9 5 L 0 9 z" fill="context-stroke"/>
  </marker>
  <marker id="arrowa" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
    <path d="M 0 1 L 9 5 L 0 9 z" fill="context-stroke"/>
  </marker>
  <marker id="arrowv" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
    <path d="M 0 1 L 9 5 L 0 9 z" fill="context-stroke"/>
  </marker>
  <marker id="arrowr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
    <path d="M 0 1 L 9 5 L 0 9 z" fill="context-stroke"/>
  </marker>
  <filter id="soft" x="-8%" y="-14%" width="116%" height="132%">
    <feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#0f1e3d" flood-opacity="0.07"/>
  </filter>
</defs>
<rect width="{W}" height="{H}" fill="{BG}"/>
<rect x="0" y="0" width="{W}" height="6" fill="{INK}"/>
{body}
</svg>
"""


# ------------------------------------------------------------------ 01 ------
def fig01():
    b = title("AWS — Public Connectivity", "Lakehouse Federation straight to the database's public endpoint")
    b += banner(112, "One JSON contract  →  grants enforced in Unity Catalog")

    y = 430
    b += node(80, y - 90, 260, 180, "Databricks Serverless", ("Workspace", "", "Unity Catalog ·", "Lakehouse Federation"), color=DBX, fill=DBX_T, tsize=16)

    b += alabel(530, y - 118, ["TLS 5432 · public endpoint", "sslmode=require"], fill=AMBER, size=12)
    b += arrow(350, y, 478, y, color=AMBER, marker="arrowa")
    b += internet(530, y, 1.25)
    b += arrow(582, y, 686, y, color=AMBER, marker="arrowa")
    b += padlock(530, y + 60, locked=False)
    b += text(530, y + 92, "the public internet", size=11, fill=AMBER, weight="bold")

    b += band(700, 240, 820, 400, "Customer VPC · 10.40.0.0/16", color=AWS, fill=AWS_T)
    b += node(726, y - 65, 170, 130, "Internet", ("Gateway",), color=AWS, fill=BG)
    b += arrow(902, y, 956, y, color=AWS)
    b += db(966, y - 85, 330, 170, "Amazon RDS for PostgreSQL", ("sales-db-instance", "", "publicly_accessible = true"), color=AWS, fill=BG, locked=False)
    b += tag(1131, y + 118, "schemas: crm (PII) · orders", color=AWS, fill="#fbe3cc")

    b += text(1131, y + 168, "No load balancer. No proxy. No PrivateLink.", size=11.5, fill=MUTED, weight="bold")
    b += text(1131, y + 186, "This is the SIMPLE case — that is the whole point.", size=11.5, fill=MUTED)

    b += footer("Simple, fast, enough for dev — but the bytes travel the public network. That is why private mode exists.")
    return b


# ------------------------------------------------------------------ 02 ------
def fig02():
    b = title("AWS — Private Connectivity (PrivateLink)", "Five hops, all private — no Internet Gateway anywhere in the picture")
    b += banner(112, "Every hop private  —  Databricks never leaves the AWS backbone", fill="#e7f6ec", color="#14532d")

    y = 430
    b += node(52, y - 62, 190, 124, "Databricks", ("Serverless Workspace", "Unity Catalog · bound to NCC"), color=DBX, fill=DBX_T)
    b += alabel(286, y - 96, ["NCC private", "endpoint rule"], fill=GREEN, size=10.5)
    b += arrow(250, y, 322, y, color=GREEN, marker="arrowg")
    b += padlock(286, y)
    b += text(286, y + 88, "postgres.db.internal", size=10.5, fill=MUTED, weight="bold")

    b += node(330, y - 62, 190, 124, "AWS PrivateLink", ("VPC Endpoint Service", "allow-list: Databricks", "serverless role only"), color=GOV, fill=GOV_T)
    b += arrow(528, y, 592, y, color=GREEN, marker="arrowg")
    b += padlock(560, y)

    b += band(600, 250, 950, 450, "Customer VPC · 10.40.0.0/16 · private subnets · NO Internet Gateway", color=AWS, fill=AWS_T)

    xs = [618, 800, 982]
    labs = [
        ("Internal NLB", ("TCP 5432",)),
        ("ECS Fargate", ("pgbouncer gateway",)),
        ("Amazon RDS Proxy", ("require_tls = true",)),
    ]
    for x, (t, s) in zip(xs, labs):
        b += node(x, y - 58, 162, 116, t, s, color=AWS, fill=BG)
    for x in (780, 962):
        b += arrow(x, y, x + 20, y, color=GREEN, marker="arrowg")
        b += padlock(x + 10, y)
    b += arrow(1144, y, 1176, y, color=GREEN, marker="arrowg")
    b += padlock(1160, y)

    b += db(1190, y - 78, 336, 156, "Amazon RDS for PostgreSQL", ("sales-db-instance", "", "publicly_accessible = FALSE"), color=AWS, fill=BG, locked=True)
    b += text(1358, y + 102, "security group admits 5432 only from the gateway", size=10.5, fill=MUTED)

    b += node(690, 570, 440, 96, "VPC Interface / Gateway Endpoints", ("Secrets Manager · ECR · CloudWatch Logs · S3",), color=MUTED, fill=BG)
    b += arrow(881, y + 60, 881, 566, color=LINE, dash="4 4")
    b += text(1310, 604, "…so the gateway needs no internet", size=11, fill=MUTED, weight="bold")
    b += text(1310, 622, "to pull its image or read its secrets.", size=11, fill=MUTED)

    b += footer("PrivateLink allow-list = exactly one principal:  arn:aws:iam::565502421330:role/private-connectivity-role-eu-central-1")
    return b


# ------------------------------------------------------------------ 03 ------
def fig03():
    b = title("Same goal, one switch", "PRIVATE_AWS = false  |  true   —   same source, same destination, same data")

    # PUBLIC
    b += band(80, 140, 1440, 250, None, color=AMBER, fill="#fdf6ec")
    b += padlock(116, 176, locked=False, halo=False)
    b += text(136, 181, "PUBLIC   ·   PRIVATE_AWS = false", size=15, fill=AMBER, weight="bold", anchor="start")
    b += text(1490, 181, "2 nodes · 1 hop", size=11.5, fill=AMBER, weight="bold", anchor="end")

    b += node(180, 232, 240, 116, "Databricks Serverless", ("Unity Catalog · Federation",), color=DBX, fill=BG)
    b += arrow(430, 290, 600, 290, color=AMBER, marker="arrowa")
    b += internet(660, 290, 1.1)
    b += arrow(715, 290, 900, 290, color=AMBER, marker="arrowa")
    b += alabel(665, 246, ["TLS 5432 · public endpoint"], fill=AMBER, size=11.5)
    b += db(915, 224, 320, 132, "Amazon RDS PostgreSQL", ("publicly_accessible = true",), color=AWS, fill=BG, locked=False)

    # PRIVATE
    b += band(80, 430, 1440, 330, None, color=GREEN, fill="#f1faf4")
    b += padlock(116, 466, halo=False)
    b += text(136, 471, "PRIVATE   ·   PRIVATE_AWS = true", size=15, fill=GREEN, weight="bold", anchor="start")
    b += text(1490, 471, "6 nodes · 0 public hops", size=11.5, fill=GREEN, weight="bold", anchor="end")

    b += node(104, 552, 178, 104, "Databricks", ("Serverless · NCC",), color=DBX, fill=BG, tsize=13)
    b += arrow(288, 604, 316, 604, color=GREEN, marker="arrowg")

    b += band(322, 500, 1180, 210, "Customer VPC · private subnets · no Internet Gateway", color=AWS, fill=AWS_T)
    px = [340, 570, 800, 1030]
    plabs = [
        ("AWS PrivateLink", ("VPC Endpoint Service",)),
        ("Internal NLB", ("TCP 5432",)),
        ("ECS Fargate", ("pgbouncer",)),
        ("RDS Proxy", ("require_tls",)),
    ]
    for x, (t, s) in zip(px, plabs):
        b += node(x, 552, 198, 104, t, s, color=AWS, fill=BG, tsize=13)
    for x in (538, 768, 998):
        b += arrow(x, 604, x + 32, 604, color=GREEN, marker="arrowg")
        b += padlock(x + 16, 604)
    b += arrow(1228, 604, 1258, 604, color=GREEN, marker="arrowg")
    b += padlock(1243, 604)
    b += db(1264, 540, 226, 128, "RDS PostgreSQL", ("publicly_accessible = FALSE",), color=AWS, fill=BG, locked=True)

    b += footer("I did not rewrite the platform. I flipped one flag.", w=760)
    return b


# ------------------------------------------------------------------ 04 ------
def fig04():
    b = title("One Gold Layer, Two Engines, Zero Copies", "The data is written once and read in place — no ingestion, no second copy, no divergence")
    b += banner(112, "One JSON governance contract  →  enforced in BOTH Unity Catalog and Snowflake", fill=GOV_T, color="#4c1d95")

    b += node(70, 340, 300, 170, "Databricks", ("Medallion", "bronze → silver → gold"), color=DBX, fill=DBX_T, tsize=17)
    b += node(1230, 340, 300, 170, "Snowflake", ("EXTERNAL TABLE", "demo.executive_cross_cloud"), color=SNOW, fill=SNOW_T, tsize=17)

    # centre: the single S3 object
    b += band(620, 285, 360, 285, None, color=AWS, fill=AWS_T)
    b += text(800, 320, "Amazon S3", size=17, fill=AWS, weight="bold")
    b += text(800, 342, "sales/gold-zone/", size=12.5, fill=MUTED)
    b += node(660, 366, 280, 106, "executive_cross_cloud", (".parquet — the one source of truth",), color=AWS, fill=BG, tsize=15)
    b += tag(800, 510, "external location  =  stage  =  loc_sales_gold", color=AWS, fill="#fbe3cc", size=10.5)
    b += text(800, 545, "same name, same S3 prefix — both generated from the same contract", size=10, fill=MUTED)

    b += arrow(378, 419, 612, 419, color=DBX, width=2.5)
    b += alabel(495, 380, ["writes once", "external location loc_sales_gold"], fill=DBX, size=11)

    b += arrow(1222, 419, 990, 419, color=SNOW, width=2.5)
    b += alabel(1106, 380, ["reads in place · zero-copy", "STAGE loc_sales_gold"], fill=SNOW, size=11)

    b += node(1120, 600, 400, 76, "SELECT metadata$filename", ("→ resolves to the exact same S3 key",), color=SNOW, fill=BG, tsize=13)
    b += arrow(1320, 596, 1320, 520, color=SNOW, dash="4 4", marker="arrowa")

    b += node(80, 600, 400, 76, "sales_aws.gold.executive_cross_cloud", ("the Databricks-side name of the same object",), color=DBX, fill=BG, tsize=13)

    b += footer("Same file. Two engines. Zero copies.", w=520)
    return b


# ------------------------------------------------------------------ 05 ------
def fig05():
    b = title("Why a transit hub", "Databricks serverless runs inside an AWS account — and an NCC rule can only ever create an AWS endpoint")

    b += f'<line x1="800" y1="140" x2="800" y2="810" stroke="{LINE}" stroke-width="1.5"/>'

    # LEFT — the wall
    b += text(400, 170, "What Databricks can do", size=19, fill=INK, weight="bold")
    b += node(80, 350, 210, 130, "Databricks", ("Serverless", "(AWS account)"), color=DBX, fill=DBX_T, tsize=16)

    b += arrow(300, 300, 520, 300, color=GREEN, width=2.5, marker="arrowg")
    b += text(410, 288, "NCC private endpoint rule", size=11, fill=GREEN, weight="bold")
    b += node(530, 262, 180, 76, "AWS resource", (), color=GREEN, fill="#f1faf4", tsize=15)
    b += text(720, 307, "✓", size=24, fill=GREEN, weight="bold", anchor="start")

    for i, (svc, yy) in enumerate((("Azure resource", 420), ("GCP resource", 530))):
        b += arrow(300, yy, 462, yy, color=RED, width=2.5, marker="arrowr")
        b += f'<rect x="482" y="{yy-48}" width="12" height="96" rx="3" fill="#d8dce3"/>'
        b += text(488, yy + 8, "✗", size=23, fill=RED, weight="bold")
        b += node(530, yy - 38, 180, 76, svc, (), color=LINE, fill="#f3f4f6", tsize=15)
    b += text(400, 648, "An NCC rule can only ever create", size=14.5, fill=BODY, weight="bold")
    b += text(400, 672, "an AWS endpoint.", size=14.5, fill=BODY, weight="bold")

    # RIGHT — move the problem
    b += text(1200, 170, "So move the problem", size=19, fill=INK, weight="bold")
    b += node(860, 350, 180, 130, "Databricks", ("Serverless",), color=DBX, fill=DBX_T, tsize=16)
    b += arrow(1048, 415, 1094, 415, color=GREEN, width=2.5, marker="arrowg")

    b += band(1102, 300, 220, 230, None, color=AWS, fill=AWS_T)
    b += text(1212, 332, "AWS transit hub", size=15, fill=AWS, weight="bold")
    for i, s in enumerate(("PrivateLink service", "internal NLB", "Fargate proxy")):
        b += node(1120, 350 + i * 58, 184, 46, s, (), color=AWS, fill=BG, tsize=12, stroke=1.5)

    b += tunnel(1340, 360, 118, "IPsec VPN", color=AZURE)
    b += node(1474, 328, 108, 64, "Azure SQL", (), color=AZURE, fill=AZURE_T, tsize=13)
    b += tunnel(1340, 470, 118, "IPsec VPN", color=GCP)
    b += node(1474, 438, 108, 64, "BigQuery", (), color=GCP, fill=GCP_T, tsize=13)

    b += text(1200, 648, "Databricks reaches AWS.", size=14.5, fill=BODY, weight="bold")
    b += text(1200, 672, "AWS reaches everywhere.", size=14.5, fill=BODY, weight="bold")

    b += footer("The private connection to another cloud is not hard — it does not exist. So I moved the problem to ground where it does.", w=1140)
    return b


# ------------------------------------------------------------------ 06 ------
def fig06():
    b = title("Azure — Private Connectivity via an AWS transit hub")
    b += banner(100, "An NCC rule can only create an AWS endpoint — so the endpoint is in AWS, and the tunnel does the rest.",
                fill="#e7f6ec", color="#14532d")

    y = 430
    b += boundary(1080, 190, 720)

    b += node(52, y - 62, 168, 124, "Databricks", ("Serverless", "runs in AWS · NCC"), color=DBX, fill=DBX_T, tsize=13)
    b += alabel(258, y - 96, ["NCC rule →", "*.database.windows.net"], fill=GREEN, size=9.5)
    b += arrow(228, y, 288, y, color=GREEN, marker="arrowg")
    b += padlock(258, y)

    b += node(296, y - 62, 172, 124, "AWS PrivateLink", ("VPC Endpoint Service", "allow-list: one role"), color=GOV, fill=GOV_T, tsize=13)
    b += arrow(476, y, 528, y, color=GREEN, marker="arrowg")
    b += padlock(502, y)

    b += band(536, 250, 444, 360, "AWS transit VPC · 10.10.0.0/16 · private subnets", color=AWS, fill=AWS_T)
    b += node(556, y - 62, 180, 124, "Internal NLB", (":1433",), color=AWS, fill=BG, tsize=13)
    b += arrow(744, y, 772, y, color=GREEN, marker="arrowg")
    b += padlock(758, y)
    b += node(780, y - 62, 180, 124, "ECS Fargate", ("HAProxy", "TCP passthrough"), color=AWS, fill=BG, tsize=13)
    b += text(758, y + 92, "terminates nothing — the TLS session is", size=10.5, fill=MUTED)
    b += text(758, y + 108, "Databricks ↔ Azure SQL, end to end", size=10.5, fill=MUTED, weight="bold")

    b += arrow(962, y, 986, y, color=GREEN, marker="arrowg")
    b += tunnel(990, y, 180, "IPsec VPN", color=AZURE, h=30)
    b += text(1080, y + 52, "AWS VGW ↔ Azure VPN Gateway", size=10, fill=AZURE, weight="bold")
    b += text(1080, y + 67, "VpnGw1AZ · zone-redundant · Connected", size=10, fill=MUTED)
    b += arrow(1174, y, 1196, y, color=GREEN, marker="arrowg")

    b += band(1200, 250, 348, 360, "Azure VNet", color=AZURE, fill=AZURE_T)
    b += node(1218, y - 62, 148, 124, "Private Endpoint", ("Approved",), color=AZURE, fill=BG, tsize=12)
    b += arrow(1372, y, 1394, y, color=GREEN, marker="arrowg")
    b += padlock(1383, y)
    b += db(1400, y - 70, 132, 140, "Azure SQL", ("publicNetworkAccess", "", "= Disabled"), color=AZURE, fill=BG, locked=True)
    b += tag(1374, y + 122, "schemas: inventory · orders", color=AZURE, fill="#cfe6fa")

    b += node(556, 640, 424, 88, "Route 53 private zone", ("database.windows.net → the private endpoint's IP",), color=MUTED, fill=BG, tsize=12)
    b += arrow(768, 636, 768, 606, color=LINE, dash="4 4")
    b += text(768, 752, "the FQDN resolves to a private address — reachable only across the tunnel", size=10.5, fill=FAINT)

    b += footer("The proxy does not terminate TLS. It forwards bytes it cannot read.", w=640)
    return b


# ------------------------------------------------------------------ 07 ------
def fig07():
    b = title("GCP — Private Connectivity via an AWS transit hub")
    b += banner(100, "BigQuery is a managed API — there is nothing to put a private endpoint in front of. So we reach Google's private VIP.",
                fill="#e7f6ec", color="#14532d")

    y = 400
    b += boundary(1080, 190, 700)

    b += node(52, y - 62, 168, 124, "Databricks", ("Serverless", "runs in AWS · NCC"), color=DBX, fill=DBX_T, tsize=13)
    b += alabel(258, y - 100, ["NCC rule → bigquery ·", "bigquerystorage · oauth2"], fill=GREEN, size=9.5)
    b += arrow(228, y, 288, y, color=GREEN, marker="arrowg")
    b += padlock(258, y)
    b += text(258, y + 88, "all three on one rule", size=10, fill=FAINT)

    b += node(296, y - 62, 172, 124, "AWS PrivateLink", ("VPC Endpoint Service",), color=GOV, fill=GOV_T, tsize=13)
    b += arrow(476, y, 528, y, color=GREEN, marker="arrowg")
    b += padlock(502, y)

    b += band(536, 226, 444, 350, "AWS transit VPC · 10.11.0.0/16", color=AWS, fill=AWS_T)
    b += node(556, y - 62, 180, 124, "Internal NLB", (":443",), color=AWS, fill=BG, tsize=13)
    b += arrow(744, y, 772, y, color=GREEN, marker="arrowg")
    b += padlock(758, y)
    b += node(780, y - 62, 180, 124, "ECS Fargate", ("HAProxy :8443",), color=AWS, fill=BG, tsize=13)
    b += text(758, y + 90, "8443 — an unprivileged container cannot bind below 1024", size=10, fill=MUTED)
    b += text(758, y + 114, "Pure TCP passthrough: TLS is Databricks ↔ Google, end to end.", size=10, fill=MUTED, weight="bold")
    b += text(758, y + 130, "Google's frontend routes on the SNI the client sent — which is why", size=10, fill=MUTED)
    b += text(758, y + 146, "ONE backend can carry all three API hosts.", size=10, fill=MUTED)

    b += arrow(962, y, 986, y, color=GREEN, marker="arrowg")
    b += tunnel(990, y, 180, "IPsec VPN + BGP", color=GCP, h=30)
    b += text(1080, y + 52, "AWS VGW ↔ GCP HA VPN", size=10, fill=GCP, weight="bold")
    b += text(1080, y + 67, "gcp-tunnel-to-aws · ESTABLISHED", size=10, fill=MUTED)
    b += arrow(1174, y, 1196, y, color=GREEN, marker="arrowg")

    b += band(1200, 226, 348, 350, "GCP VPC", color=GCP, fill=GCP_T)
    b += node(1216, y - 76, 316, 88, "private.googleapis.com VIP", ("199.36.153.8/30",), color=GCP, fill=BG, tsize=13)
    b += arrow(1374, y + 16, 1374, y + 44, color=GREEN, marker="arrowg")
    b += padlock(1374, y + 30)
    b += db(1226, y + 50, 296, 84, "BigQuery", ("reached without touching the internet",), color=GCP, fill=BG, locked=True)
    b += tag(1374, y + 162, "datasets: analytics (internal) · web (PII)", color=GCP, fill="#c9e9d6")

    # the callout that cost a day
    b += band(120, 620, 900, 138, None, color=RED, fill="#fdf0f0")
    b += text(146, 652, "⚠   Cloud Router must ADVERTISE 199.36.153.8/30   (advertise_mode = CUSTOM)", size=13.5, fill=RED, weight="bold", anchor="start")
    b += text(146, 682, "Without it the tunnel is UP, BGP is Established, every route is active, the deploy is green —", size=11.5, fill=BODY, anchor="start")
    b += text(146, 702, "and the packets are silently dropped onto the public internet.", size=11.5, fill=BODY, weight="bold", anchor="start")
    b += text(146, 730, "I did not find it by reading status. I found it by counting bytes.", size=11, fill=MUTED, anchor="start")

    b += footer("BigQuery has no 'disable public access' switch. What is private here is the CONNECTION — not the disappearance of the public API.", w=1220)
    return b


# ------------------------------------------------------------------ 08 ------
def fig08():
    b = title("Public Connectivity — Azure & GCP", "Two nodes and one hop per path. The simplicity is the point.")
    b += banner(112, "Same catalogs.  Same grants.  Same JSON contract.  The only thing that changes is the road.")

    b += node(90, 360, 280, 150, "Databricks Serverless", ("Workspace", "Unity Catalog ·", "Lakehouse Federation"), color=DBX, fill=DBX_T, tsize=16)

    # Azure lane
    b += f'<path d="M 378 410 H 520 Q 560 410 560 372 V 300 H 660" fill="none" stroke="{AMBER}" stroke-width="2" marker-end="url(#arrowa)"/>'
    b += internet(720, 300, 1.15)
    b += arrow(772, 300, 900, 300, color=AMBER, marker="arrowa")
    b += padlock(720, 262, locked=False)
    b += alabel(720, 348, ["TLS 1433 · public endpoint"], fill=AMBER, size=11)
    b += db(915, 232, 400, 140, "Azure SQL", ("publicNetworkAccess = Enabled", "firewall allow-list"), color=AZURE, fill=AZURE_T, locked=False)
    b += tag(1115, 396, "schemas: inventory · orders", color=AZURE, fill="#cfe6fa")

    # GCP lane
    b += f'<path d="M 378 460 H 520 Q 560 460 560 498 V 570 H 660" fill="none" stroke="{AMBER}" stroke-width="2" marker-end="url(#arrowa)"/>'
    b += internet(720, 570, 1.15)
    b += arrow(772, 570, 900, 570, color=AMBER, marker="arrowa")
    b += padlock(720, 532, locked=False)
    b += alabel(720, 618, ["HTTPS 443 · googleapis.com"], fill=AMBER, size=11)
    b += db(915, 502, 400, 140, "BigQuery", ("public API endpoint", "IAM-authorised"), color=GCP, fill=GCP_T, locked=False)
    b += tag(1115, 666, "datasets: analytics (internal) · web (PII)", color=GCP, fill="#c9e9d6")

    b += text(1400, 300, "no proxy", size=11, fill=FAINT, weight="bold", anchor="start")
    b += text(1400, 318, "no tunnel", size=11, fill=FAINT, weight="bold", anchor="start")
    b += text(1400, 336, "no PrivateLink", size=11, fill=FAINT, weight="bold", anchor="start")
    b += text(1400, 570, "their absence", size=11, fill=FAINT, weight="bold", anchor="start")
    b += text(1400, 588, "is the message", size=11, fill=FAINT, weight="bold", anchor="start")

    b += footer("In public mode the integration layer creates ZERO resources — an apply that finishes in seconds is not a failure.", w=1080)
    return b


# ------------------------------------------------------------------ 09 ------
def fig09():
    b = title("One workspace. Three clouds. No public path.")
    b += text(W / 2, 84, "There is no internet-cloud glyph anywhere in this picture. That absence is the entire point.", size=13, fill=FAINT)

    b += node(40, 368, 176, 200, "Databricks", ("Serverless", "Workspace", "", "Unity Catalog ·", "runs in AWS"), color=DBX, fill=DBX_T, tsize=15)
    b += tag(128, 596, "NCC — Network Connectivity Config", color=DBX, fill="#fbd7d2", size=9)

    b += band(238, 176, 120, 570, None, color=GOV, fill=GOV_T)
    b += text(298, 200, "AWS", size=12, fill=GOV, weight="bold")
    b += text(298, 217, "PrivateLink", size=12, fill=GOV, weight="bold")

    lanes = [
        dict(y=280, color=AWS, tint=AWS_T, name="AWS",
             lane="VPC 10.40.0.0/16 · no Internet Gateway",
             hops=[("Internal NLB", ":5432"), ("Fargate", "pgbouncer"), ("RDS Proxy", "require_tls")],
             tun=None, mid=None,
             end=("Amazon RDS PostgreSQL", "publicly_accessible = false")),
        dict(y=470, color=AZURE, tint=AZURE_T, name="Azure",
             lane="AWS transit VPC 10.10.0.0/16 → Azure VNet",
             hops=[("Internal NLB", ":1433"), ("Fargate", "HAProxy")],
             tun="IPsec VPN", mid=("Azure Private", "Endpoint", 12),
             end=("Azure SQL", "publicNetworkAccess = Disabled")),
        dict(y=650, color=GCP, tint=GCP_T, name="GCP",
             lane="AWS transit VPC 10.11.0.0/16 → GCP VPC",
             hops=[("Internal NLB", ":443"), ("Fargate", "HAProxy :8443")],
             tun="IPsec VPN + BGP", mid=("private.googleapis", "199.36.153.8/30", 11),
             end=("BigQuery", "reached without touching the internet")),
    ]

    for L in lanes:
        y, c, t = L["y"], L["color"], L["tint"]
        b += band(376, y - 78, 1180, 156, None, color=c, fill=t)
        b += text(394, y - 52, L["name"], size=13, fill=c, weight="bold", anchor="start")
        b += text(1538, y - 52, L["lane"], size=10.5, fill=c, weight="bold", anchor="end")

        ny = y + 8  # node row sits below the lane header
        b += f'<path d="M 216 468 H 228 V {ny} H 232" fill="none" stroke="{GREEN}" stroke-width="2" marker-end="url(#arrowg)"/>'
        b += node(250, ny - 26, 96, 52, "PrivateLink", (), color=GOV, fill=BG, tsize=11, stroke=1.5)
        b += arrow(350, ny, 396, ny, color=GREEN, marker="arrowg")
        b += padlock(373, ny)

        last = len(L["hops"]) - 1
        for i, (ht, hs) in enumerate(L["hops"]):
            x = 404 + i * 192
            b += node(x, ny - 42, 160, 84, ht, (hs,), color=c, fill=BG, tsize=12, stroke=1.5)
            if i < last:
                b += arrow(x + 164, ny, x + 188, ny, color=GREEN, marker="arrowg")
                b += padlock(x + 176, ny)
        tail = 404 + last * 192 + 160  # right edge of the last hop

        if L["tun"]:
            b += arrow(tail + 4, ny, 786, ny, color=GREEN, marker="arrowg")
            b += tunnel(790, ny, 128, L["tun"], color=c, h=26)
            b += arrow(922, ny, 946, ny, color=GREEN, marker="arrowg")
            mt, ms, msz = L["mid"]
            b += node(950, ny - 42, 160, 84, mt, (ms,), color=c, fill=BG, tsize=msz, stroke=1.5)
            b += arrow(1114, ny, 1152, ny, color=GREEN, marker="arrowg")
            b += padlock(1133, ny)
        else:
            b += arrow(tail + 6, ny, 1152, ny, color=GREEN, marker="arrowg")
            b += padlock(1054, ny)

        et, es = L["end"]
        b += db(1160, ny - 46, 388, 92, et, (es,), color=c, fill=BG, locked=True)

    # Drawn last so it sits ON TOP of the lane tints. It spans only the Azure and
    # GCP lanes — the AWS path never leaves AWS, so it has no boundary to cross —
    # and it is placed at x=854 so that exactly the two IPsec tunnels cross it.
    b += boundary(854, 392, 728)

    b += footer("3 NCC rules   ·   3 PrivateLink services   ·   2 IPsec tunnels   ·   0 public endpoints", w=920, y=790)
    return b


# ------------------------------------------------------------------ 10 ------
def fig10():
    b = title("One contract. Three clouds. Two engines.")
    b += text(W / 2, 82, "Everything below flows down from a single JSON document.", size=13, fill=FAINT)

    # BAND 1 — the contract
    b += doc(620, 108, 360, 96, "domain JSON — infra + grants + classification",
             ("one file per domain · the only place governance is written",))
    for x in (420, 800, 1180):
        b += f'<path d="M 800 206 V 222 H {x} V 244" fill="none" stroke="{GOV}" stroke-width="2" marker-end="url(#arrowv)"/>'

    # BAND 2 — offline governance
    b += band(80, 248, 1440, 148, None, color=GOV, fill=GOV_T)
    b += text(96, 270, "GOVERNED — offline, before anything is deployed", size=11, fill=GOV, weight="bold", anchor="start")
    g = [
        ("Policy analyzer", ("least-privilege + PII gate",), "fails the PR on any HIGH", "#fde8e8", RED),
        ("OPA / Rego", ("independent re-implementation",), "cross-checks the analyzer", "#ede9fe", GOV),
        ("Cost + carbon estimate", ("multi-cloud + Databricks",), "before a single resource exists", "#ede9fe", GOV),
    ]
    for i, (t, s, tg, tf, tc) in enumerate(g):
        x = 110 + i * 460
        b += node(x, 284, 420, 74, t, s, color=GOV, fill=BG, tsize=14)
        b += tag(x + 210, 374, tg, color=tc, fill=tf, size=9.5)
    b += text(800, 412, "no cloud, no credentials — this runs on a laptop", size=11, fill=MUTED, weight="bold")

    # BAND 3 — deployed
    b += band(80, 428, 1440, 226, None, color=LINE, fill=PANEL)
    b += text(96, 450, "DEPLOYED — by Terragrunt, into three clouds", size=11, fill=MUTED, weight="bold", anchor="start")
    b += tag(1348, 445, "public or private — a per-cloud flag, not a rewrite", color=DBX, fill="#fbd7d2", size=9.5)
    b += node(110, 462, 1380, 62, "Databricks Unity Catalog — one metastore, one serverless workspace",
              ("catalogs:  sales_rds_fed  ·  supply_sql_master  ·  marketing_bq_fed  ·  shared_gcp_delta_share",),
              color=DBX, fill=DBX_T, tsize=15)

    clouds = [
        ("AWS", ("S3 · RDS Postgres", "ECS · PrivateLink"), AWS, AWS_T),
        ("Azure", ("ADLS · Azure SQL", "VPN Gateway"), AZURE, AZURE_T),
        ("GCP", ("GCS · BigQuery", "HA VPN"), GCP, GCP_T),
    ]
    for i, (t, s, c, f) in enumerate(clouds):
        x = 110 + i * 460
        b += node(x, 556, 420, 84, t, s, color=c, fill=f, tsize=15)
        b += f'<line x1="{x+210}" y1="526" x2="{x+210}" y2="552" stroke="{MUTED}" stroke-width="2" marker-end="url(#arrow)"/>'

    # BAND 4 — the result
    b += band(80, 668, 1440, 150, None, color=AWS, fill="#fdfaf6")
    b += node(100, 688, 250, 78, "Medallion", ("bronze → silver → gold",), color=DBX, fill=BG, tsize=14)
    b += tag(225, 786, "PII minimised at the silver step", color=DBX, fill=DBX_T, size=9.5)
    b += arrow(356, 727, 396, 727, color=MUTED)

    b += node(404, 688, 300, 78, "Amazon S3 · sales/gold-zone/", ("executive_cross_cloud",), color=AWS, fill=AWS_T, tsize=14)

    b += f'<path d="M 710 715 H 750 V 700 H 786" fill="none" stroke="{MUTED}" stroke-width="2" marker-end="url(#arrow)"/>'
    b += f'<path d="M 710 739 H 750 V 754 H 786" fill="none" stroke="{MUTED}" stroke-width="2" marker-end="url(#arrow)"/>'
    b += node(794, 676, 250, 48, "Databricks SQL", (), color=DBX, fill=BG, tsize=13, stroke=1.5)
    b += node(794, 730, 250, 48, "Snowflake — external table, zero-copy", (), color=SNOW, fill=BG, tsize=11.5, stroke=1.5)

    b += f'<path d="M 1048 700 H 1080 V 727 H 1112" fill="none" stroke="{MUTED}" stroke-width="2"/>'
    b += f'<path d="M 1048 754 H 1080 V 727 H 1112" fill="none" stroke="{MUTED}" stroke-width="2" marker-end="url(#arrow)"/>'
    b += node(1120, 688, 380, 78, "Executive dashboard", ("revenue · marketing ROI · stockout risk",), color=INK, fill=BG, tsize=14)

    b += footer("The contract is the source. Everything else is a consequence.", w=680, y=838)
    return b


FIGS = {
    "01-aws-public-connection": fig01,
    "02-aws-private-connection": fig02,
    "03-public-vs-private-side-by-side": fig03,
    "04-zero-copy-snowflake": fig04,
    "05-the-transit-hub-idea": fig05,
    "06-azure-private-connection": fig06,
    "07-gcp-private-connection": fig07,
    "08-azure-and-gcp-public": fig08,
    "09-three-clouds-private-hero": fig09,
    "10-the-whole-platform": fig10,
}

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def to_png(svg_path: Path, png_path: Path, scale: int = 2) -> bool:
    if not Path(CHROME).exists():
        return False
    with tempfile.TemporaryDirectory() as td:
        page = Path(td) / "p.html"
        shutil.copy(svg_path, Path(td) / "d.svg")
        page.write_text(
            f'<html><head><style>html,body{{margin:0;padding:0;overflow:hidden}}</style></head>'
            f'<body><img src="d.svg" width="{W}" height="{H}"></body></html>'
        )
        subprocess.run(
            [CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
             f"--force-device-scale-factor={scale}", f"--window-size={W},{H}",
             f"--screenshot={png_path}", str(page)],
            check=True, capture_output=True,
        )
    return png_path.exists()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--svg", action="store_true", help="SVG only, skip PNG rendering")
    ap.add_argument("--only", help="render a single figure by name prefix, e.g. 09")
    args = ap.parse_args()

    for name, fn in FIGS.items():
        if args.only and not name.startswith(args.only):
            continue
        s = OUT / f"{name}.svg"
        s.write_text(svg(fn()))
        line = f"  {s.relative_to(OUT.parent.parent)}"
        if not args.svg:
            p = OUT / f"{name}.png"
            if to_png(s, p):
                line += f"  →  {p.name}"
            else:
                line += "  (Chrome not found — SVG only)"
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
heading.py 
-----------------
For heading analysis, we assume lines for PGN 127250 contain something like:
... 127250 Vessel Heading: Heading = 123.4

This script:
- filters lines by PGN (default 127250)
- extracts Heading value
- computes circular delta between successive headings
- flags anomalies using median + MAD
"""

from __future__ import annotations

import argparse
import re
import statistics
from dataclasses import dataclass
from typing import List, Optional, Tuple


DEFAULT_PGN = 127250


@dataclass
class Point:
    t: str          # keep timestamp as string (no parsing needed)
    heading: float  # stores heading in degrees [0, 360)


@dataclass
#this class stores the data of the difference between 2 points 
class Delta:
    t_prev: str
    t_curr: str
    h_prev: float
    h_curr: float
    d_deg: float    # (-180, 180]


LINE_RE = re.compile(
    r"""^
    (?P<ts>\S+)                 # timestamp (no spaces)
    \s+\d+\s+\d+\s+\d+\s+        # 3 ints: prio src dst (we ignore)
    (?P<pgn>\d+)                 # PGN
    \s+.*?                       # name text
    :\s*(?P<body>.*)$            # after colon is the body
    """,
    re.VERBOSE,
)

# Finds looks at heading and anticipates different possible versions "Heading = 123.4" or "heading=123.4deg" etc.
HEADING_RE = re.compile(r"\bheading\b\s*=\s*([-+]?\d+(?:\.\d+)?)", re.IGNORECASE)

#makes the heading into compass range 
def normalize(h: float) -> float:
    h = h % 360.0
    return h + 360.0 if h < 0 else h

#calculates the true turn range between the heading 
def circ_delta(prev: float, curr: float) -> float:
    d = (curr - prev) % 360.0
    if d > 180.0:
        d -= 360.0
    return d

# calculates the varibility using Median Absolute Deviation 
def mad(vals: List[float]) -> float:
    if not vals:
        return 0.0
    m = statistics.median(vals)
    return statistics.median([abs(x - m) for x in vals])

#reads the log file and extracts the data 
def parse_points(path: str, pgn: int) -> List[Point]:
    points: List[Point] = []
    with open(path, "r", encoding="utf-8", errors="ignore") as f:      #this goes line by line 
        for line in f:
            line = line.strip()
            if not line:
                continue

            m = LINE_RE.match(line)
            if not m:
                continue

            if int(m.group("pgn")) != pgn:
                continue

            body = m.group("body")
            hm = HEADING_RE.search(body)
            if not hm:
                continue

            h = normalize(float(hm.group(1)))
            points.append(Point(t=m.group("ts"), heading=h))

    return points

#takes different points and converts them into deltas 
def compute_deltas(points: List[Point]) -> List[Delta]:
    out: List[Delta] = []
    for i in range(1, len(points)):
        out.append(
            Delta(
                t_prev=points[i - 1].t,
                t_curr=points[i].t,
                h_prev=points[i - 1].heading,
                h_curr=points[i].heading,
                d_deg=circ_delta(points[i - 1].heading, points[i].heading),
            )
        )
    return out

#compares the median delta to the MAD. the values that are outside the threshhold get flagged as anomalous data 
def flag_anoms(deltas: List[Delta], k: float) -> Tuple[float, float, List[Tuple[int, Delta]]]:
    vals = [d.d_deg for d in deltas]
    if not vals:
        return 0.0, 0.0, []

    med = float(statistics.median(vals))
    m = float(mad(vals))
    eps = 1e-9
    thresh = k * (m if m > 0 else eps)

    anoms: List[Tuple[int, Delta]] = []
    for i, d in enumerate(deltas):
        if abs(d.d_deg - med) > thresh:
            anoms.append((i, d))

    return med, m, anoms

#creates arguments 
def main() -> int:
    ap = argparse.()
    ap.add_argument("--log", required=True, help="Path to your plain-text log file.")
    ap.add_argument("--pgn", type=int, default=DEFAULT_PGN, help="PGN to analyze (default 127250).")
    ap.add_argument("--k", type=float, default=8.0, help="MAD multiplier (default 8.0).")
    ap.add_argument("--min-points", type=int, default=20, help="Minimum points required (default 20).")
    args = ap.parse_args()

    pts = parse_points(args.log, args.pgn)
    print(f"PGN {args.pgn} points: {len(pts)}")
    if len(pts) < args.min_points:
        print(f"Not enough points (need {args.min_points}).")
        return 2

    ds = compute_deltas(pts)
    med, m, anoms = flag_anoms(ds, args.k)
#prints out anomlous data and how it was found 
    print(f"Delta median: {med:.6f} deg")
    print(f"Delta MAD:    {m:.6f} deg")
    print(f"Anomalies:    {len(anoms)} (rule: |delta - median| > {args.k}*MAD)\n")

    if anoms:
        print("idx | t_prev -> t_curr | h_prev -> h_curr | delta")
        print("-" * 80)
        for idx, d in anoms[:200]:
            print(f"{idx:3d} | {d.t_prev} -> {d.t_curr} | {d.h_prev:8.3f} -> {d.h_curr:8.3f} | {d.d_deg:9.6f}")
        if len(anoms) > 200:
            print(f"... (showing first 200 of {len(anoms)})")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""
plot_heading_rudder_deltas.py

Input: canboat analyzer *text* output (lines like:
  2026-01-22-20:27:31.654 ... 127250 Vessel Heading: ... Heading = 88.8 deg; ... Reference = True
  2026-01-22-20:27:31.696 ... 127245 Rudder: ... Position = -1.6 deg

Output: One plot with two time series (different colors):
  - Heading delta (circular) vs time
  - Rudder delta (linear) vs time
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional, Tuple

import matplotlib.pyplot as plt


# --------- REGEX ---------
TS_RE = re.compile(r"^(?P<ts>\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}\.\d{3})\s+")
PGN_RE = re.compile(r"\s(?P<pgn>\d{5,6})\s")

HEADING_VALUE_RE = re.compile(r"\bHeading\s*=\s*([-+]?\d+(?:\.\d+)?)\s*deg\b")
HEADING_REF_RE = re.compile(r"\bReference\s*=\s*(True|Magnetic)\b")

RUDDER_VALUE_RE = re.compile(r"\bPosition\s*=\s*([-+]?\d+(?:\.\d+)?)\s*deg\b")


@dataclass
class Point:
    t: datetime
    v: float


def parse_timestamp(ts: str) -> datetime:
    return datetime.strptime(ts, "%Y-%m-%d-%H:%M:%S.%f")


def circular_delta_deg(curr: float, prev: float) -> float:
    """Shortest signed angular difference in degrees, result in [-180, +180]."""
    d = (curr - prev) % 360.0
    if d > 180.0:
        d -= 360.0
    return d


def extract_heading(line: str) -> Optional[Tuple[float, str]]:
    """Return (heading_degrees, reference_str) or None."""
    m_val = HEADING_VALUE_RE.search(line)
    if not m_val:
        return None
    heading = float(m_val.group(1))

    m_ref = HEADING_REF_RE.search(line)
    if not m_ref:
        return None
    ref = m_ref.group(1)  # "True" or "Magnetic"
    return heading, ref


def extract_rudder(line: str) -> Optional[float]:
    m = RUDDER_VALUE_RE.search(line)
    if not m:
        return None
    return float(m.group(1))


def parse_file(path: str, heading_reference_to_use: str = "True") -> Tuple[List[Point], List[Point]]:
    heading: List[Point] = []
    rudder: List[Point] = []

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for raw in f:
            line = raw.strip()
            if not line:
                continue

            ts_m = TS_RE.search(line)
            if not ts_m:
                continue
            t = parse_timestamp(ts_m.group("ts"))

            pgn_m = PGN_RE.search(line)
            if not pgn_m:
                continue
            pgn = int(pgn_m.group("pgn"))

            if pgn == 127250:
                hv = extract_heading(line)
                if hv is None:
                    continue
                heading_deg, ref = hv
                if ref == heading_reference_to_use:
                    heading.append(Point(t, heading_deg))

            elif pgn == 127245:
                rv = extract_rudder(line)
                if rv is not None:
                    rudder.append(Point(t, rv))

    return heading, rudder


def compute_deltas(points: List[Point], circular: bool) -> List[Point]:
    if len(points) < 2:
        return []
    points = sorted(points, key=lambda p: p.t)

    out: List[Point] = []
    prev = points[0]
    for curr in points[1:]:
        dv = circular_delta_deg(curr.v, prev.v) if circular else (curr.v - prev.v)
        out.append(Point(curr.t, dv))
        prev = curr
    return out


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: python plot_heading_rudder_deltas.py <analyzer_output.txt> [True|Magnetic]")
        print("Default heading reference: True")
        return 2

    path = sys.argv[1]
    heading_ref = sys.argv[2] if len(sys.argv) >= 3 else "True"
    if heading_ref not in ("True", "Magnetic"):
        print("Heading reference must be 'True' or 'Magnetic'")
        return 2

    heading_pts, rudder_pts = parse_file(path, heading_reference_to_use=heading_ref)

    if not heading_pts:
        print(f"No heading points found for PGN 127250 with Reference={heading_ref}")
    if not rudder_pts:
        print("No rudder points found for PGN 127245")

    heading_d = compute_deltas(heading_pts, circular=True)
    rudder_d = compute_deltas(rudder_pts, circular=False)

    if not heading_d and not rudder_d:
        print("No deltas computed (need at least 2 points per series).")
        return 1

    plt.figure()

    if heading_d:
        plt.plot([p.t for p in heading_d], [p.v for p in heading_d],
                 label=f"Heading Δ (127250, Reference={heading_ref})")
    if rudder_d:
        plt.plot([p.t for p in rudder_d], [p.v for p in rudder_d],
                 label="Rudder Δ (127245)")

    plt.xlabel("Time")
    plt.ylabel("Delta (deg)")
    plt.title("Heading vs Rudder Delta Over Time")
    plt.legend()
    plt.tight_layout()
    plt.show()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

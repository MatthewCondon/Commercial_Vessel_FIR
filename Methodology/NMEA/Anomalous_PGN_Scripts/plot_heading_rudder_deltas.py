#!/usr/bin/env python3
"""
plot_heading_rudder_deltas.py (robust analyzer text parser)

Reads canboat analyzer *text* output lines like:
  2026-01-22-20:27:31.654 2   0 255 127250 Vessel Heading: ... Heading = 88.8 deg; ... Reference = True
  2026-01-22-20:27:31.696 2   0 255 127245 Rudder: ... Position = -1.6 deg

Computes deltas:
  - Heading delta: circular (wrap-safe)
  - Rudder delta: linear

Outputs:
  - heading_deltas.csv
  - rudder_deltas.csv
If matplotlib is installed, also shows an overlay plot.
"""

from __future__ import annotations

import csv
import sys
import re
from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional, Tuple


# Accept timestamps like:
# 2026-01-22-20:27:31.654
# 2026-01-22-20:27:31.654321
# 2026-01-22-20:27:31
TS_FLEX_RE = re.compile(
    r"^\s*(?P<ts>\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?)\s+"
)

HEADING_VALUE_RE = re.compile(r"\bHeading\s*=\s*([-+]?\d+(?:\.\d+)?)\s*deg\b")
HEADING_REF_RE = re.compile(r"\bReference\s*=\s*(True|Magnetic)\b")

RUDDER_VALUE_RE = re.compile(r"\bPosition\s*=\s*([-+]?\d+(?:\.\d+)?)\s*deg\b")


@dataclass
class Point:
    t: datetime
    v: float


def parse_timestamp_flex(ts: str) -> datetime:
    # Normalize fractional seconds to microseconds (0–6 digits)
    if "." in ts:
        base, frac = ts.split(".", 1)
        frac = (frac + "000000")[:6]
        ts_norm = f"{base}.{frac}"
        return datetime.strptime(ts_norm, "%Y-%m-%d-%H:%M:%S.%f")
    return datetime.strptime(ts, "%Y-%m-%d-%H:%M:%S")


def circular_delta_deg(curr: float, prev: float) -> float:
    d = (curr - prev) % 360.0
    if d > 180.0:
        d -= 360.0
    return d


def extract_heading(line_rest: str) -> Optional[Tuple[float, str]]:
    mv = HEADING_VALUE_RE.search(line_rest)
    mr = HEADING_REF_RE.search(line_rest)
    if not mv or not mr:
        return None
    return float(mv.group(1)), mr.group(1)


def extract_rudder(line_rest: str) -> Optional[float]:
    m = RUDDER_VALUE_RE.search(line_rest)
    return float(m.group(1)) if m else None


def parse_line(line: str) -> Optional[Tuple[datetime, int, str]]:
    """
    Returns (timestamp, pgn, remainder_text) if parseable, else None.
    Expected token layout after timestamp:
      <prio> <src> <dst> <pgn> <rest...>
    """
    m = TS_FLEX_RE.match(line)
    if not m:
        return None

    ts_str = m.group("ts")
    t = parse_timestamp_flex(ts_str)

    after_ts = line[m.end():].strip()
    parts = after_ts.split(maxsplit=4)
    if len(parts) < 5:
        return None

    # parts: prio, src, dst, pgn, rest
    try:
        pgn = int(parts[3])
    except ValueError:
        return None

    rest = parts[4]
    return t, pgn, rest


def parse_file(path: str, heading_reference_to_use: str = "True") -> Tuple[List[Point], List[Point]]:
    heading: List[Point] = []
    rudder: List[Point] = []

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            parsed = parse_line(line)
            if not parsed:
                continue
            t, pgn, rest = parsed

            if pgn == 127250:
                hv = extract_heading(rest)
                if hv is None:
                    continue
                heading_deg, ref = hv
                if ref == heading_reference_to_use:
                    heading.append(Point(t, heading_deg))

            elif pgn == 127245:
                rv = extract_rudder(rest)
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


def write_csv(path: str, points: List[Point]) -> None:
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["time_iso", "delta_deg"])
        for p in points:
            w.writerow([p.t.isoformat(), f"{p.v:.6f}"])


def try_plot(heading_d: List[Point], rudder_d: List[Point], heading_ref: str) -> None:
    try:
        import matplotlib.pyplot as plt  # type: ignore
    except ModuleNotFoundError:
        print("matplotlib not installed — wrote CSVs only (no plot).")
        return

    plt.figure()
    if heading_d:
        plt.plot([p.t for p in heading_d], [p.v for p in heading_d],
                 label=f"Heading Δ (127250, Ref={heading_ref})")
    if rudder_d:
        plt.plot([p.t for p in rudder_d], [p.v for p in rudder_d],
                 label="Rudder Δ (127245)")
    plt.xlabel("Time")
    plt.ylabel("Delta (deg)")
    plt.title("Heading vs Rudder Delta Over Time")
    plt.legend()
    plt.tight_layout()
    plt.show()


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: python plot_heading_rudder_deltas.py <analyzer.txt> [True|Magnetic]")
        return 2

    path = sys.argv[1]
    heading_ref = sys.argv[2] if len(sys.argv) >= 3 else "True"
    if heading_ref not in ("True", "Magnetic"):
        print("Heading reference must be 'True' or 'Magnetic'")
        return 2

    heading_pts, rudder_pts = parse_file(path, heading_reference_to_use=heading_ref)

    print(f"Parsed heading points: {len(heading_pts)} (PGN 127250, Ref={heading_ref})")
    print(f"Parsed rudder points:  {len(rudder_pts)} (PGN 127245)")

    heading_d = compute_deltas(heading_pts, circular=True)
    rudder_d = compute_deltas(rudder_pts, circular=False)

    print(f"Computed heading deltas: {len(heading_d)}")
    print(f"Computed rudder deltas:  {len(rudder_d)}")

    if not heading_d and not rudder_d:
        print("No deltas computed (need at least 2 points per series).")
        return 1

    write_csv("heading_deltas.csv", heading_d)
    write_csv("rudder_deltas.csv", rudder_d)
    print("Wrote: heading_deltas.csv, rudder_deltas.csv")

    try_plot(heading_d, rudder_d, heading_ref)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

if __name__ == "__main__":
    raise SystemExit(main())

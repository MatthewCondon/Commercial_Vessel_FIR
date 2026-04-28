#!/usr/bin/env python3

from __future__ import annotations

import csv
import re
import sys
from dataclasses import dataclass
from datetime import datetime
from typing import Dict, List, Optional, Tuple, Set


# =============================
# HARDCODED PGN MEANINGS
# =============================

PGN_MEANINGS = {
    127250: "Vessel Heading",
    127251: "Rate of Turn",
    127252: "Heave",
    127258: "Magnetic Variation",
    127245: "Rudder",
    129025: "Position, Rapid Update",
    129026: "COG & SOG, Rapid Update",
    129029: "GNSS Position Data",
    129033: "Time & Date",
    129283: "Cross Track Error",
    129291: "Set & Drift",
    130306: "Wind Data",
    130310: "Environmental Parameters",
    130311: "Environmental Parameters",
    130316: "Temperature, Extended Range",
    127488: "Engine Parameters, Rapid Update",
    127489: "Engine Parameters, Dynamic",
    127493: "Transmission Parameters",
    127505: "Fluid Level",
    127506: "DC Detailed Status",
    127508: "Battery Status",
    128259: "Speed",
    128267: "Water Depth",
    128275: "Distance Log",
    127501: "Binary Switch Bank Status",
    65284: "Maretron Proprietary",
}

# =============================
# DEFAULT FIELD SELECTION
# =============================

PGN_DEFAULT_FIELD = {
    127250: "Heading",
    127245: "Position",
}


def get_pgn_name(pgn: int) -> str:
    return PGN_MEANINGS.get(pgn, "Unknown PGN")


# =============================
# PARSING
# =============================

TS_RE = re.compile(
    r"^\s*(?P<ts>\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?)\s+"
)

FIELD_RE = re.compile(
    r"\b(?P<name>[A-Za-z][A-Za-z0-9_/\- ]{0,50}?)\s*=\s*(?P<val>[-+]?\d+(?:\.\d+)?)\b"
)


@dataclass(frozen=True)
class Point:
    t: datetime
    v: float


def parse_timestamp(ts: str) -> datetime:
    if "." in ts:
        base, frac = ts.split(".", 1)
        frac = (frac + "000000")[:6]
        ts = f"{base}.{frac}"
        return datetime.strptime(ts, "%Y-%m-%d-%H:%M:%S.%f")
    return datetime.strptime(ts, "%Y-%m-%d-%H:%M:%S")


def parse_line(line: str) -> Optional[Tuple[datetime, int, str]]:
    m = TS_RE.match(line)
    if not m:
        return None

    t = parse_timestamp(m.group("ts"))
    parts = line[m.end():].strip().split(maxsplit=4)
    if len(parts) < 5:
        return None

    try:
        pgn = int(parts[3])
    except ValueError:
        return None

    rest = parts[4]
    return t, pgn, rest


# =============================
# DELTA MATH
# =============================

def circular_delta(curr: float, prev: float) -> float:
    d = (curr - prev) % 360.0
    if d > 180:
        d -= 360
    return d


def compute_deltas(points: List[Point], circular: bool) -> List[Point]:
    if len(points) < 2:
        return []

    pts = sorted(points, key=lambda p: p.t)

    # remove duplicate timestamps
    dedup: Dict[datetime, float] = {}
    for p in pts:
        dedup[p.t] = p.v

    pts2 = [Point(t, v) for t, v in sorted(dedup.items())]

    out: List[Point] = []
    prev = pts2[0]

    for curr in pts2[1:]:
        dv = circular_delta(curr.v, prev.v) if circular else (curr.v - prev.v)
        out.append(Point(curr.t, dv))
        prev = curr

    return out


# =============================
# DISCOVERY
# =============================

def discover_pgns(path: str) -> Dict[int, int]:
    counts: Dict[int, int] = {}
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            parsed = parse_line(line)
            if not parsed:
                continue
            _, pgn, _ = parsed
            counts[pgn] = counts.get(pgn, 0) + 1
    return counts


def discover_fields(path: str, target_pgn: int) -> List[str]:
    fields: Set[str] = set()
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            parsed = parse_line(line)
            if not parsed:
                continue
            _, pgn, rest = parsed
            if pgn != target_pgn:
                continue

            for m in FIELD_RE.finditer(rest):
                fields.add(m.group("name").strip())

    return sorted(fields)


def auto_select_field(path: str, pgn: int) -> str:
    fields = discover_fields(path, pgn)

    if not fields:
        print(f"No numeric fields found for PGN {pgn}")
        raise SystemExit(1)

    if pgn in PGN_DEFAULT_FIELD:
        default = PGN_DEFAULT_FIELD[pgn]
        if default in fields:
            print(f"Auto-selected field '{default}' for PGN {pgn}")
            return default

    fallback = fields[0]
    print(f"No default match — using '{fallback}' for PGN {pgn}")
    return fallback


def extract_points(path: str, target_pgn: int, field: str) -> List[Point]:
    out: List[Point] = []
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            parsed = parse_line(line)
            if not parsed:
                continue
            t, pgn, rest = parsed
            if pgn != target_pgn:
                continue

            for m in FIELD_RE.finditer(rest):
                if m.group("name").strip() == field:
                    out.append(Point(t, float(m.group("val"))))
                    break
    return out


# =============================
# OUTPUT
# =============================

def write_csv(path: str, series: List[Tuple[str, List[Point]]]):
    all_times: Set[datetime] = set()
    maps = []

    for label, pts in series:
        m = {p.t: p.v for p in pts}
        maps.append((label, m))
        all_times.update(m.keys())

    times_sorted = sorted(all_times)

    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        headers = ["time_iso"] + [label for label, _ in maps]
        w.writerow(headers)

        for t in times_sorted:
            row = [t.isoformat()]
            for _, m in maps:
                row.append("" if t not in m else f"{m[t]:.6f}")
            w.writerow(row)


def try_plot(series: List[Tuple[str, List[Point]]]):
    try:
        import matplotlib.pyplot as plt
    except ModuleNotFoundError:
        print("matplotlib not installed. CSV created only.")
        return

    plt.figure()
    for label, pts in series:
        pts = sorted(pts, key=lambda p: p.t)
        plt.plot([p.t for p in pts], [p.v for p in pts], label=label)

    plt.xlabel("Time")
    plt.ylabel("Delta")
    plt.title("PGN Delta Comparison")
    plt.legend()
    plt.tight_layout()
    plt.show()


# =============================
# MAIN
# =============================

def prompt_int(prompt: str, valid: Set[int]) -> int:
    while True:
        try:
            v = int(input(prompt))
            if v in valid:
                return v
        except:
            pass
        print(f"Choose from {sorted(valid)}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python interactive_pgn_delta_plotter.py analyzer.txt")
        return

    path = sys.argv[1]

    print("\n1) Graph 1 PGN")
    print("2) Compare 2 PGNs")
    mode = prompt_int("Select mode: ", {1, 2})

    pgn_counts = discover_pgns(path)
    pgn_list = sorted(pgn_counts.keys())

    print("\nPGNs found:")
    for i, pgn in enumerate(pgn_list, 1):
        print(f"[{i}] {pgn} – {get_pgn_name(pgn)} ({pgn_counts[pgn]} msgs)")

    def pick_pgn(label: str):
        idx = prompt_int(f"Select {label} PGN: ", set(range(1, len(pgn_list)+1)))
        return pgn_list[idx-1]

    pgn1 = pick_pgn("first")
    pgn2 = pick_pgn("second") if mode == 2 else None

    field1 = auto_select_field(path, pgn1)
    field2 = auto_select_field(path, pgn2) if pgn2 else None

    pts1 = extract_points(path, pgn1, field1)
    deltas1 = compute_deltas(pts1, circular=(field1.lower() == "heading"))

    series = [(f"{get_pgn_name(pgn1)} ({field1}) Δ", deltas1)]

    if pgn2 and field2:
        pts2 = extract_points(path, pgn2, field2)
        deltas2 = compute_deltas(pts2, circular=(field2.lower() == "heading"))
        series.append((f"{get_pgn_name(pgn2)} ({field2}) Δ", deltas2))

    write_csv("combined_deltas.csv", series)
    print("\nWrote combined_deltas.csv")

    try_plot(series)


if __name__ == "__main__":
    main()

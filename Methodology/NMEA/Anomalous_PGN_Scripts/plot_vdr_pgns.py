#!/usr/bin/env python3
"""
plot_vdr_pgns.py
----------------
Graphs multiple PGNs from a VDR-style NMEA2000/CAN export line format:

Example line:
00002CCC | 26 | 15FD07C0 | 130311 | 5 | 192 | 255 | 1F C3 FF FF FF 7F FF FF | Environmental Parameters (2)

What it plots (per PGN):
1) Delta-t (rate) over time  [requires parseable timestamps]
2) Payload Hamming distance over time
3) Selected byte traces over time (e.g., byte0, byte1, byte2...)

Usage:
  python3 plot_vdr_pgns.py --vdr data/vdr.log --pgn 127245 127250 127488 --bytes 0 1 2

If your "time" column is a tick counter you want in seconds:
  python3 plot_vdr_pgns.py --vdr data/vdr.log --pgn 127245 --time-scale 0.001
(0.001 converts milliseconds->seconds, for example)

Notes:
- This is protocol-agnostic plotting. It doesn't decode PGNs to real-world units.
- It's still extremely useful for anomaly visualization (flooding, bursts, stuck bytes, spoofing).
"""

from __future__ import annotations

import argparse
import re
import statistics
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import matplotlib.pyplot as plt

HEXBYTE_RE = re.compile(r"^[0-9A-Fa-f]{2}$")

@dataclass
class VdrMsg:
    t_raw: str
    t: Optional[float]
    pgn: int
    data: bytes
    label: str
    line_no: int

def try_parse_time(token: str) -> Optional[float]:
    tok = token.strip()
    if not tok:
        return None
    # decimal integer
    if tok.isdigit():
        return float(int(tok))
    # hex-ish
    try:
        if all(c in "0123456789abcdefABCDEF" for c in tok):
            return float(int(tok, 16))
    except Exception:
        return None
    return None

def parse_data_bytes(s: str) -> bytes:
    parts = [p.strip() for p in s.strip().split()]
    out: List[int] = []
    for p in parts:
        if HEXBYTE_RE.match(p):
            out.append(int(p, 16))
    return bytes(out)

def parse_vdr_file(path: Path, time_scale: float) -> List[VdrMsg]:
    msgs: List[VdrMsg] = []
    for i, raw in enumerate(path.read_text(errors="ignore").splitlines(), start=1):
        line = raw.strip()
        if not line or "|" not in line:
            continue
        cols = [c.strip() for c in line.split("|")]
        if len(cols) < 8:
            continue

        t_raw = cols[0]
        t = try_parse_time(t_raw)
        if t is not None:
            t *= time_scale

        try:
            pgn = int(cols[3])
        except Exception:
            continue

        data = parse_data_bytes(cols[7])
        label = cols[8] if len(cols) >= 9 else ""

        msgs.append(VdrMsg(t_raw=t_raw, t=t, pgn=pgn, data=data, label=label, line_no=i))
    return msgs

def hamming_distance(a: bytes, b: bytes) -> int:
    n = min(len(a), len(b))
    dist = 0
    for i in range(n):
        dist += (a[i] ^ b[i]).bit_count()
    dist += 8 * abs(len(a) - len(b))
    return dist

def build_series(msgs: List[VdrMsg]) -> Dict[str, List[Tuple[float, float]]]:
    """
    Builds:
      dt_series: (t_curr, dt) for each msg after first
      ham_series: (t_curr, hamming(prev, curr))
      byte_series[i]: (t, byte_value) for each message where byte exists
    Assumes timestamps exist; if not, caller should replace t with line_no.
    """
    dt_series: List[Tuple[float, float]] = []
    ham_series: List[Tuple[float, float]] = []
    byte_series: Dict[int, List[Tuple[float, float]]] = {}

    msgs = sorted(msgs, key=lambda m: m.t)  # t exists
    for idx, m in enumerate(msgs):
        t = float(m.t)  # type: ignore
        # bytes
        for bi, bv in enumerate(m.data):
            byte_series.setdefault(bi, []).append((t, float(bv)))

        if idx == 0:
            continue
        prev = msgs[idx - 1]
        t_prev = float(prev.t)  # type: ignore
        dt = t - t_prev
        dt_series.append((t, dt))

        hd = hamming_distance(prev.data, m.data)
        ham_series.append((t, float(hd)))

    return {
        "dt": dt_series,
        "ham": ham_series,
        "bytes": byte_series,  # keyed by byte index
    }

def build_series_no_time(msgs: List[VdrMsg]) -> Dict[str, List[Tuple[float, float]]]:
    """
    Same as build_series but uses line_no as x-axis (when no timestamps parse).
    """
    dt_series: List[Tuple[float, float]] = []
    ham_series: List[Tuple[float, float]] = []
    byte_series: Dict[int, List[Tuple[float, float]]] = {}

    msgs = sorted(msgs, key=lambda m: m.line_no)
    for idx, m in enumerate(msgs):
        x = float(m.line_no)
        for bi, bv in enumerate(m.data):
            byte_series.setdefault(bi, []).append((x, float(bv)))

        if idx == 0:
            continue
        prev = msgs[idx - 1]
        dt = float(m.line_no - prev.line_no)
        dt_series.append((x, dt))

        hd = hamming_distance(prev.data, m.data)
        ham_series.append((x, float(hd)))

    return {
        "dt": dt_series,
        "ham": ham_series,
        "bytes": byte_series,
    }

def plot_xy(series: List[Tuple[float, float]], title: str, xlabel: str, ylabel: str) -> None:
    if not series:
        print(f"[warn] no data to plot for: {title}")
        return
    xs = [x for x, _ in series]
    ys = [y for _, y in series]
    plt.figure()
    plt.plot(xs, ys)
    plt.title(title)
    plt.xlabel(xlabel)
    plt.ylabel(ylabel)
    plt.grid(True)

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--vdr", required=True, help="Path to VDR log file")
    ap.add_argument("--pgn", type=int, nargs="+", required=True, help="One or more PGNs to plot")
    ap.add_argument("--bytes", type=int, nargs="*", default=[], help="Byte indices to plot (0-7 typically)")
    ap.add_argument("--time-scale", type=float, default=1.0, help="Scale parsed time by this factor (e.g., 0.001)")
    ap.add_argument("--max-per-pgn", type=int, default=200000, help="Cap messages per PGN for plotting")
    args = ap.parse_args()

    path = Path(args.vdr)
    msgs = parse_vdr_file(path, time_scale=args.time_scale)
    if not msgs:
        print("No parseable messages found. Check format.")
        return 2

    # group by PGN
    groups: Dict[int, List[VdrMsg]] = {}
    for m in msgs:
        if m.pgn in set(args.pgn):
            groups.setdefault(m.pgn, []).append(m)

    if not groups:
        print("No messages matched requested PGNs.")
        return 2

    # determine if timestamps are usable
    any_time = any(m.t is not None for g in groups.values() for m in g)
    all_time = all(m.t is not None for g in groups.values() for m in g)

    if not all_time:
        print("[info] Some/all timestamps did not parse. Using line number as x-axis.")
        xlab = "line number"
        use_time = False
    else:
        xlab = "time (scaled units)"
        use_time = True

    for pgn in args.pgn:
        g = groups.get(pgn, [])
        if not g:
            continue
        if len(g) > args.max_per_pgn:
            g = g[: args.max_per_pgn]

        label = g[0].label.strip()
        name = f"PGN {pgn}" + (f" - {label}" if label else "")

        series = build_series(g) if use_time else build_series_no_time(g)

        # Plot delta-t (rate)
        plot_xy(
            series["dt"],
            title=f"{name} | Δt between messages",
            xlabel=xlab,
            ylabel="Δt",
        )

        # Plot payload change (hamming distance)
        plot_xy(
            series["ham"],
            title=f"{name} | payload change (Hamming distance)",
            xlabel=xlab,
            ylabel="Hamming distance (bits)",
        )

        # Plot selected bytes (if requested)
        for bi in args.bytes:
            bser = series["bytes"].get(bi, [])
            plot_xy(
                bser,
                title=f"{name} | byte[{bi}]",
                xlabel=xlab,
                ylabel=f"byte[{bi}] value (0-255)",
            )

    plt.show()
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

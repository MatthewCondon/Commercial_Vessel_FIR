#!/usr/bin/env python3
"""

-----------------------
Parse VDR-style NMEA 2000/CAN log lines separated by '|', group by PGN,
and flag anomalies per-PGN using robust stats (median + MAD):

1) Rate anomalies (time delta spikes/bursts)
2) Payload length anomalies
3) Payload change anomalies (Hamming distance spikes)
4) Repeated "invalid" payload patterns (all FF / all 00) as warnings

Input example line:
00002CCC | 26 | 15FD07C0 | 130311 | 5 | 192 | 255 | 1F C3 FF FF FF 7F FF FF | Environmental Parameters (2)
"""

from __future__ import annotations
import argparse
import re
import statistics
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

HEXBYTE_RE = re.compile(r"^[0-9A-Fa-f]{2}$")

@dataclass
class VdrMsg:
    t_raw: str                 # whatever is in col0 (we try to interpret as time)
    t: Optional[float]         # parsed time if possible, else None
    pgn: int
    data: bytes
    label: str
    line_no: int
    raw_line: str

def try_parse_time(token: str) -> Optional[float]:
    """
    Best-effort time parse:
    - if decimal int -> float
    - if hex like 00002CCC -> interpret as hex integer
    If your VDR uses ms ticks, you can later scale (e.g., /1000).
    """
    tok = token.strip()
    if not tok:
        return None
    # decimal
    if tok.isdigit():
        return float(int(tok))
    # hex
    try:
        if all(c in "0123456789abcdefABCDEF" for c in tok):
            return float(int(tok, 16))
    except Exception:
        pass
    return None

def parse_data_bytes(s: str) -> bytes:
    parts = [p.strip() for p in s.strip().split()]
    b = []
    for p in parts:
        if not p:
            continue
        if not HEXBYTE_RE.match(p):
            # ignore junk tokens
            continue
        b.append(int(p, 16))
    return bytes(b)

def parse_vdr_file(path: Path) -> List[VdrMsg]:
    msgs: List[VdrMsg] = []
    for i, raw in enumerate(path.read_text(errors="ignore").splitlines(), start=1):
        line = raw.strip()
        if not line or "|" not in line:
            continue
        cols = [c.strip() for c in line.split("|")]
        # We expect at least: col0 time, col3 PGN, col7 data
        if len(cols) < 8:
            continue

        t_raw = cols[0]
        t = try_parse_time(t_raw)

        # PGN is typically col3 in your example
        try:
            pgn = int(cols[3])
        except Exception:
            continue

        data = parse_data_bytes(cols[7])
        label = cols[8] if len(cols) >= 9 else ""

        msgs.append(VdrMsg(
            t_raw=t_raw, t=t, pgn=pgn, data=data, label=label,
            line_no=i, raw_line=raw
        ))
    return msgs

def mad(values: List[float]) -> float:
    if not values:
        return 0.0
    m = statistics.median(values)
    return statistics.median([abs(x - m) for x in values])

def hamming_distance(a: bytes, b: bytes) -> int:
    n = min(len(a), len(b))
    dist = 0
    for i in range(n):
        dist += (a[i] ^ b[i]).bit_count()
    # penalize length difference
    dist += 8 * abs(len(a) - len(b))
    return dist

def analyze_group(msgs: List[VdrMsg], k_rate: float, k_payload: float) -> Dict:
    # sort by time if we have it; else by line number
    msgs_sorted = sorted(msgs, key=lambda m: (m.t is None, m.t if m.t is not None else m.line_no))

    # 1) Rate deltas
    deltas: List[float] = []
    delta_pairs: List[Tuple[VdrMsg, VdrMsg, float]] = []
    if all(m.t is not None for m in msgs_sorted):
        for prev, cur in zip(msgs_sorted, msgs_sorted[1:]):
            d = float(cur.t - prev.t)  # type: ignore
            deltas.append(d)
            delta_pairs.append((prev, cur, d))

    rate_anoms: List[Tuple[VdrMsg, VdrMsg, float]] = []
    if deltas:
        med = float(statistics.median(deltas))
        m = float(mad(deltas))
        thresh = k_rate * (m if m > 0 else 1e-9)
        for prev, cur, d in delta_pairs:
            if abs(d - med) > thresh:
                rate_anoms.append((prev, cur, d))
    else:
        med, m = 0.0, 0.0

    # 2) Payload length anomalies
    lengths = [len(m.data) for m in msgs_sorted]
    common_len = statistics.mode(lengths) if lengths else 0
    len_anoms = [m for m in msgs_sorted if len(m.data) != common_len]

    # 3) Payload change anomalies using Hamming distance
    ham_vals: List[int] = []
    ham_pairs: List[Tuple[VdrMsg, VdrMsg, int]] = []
    for prev, cur in zip(msgs_sorted, msgs_sorted[1:]):
        hd = hamming_distance(prev.data, cur.data)
        ham_vals.append(hd)
        ham_pairs.append((prev, cur, hd))

    payload_anoms: List[Tuple[VdrMsg, VdrMsg, int]] = []
    if ham_vals:
        ham_med = float(statistics.median(ham_vals))
        ham_mad = float(mad([float(x) for x in ham_vals]))
        ham_thresh = k_payload * (ham_mad if ham_mad > 0 else 1e-9)
        for prev, cur, hd in ham_pairs:
            if abs(float(hd) - ham_med) > ham_thresh:
                payload_anoms.append((prev, cur, hd))
    else:
        ham_med, ham_mad = 0.0, 0.0

    # 4) Invalid pattern warnings
    ff = bytes([0xFF]) * common_len if common_len else b""
    zz = bytes([0x00]) * common_len if common_len else b""
    ff_count = sum(1 for m in msgs_sorted if common_len and m.data == ff)
    zz_count = sum(1 for m in msgs_sorted if common_len and m.data == zz)

    return {
        "count": len(msgs_sorted),
        "label": msgs_sorted[0].label if msgs_sorted else "",
        "rate": {"median": med, "mad": m, "anoms": rate_anoms, "has_time": bool(deltas)},
        "len": {"common": common_len, "anoms": len_anoms},
        "payload": {"median": ham_med, "mad": ham_mad, "anoms": payload_anoms},
        "invalid": {"all_ff": ff_count, "all_00": zz_count},
    }

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--vdr", required=True, help="Path to VDR log text file")
    ap.add_argument("--top", type=int, default=15, help="Show top N PGNs by message count")
    ap.add_argument("--min-count", type=int, default=50, help="Only analyze PGNs with at least this many messages")
    ap.add_argument("--k-rate", type=float, default=8.0, help="MAD multiplier for rate anomalies")
    ap.add_argument("--k-payload", type=float, default=10.0, help="MAD multiplier for payload-change anomalies")
    args = ap.parse_args()

    path = Path(args.vdr)
    msgs = parse_vdr_file(path)
    if not msgs:
        print("No parseable messages found. Check file format / separators.")
        return 2

    groups: Dict[int, List[VdrMsg]] = {}
    for m in msgs:
        groups.setdefault(m.pgn, []).append(m)

    # show most common
    by_count = sorted(groups.items(), key=lambda kv: len(kv[1]), reverse=True)
    print(f"Parsed {len(msgs)} messages across {len(groups)} PGNs.\n")
    print(f"Top {args.top} PGNs by count:")
    for pgn, g in by_count[:args.top]:
        lbl = g[0].label
        print(f"  PGN {pgn}: {len(g)} msgs  {('- ' + lbl) if lbl else ''}")

    print("\nAnalyzing PGNs...")
    for pgn, g in by_count:
        if len(g) < args.min_count:
            continue
        res = analyze_group(g, k_rate=args.k_rate, k_payload=args.k_payload)

        rate_anoms = res["rate"]["anoms"]
        len_anoms = res["len"]["anoms"]
        payload_anoms = res["payload"]["anoms"]
        inv = res["invalid"]

        if not rate_anoms and not len_anoms and not payload_anoms:
            continue

        print("\n" + "=" * 80)
        print(f"PGN {pgn} ({res['count']} msgs) {res['label']}")
        if res["rate"]["has_time"]:
            print(f"  Rate: median Δt={res['rate']['median']:.3f}, MAD={res['rate']['mad']:.3f}, anomalies={len(rate_anoms)}")
        else:
            print("  Rate: timestamps not detected (can still do payload anomalies).")

        print(f"  Payload: median HD={res['payload']['median']:.3f}, MAD={res['payload']['mad']:.3f}, anomalies={len(payload_anoms)}")
        print(f"  Length: common={res['len']['common']} bytes, anomalies={len(len_anoms)}")
        if inv["all_ff"] or inv["all_00"]:
            print(f"  Invalid-pattern counts: all-FF={inv['all_ff']}, all-00={inv['all_00']}")

        # print a few examples
        for prev, cur, d in rate_anoms[:3]:
            print(f"    [RATE] lines {prev.line_no}->{cur.line_no} Δt={d:.3f}  {prev.t_raw}->{cur.t_raw}")
        for m in len_anoms[:3]:
            print(f"    [LEN ] line {m.line_no} len={len(m.data)} data={m.data.hex(' ')}")
        for prev, cur, hd in payload_anoms[:3]:
            print(f"    [PAY ] lines {prev.line_no}->{cur.line_no} HD={hd}  {prev.data.hex(' ')} -> {cur.data.hex(' ')}")

    print("\nDone.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

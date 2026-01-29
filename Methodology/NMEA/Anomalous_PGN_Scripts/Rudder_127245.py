#!/usr/bin/env python3
"""
rudder.py
-------------
Cross-platform rudder (PGN 127245) delta anomaly detector.

Inputs supported:
  1) --candump : raw candump log -> candump2analyzer -> analyzer -json
  2) --jsonl   : analyzer -json output (JSONL)
  3) --text    : analyzer human-readable text output (lines like: "... 127245 Rudder: ... Position = 0.0 deg")

Anomaly logic:
  - Extract rudder angle points
  - Compute delta between successive angles
  - Flag anomalies via robust threshold using MAD:
        anomaly if |delta - median(delta)| > k * MAD(delta)
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import re
import statistics
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Dict, Iterable, Iterator, List, Optional, Tuple


RUDDER_PGN = 127245


# -----------------------------
# Data structures
# -----------------------------
@dataclass
class RudderPoint:
    t: Optional[float]   # seconds since start (best-effort)
    angle: float         # degrees
    src: Dict            # parsed message for debug


@dataclass
class RudderDelta:
    t_prev: Optional[float]
    t_curr: Optional[float]
    angle_prev: float
    angle_curr: float
    delta: float
    msg_prev: Dict
    msg_curr: Dict


# -----------------------------
# Helper: locate canboat binaries
# -----------------------------
def _which(name: str) -> Optional[str]:
    from shutil import which
    return which(name)


def detect_canboat_binaries(
    analyzer_arg: Optional[str],
    candump2analyzer_arg: Optional[str],
) -> Tuple[str, str]:
    if candump2analyzer_arg and analyzer_arg:
        return candump2analyzer_arg, analyzer_arg

    env_c2a = os.environ.get("CANBOAT_CANDUMP2ANALYZER")
    env_an = os.environ.get("CANBOAT_ANALYZER")
    if env_c2a and env_an:
        return env_c2a, env_an

    here = Path(__file__).resolve().parent
    is_win = platform.system().lower().startswith("win")

    if is_win:
        cand = here / "tools" / "canboat" / "candump2analyzer.exe"
        ana = here / "tools" / "canboat" / "analyzer.exe"
        if cand.exists() and ana.exists():
            return str(cand), str(ana)
    else:
        cand = here / "tools" / "canboat-src" / "candump2analyzer"
        ana = here / "tools" / "canboat-src" / "analyzer"
        if cand.exists() and ana.exists():
            return str(cand), str(ana)

    if is_win:
        cand = _which("candump2analyzer.exe") or _which("candump2analyzer")
        ana = _which("analyzer.exe") or _which("analyzer")
    else:
        cand = _which("candump2analyzer")
        ana = _which("analyzer")

    if cand and ana:
        return cand, ana

    raise FileNotFoundError(
        "Could not locate canboat binaries.\n"
        "- Linux/Codespaces: build canboat (make) and ensure tools/canboat-src/analyzer and candump2analyzer exist.\n"
        "- Windows: ensure analyzer.exe and candump2analyzer.exe exist and are on PATH or pass explicit paths.\n"
        "- Or set env vars: CANBOAT_CANDUMP2ANALYZER and CANBOAT_ANALYZER."
    )


# -----------------------------
# Running analyzer pipeline (candump -> jsonl)
# -----------------------------
def run_analyzer_jsonl(
    candump_log: Path,
    candump2analyzer_path: str,
    analyzer_path: str,
) -> Iterator[Dict]:
    if not candump_log.exists():
        raise FileNotFoundError(f"candump log not found: {candump_log}")

    with candump_log.open("rb") as f_in:
        p1 = subprocess.Popen(
            [candump2analyzer_path],
            stdin=f_in,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        p2 = subprocess.Popen(
            [analyzer_path, "-json"],
            stdin=p1.stdout,  # type: ignore[arg-type]
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

        assert p2.stdout is not None
        for raw in p2.stdout:
            line = raw.decode("utf-8", errors="ignore").strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue

        _, err2 = p2.communicate()
        err1 = p1.stderr.read() if p1.stderr else b""
        rc1 = p1.wait()
        rc2 = p2.returncode

    if rc1 != 0:
        raise RuntimeError(f"candump2analyzer failed (exit {rc1}).\n{err1.decode(errors='ignore')}")
    if rc2 != 0:
        raise RuntimeError(f"analyzer failed (exit {rc2}).\n{err2.decode(errors='ignore')}")


def read_jsonl_file(path: Path) -> Iterator[Dict]:
    if not path.exists():
        raise FileNotFoundError(f"jsonl not found: {path}")
    with path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


# -----------------------------
# NEW: parse analyzer human-readable text lines
# Example (from your file):
# 2025-12-16-17:47:58.753 ... 127245 Rudder: ... Position = 0.0 deg
# -----------------------------
_TS_FMT = "%Y-%m-%d-%H:%M:%S.%f"

# Capture timestamp + PGN + name + fields
_LINE_RE = re.compile(
    r"^(?P<ts>\d{4}-\d{2}-\d{2}-\d{2}:\d{2}:\d{2}\.\d+)\s+"
    r".*?\s(?P<pgn>\d{5,6})\s+(?P<name>[^:]+):\s*(?P<fields>.*)$"
)


def _parse_ts_to_seconds(ts: str, t0: Optional[datetime]) -> Tuple[Optional[float], Optional[datetime]]:
    try:
        dt = datetime.strptime(ts, _TS_FMT)
    except ValueError:
        return None, t0
    if t0 is None:
        return 0.0, dt
    return (dt - t0).total_seconds(), t0


def _parse_fields_text(fields_blob: str) -> Dict[str, str]:
    """
    fields look like:
      "Instance = 0; Direction Order = No Order; ...; Position = 0.0 deg"
    """
    out: Dict[str, str] = {}
    parts = [p.strip() for p in fields_blob.split(";") if p.strip()]
    for part in parts:
        if "=" in part:
            k, v = part.split("=", 1)
            out[k.strip()] = v.strip()
    return out


def read_analyzer_text_file(path: Path) -> Iterator[Dict]:
    """
    Emits dicts shaped similarly to JSON analyzer output:
      {"pgn": int, "timestamp": float|None, "name": str, "fields": {k: v, ...}}
    """
    if not path.exists():
        raise FileNotFoundError(f"text file not found: {path}")

    t0: Optional[datetime] = None

    with path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            m = _LINE_RE.match(line)
            if not m:
                continue

            ts = m.group("ts")
            pgn = int(m.group("pgn"))
            name = m.group("name").strip()
            fields_blob = m.group("fields").strip()

            t_sec, t0 = _parse_ts_to_seconds(ts, t0)
            fields = _parse_fields_text(fields_blob)

            yield {
                "pgn": pgn,
                "timestamp": t_sec,
                "name": name,
                "fields": fields,
                "_raw": line,
            }


# -----------------------------
# Rudder extraction
# -----------------------------
def _get_pgn(msg: Dict) -> Optional[int]:
    v = msg.get("pgn")
    if isinstance(v, int):
        return v
    if isinstance(v, str) and v.isdigit():
        return int(v)
    return None


def _get_timestamp(msg: Dict) -> Optional[float]:
    v = msg.get("timestamp")
    if isinstance(v, (int, float)):
        return float(v)
    return None


def _coerce_deg(v: object) -> Optional[float]:
    if isinstance(v, (int, float)):
        return float(v)
    if isinstance(v, str):
        s = v.strip().lower()
        for junk in ("degrees", "degree", "deg", "°"):
            s = s.replace(junk, "")
        s = s.strip()
        try:
            return float(s)
        except ValueError:
            return None
    return None


def extract_rudder_points(messages: Iterable[Dict]) -> List[RudderPoint]:
    """
    Supports both:
      - JSON analyzer output (fields dict contains 'Rudder Angle' or similar)
      - analyzer text output (fields dict contains 'Position' like: '0.0 deg')  :contentReference[oaicite:1]{index=1}
    """
    points: List[RudderPoint] = []

    # Try common rudder keys (JSON) + 'Position' (text format)
    candidates = [
        "Rudder Angle",
        "Rudder angle",
        "rudderAngle",
        "rudder_angle",
        "Rudder Position",
        "Position",  # <-- this is what your analyzer text uses :contentReference[oaicite:2]{index=2}
        "Angle",
        "angle",
    ]

    for msg in messages:
        if _get_pgn(msg) != RUDDER_PGN:
            continue

        t = _get_timestamp(msg)

        fields = msg.get("fields")
        angle: Optional[float] = None

        if isinstance(fields, dict):
            for k in candidates:
                if k in fields:
                    angle = _coerce_deg(fields.get(k))
                    if angle is not None:
                        break

        if angle is None:
            continue

        points.append(RudderPoint(t=t, angle=float(angle), src=msg))

    if any(p.t is not None for p in points):
        points.sort(key=lambda p: (p.t is None, p.t))
    return points


# -----------------------------
# Delta + anomaly detection
# -----------------------------
def compute_deltas(points: List[RudderPoint]) -> List[RudderDelta]:
    deltas: List[RudderDelta] = []
    for i in range(1, len(points)):
        a0 = points[i - 1].angle
        a1 = points[i].angle
        deltas.append(
            RudderDelta(
                t_prev=points[i - 1].t,
                t_curr=points[i].t,
                angle_prev=a0,
                angle_curr=a1,
                delta=(a1 - a0),
                msg_prev=points[i - 1].src,
                msg_curr=points[i].src,
            )
        )
    return deltas


def median_absolute_deviation(values: List[float]) -> float:
    if not values:
        return 0.0
    med = statistics.median(values)
    devs = [abs(x - med) for x in values]
    return float(statistics.median(devs))


def flag_anomalies_mad(deltas: List[RudderDelta], k: float) -> Tuple[float, float, List[Tuple[int, RudderDelta]]]:
    vals = [d.delta for d in deltas]
    if not vals:
        return 0.0, 0.0, []

    med = float(statistics.median(vals))
    mad = median_absolute_deviation(vals)

    eps = 1e-9
    thresh = k * (mad if mad > 0 else eps)

    anomalies: List[Tuple[int, RudderDelta]] = []
    for i, d in enumerate(deltas):
        if abs(d.delta - med) > thresh:
            anomalies.append((i, d))
    return med, mad, anomalies


def fmt_time(t: Optional[float]) -> str:
    return "NA" if t is None else f"{t:.3f}"


def print_summary(points: List[RudderPoint], deltas: List[RudderDelta], med: float, mad: float, k: float, anomalies: List[Tuple[int, RudderDelta]]) -> None:
    print(f"\nRudder PGN points found: {len(points)}")
    print(f"Rudder deltas computed:  {len(deltas)}")
    print(f"Delta median:           {med:.6f}")
    print(f"Delta MAD:              {mad:.6f}")
    print(f"Anomaly threshold:      |delta - median| > {k} * MAD\n")

    if not anomalies:
        print("No anomalies flagged.")
        return

    print(f"ANOMALIES FLAGGED: {len(anomalies)}")
    print("-" * 90)
    print("idx | t_prev   -> t_curr   | angle_prev -> angle_curr | delta")
    print("-" * 90)
    for idx, d in anomalies[:200]:
        print(
            f"{idx:3d} | {fmt_time(d.t_prev):>7} -> {fmt_time(d.t_curr):>7} | "
            f"{d.angle_prev:>10.4f} -> {d.angle_curr:>10.4f} | {d.delta:>10.6f}"
        )
    if len(anomalies) > 200:
        print(f"... (showing first 200 of {len(anomalies)})")


def write_anomalies_csv(path: Path, anomalies: List[Tuple[int, RudderDelta]], med: float, mad: float, k: float) -> None:
    import csv
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["idx", "t_prev", "t_curr", "angle_prev", "angle_curr", "delta", "median", "mad", "k"])
        for idx, d in anomalies:
            w.writerow([idx, d.t_prev, d.t_curr, d.angle_prev, d.angle_curr, d.delta, med, mad, k])


# -----------------------------
# Main
# -----------------------------
def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Detect rudder delta anomalies (PGN 127245) from candump/jsonl/analyzer-text.")
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--candump", type=str, help="Raw candump log file (frames).")
    src.add_argument("--jsonl", type=str, help="Analyzer -json output (JSONL).")
    src.add_argument("--text", type=str, help="Analyzer human-readable text output (.txt).")

    p.add_argument("--candump2analyzer", type=str, default=None, help="Path to candump2analyzer (or .exe).")
    p.add_argument("--analyzer", type=str, default=None, help="Path to analyzer (or .exe).")

    p.add_argument("--k", type=float, default=8.0, help="MAD multiplier for anomaly threshold (default: 8.0).")
    p.add_argument("--min-points", type=int, default=20, help="Minimum rudder points needed (default: 20).")

    p.add_argument("--csv", type=str, default=None, help="Write anomalies CSV to this path.")
    p.add_argument("--debug", action="store_true", help="Print extra debug info.")
    return p.parse_args()


def main() -> int:
    args = parse_args()

    if args.jsonl:
        msg_iter = read_jsonl_file(Path(args.jsonl))
        source_desc = f"JSONL file: {args.jsonl}"
    elif args.text:
        msg_iter = read_analyzer_text_file(Path(args.text))
        source_desc = f"Analyzer text file: {args.text}"
    else:
        candump2analyzer_path, analyzer_path = detect_canboat_binaries(args.analyzer, args.candump2analyzer)
        if args.debug:
            print(f"[debug] candump2analyzer: {candump2analyzer_path}")
            print(f"[debug] analyzer:        {analyzer_path}")
        msg_iter = run_analyzer_jsonl(Path(args.candump), candump2analyzer_path, analyzer_path)
        source_desc = f"candump log: {args.candump}"

    print(f"Source: {source_desc}")
    print("Extracting rudder points (PGN 127245)...")

    msgs = list(msg_iter)
    points = extract_rudder_points(msgs)

    if len(points) < args.min_points:
        print(f"Not enough rudder points: {len(points)} found; need at least {args.min_points}.")
        return 2

    deltas = compute_deltas(points)
    med, mad, anomalies = flag_anomalies_mad(deltas, k=float(args.k))

    print_summary(points, deltas, med, mad, float(args.k), anomalies)

    if args.csv:
        write_anomalies_csv(Path(args.csv), anomalies, med, mad, float(args.k))
        print(f"\nWrote anomalies CSV: {args.csv}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

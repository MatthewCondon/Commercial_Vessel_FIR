import json
import subprocess
from dataclasses import dataclass
from typing import Optional, Dict, Any, Iterable, List

PGN_RUDDER = 127245

# Adjust these to your environment
CANBOAT_DIR = r"C:\canboat"  # folder containing analyzer.exe and candump2analyzer.exe
ANALYZER_EXE = CANBOAT_DIR + r"\analyzer.exe"
C2A_EXE = CANBOAT_DIR + r"\candump2analyzer.exe"

# Your input log file (candump-style or whatever candump2analyzer supports)
INPUT_LOG = r"C:\path\to\candump.log"

# Detection config
DELTA_THRESHOLD_DEG = 2.0  # flag if absolute delta between successive rudder points exceeds this (degrees)
MAX_EVENTS_PRINT = 50      # keep console sane

# If canboat field names vary, we try several likely keys.
# You can print msg["fields"].keys() once to confirm the exact name on your data.
RUDDER_FIELD_CANDIDATES = [
    "Rudder Position",
    "RudderPosition",
    "Position",
    "Rudder Angle",
    "RudderAngle",
]


@dataclass
class RudderPoint:
    timestamp: str
    src: int
    dst: int
    rudder_deg: float
    raw: Dict[str, Any]


def run_analyzer_json(input_log: str) -> Iterable[Dict[str, Any]]:
    """
    Runs: type <log> | candump2analyzer | analyzer -json
    and yields parsed JSON objects line-by-line.
    """
    # Use PowerShell so piping is straightforward on Windows
    ps_cmd = (
        f'Get-Content -Path "{input_log}" | '
        f'& "{C2A_EXE}" | '
        f'& "{ANALYZER_EXE}" -json'
    )

    proc = subprocess.Popen(
        ["powershell", "-NoProfile", "-Command", ps_cmd],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
    )

    # analyzer -json outputs one JSON object per line
    assert proc.stdout is not None
    for line in proc.stdout:
        line = line.strip()
        if not line:
            continue
        try:
            yield json.loads(line)
        except json.JSONDecodeError:
            # Some lines might be non-JSON (rare); skip safely
            continue

    # Drain stderr for debugging if needed
    stderr = proc.stderr.read() if proc.stderr else ""
    rc = proc.wait()
    if rc != 0:
        raise RuntimeError(f"Analyzer pipeline failed (exit {rc}). Stderr:\n{stderr}")


def get_rudder_angle_deg(fields: Dict[str, Any]) -> Optional[float]:
    """
    Tries to find rudder angle in degrees from decoded canboat fields.
    Returns float if found, else None.
    """
    for key in RUDDER_FIELD_CANDIDATES:
        if key in fields and fields[key] is not None:
            val = fields[key]
            # canboat often gives numbers directly; sometimes nested {"value":..., "name":...} in -nv mode
            if isinstance(val, (int, float)):
                return float(val)
            if isinstance(val, dict) and "value" in val and isinstance(val["value"], (int, float)):
                return float(val["value"])

    # Fallback: try to find *any* numeric field that looks like rudder position
    # (useful if field naming differs)
    for k, v in fields.items():
        if isinstance(k, str) and "rudder" in k.lower():
            if isinstance(v, (int, float)):
                return float(v)
            if isinstance(v, dict) and "value" in v and isinstance(v["value"], (int, float)):
                return float(v["value"])
    return None


def extract_rudder_points(messages: Iterable[Dict[str, Any]]) -> List[RudderPoint]:
    points: List[RudderPoint] = []
    for msg in messages:
        # Skip initial version line if present
        if "version" in msg and "units" in msg:
            continue

        pgn = msg.get("pgn")
        if pgn != PGN_RUDDER:
            continue

        fields = msg.get("fields") or {}
        angle = get_rudder_angle_deg(fields)
        if angle is None:
            continue

        points.append(
            RudderPoint(
                timestamp=str(msg.get("timestamp", "")),
                src=int(msg.get("src", -1)),
                dst=int(msg.get("dst", -1)),
                rudder_deg=float(angle),
                raw=msg,
            )
        )
    return points


def detect_delta_anomalies(points: List[RudderPoint], threshold_deg: float):
    anomalies = []
    prev = None
    for p in points:
        if prev is None:
            prev = p
            continue
        delta = abs(p.rudder_deg - prev.rudder_deg)
        if delta > threshold_deg:
            anomalies.append((p, prev, delta))
        prev = p
    return anomalies


def main():
    print("Running canboat analyzer -> JSON -> rudder delta anomalies...")
    msgs = run_analyzer_json(INPUT_LOG)

    points = extract_rudder_points(msgs)
    if len(points) < 2:
        print("Not enough rudder points found to compute deltas.")
        return

    anomalies = detect_delta_anomalies(points, DELTA_THRESHOLD_DEG)

    print(f"Total rudder points: {len(points)}")
    print(f"Delta threshold: {DELTA_THRESHOLD_DEG} deg")
    print(f"Anomalies found: {len(anomalies)}")

    # Print a few anomalies
    for i, (cur, prev, delta) in enumerate(anomalies[:MAX_EVENTS_PRINT], 1):
        print(
            f"[{i}] {cur.timestamp} src={cur.src} dst={cur.dst} "
            f"rudder={cur.rudder_deg:.3f} deg (prev {prev.rudder_deg:.3f}) delta={delta:.3f}"
        )

    # Helpful: show what field names are actually present (first message)
    # so you can lock in the exact rudder field key.
    sample_fields = points[0].raw.get("fields", {})
    print("\nSample decoded field keys (first rudder message):")
    for k in sample_fields.keys():
        print(f"  - {k}")


if __name__ == "__main__":
    main()

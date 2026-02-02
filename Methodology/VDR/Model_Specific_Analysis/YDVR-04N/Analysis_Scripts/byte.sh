#!/usr/bin/env bash
# ydvr_extract.sh — YDVR-04N .DAT -> extract CAN29 frames, write ONLY a zip: <basename>.zip
#
# What it does:
#   - Extracts frames from record types (default 0x4A,0x4B,0x4C)
#   - Produces 4 outputs inside a temp dir:
#       <base>_socketcan.log
#       <base>_compact.txt
#       <base>_csv.csv
#       <base>_decoded.txt
#   - Zips them into: <base>.zip
#   - Deletes the temp dir so NO loose output files remain (zip only)
#
# Timestamp modes:
#   --mode 1  => REAL ONLY (strict): only PGN 126992 yields timestamps; others blank/NA (not dropped)
#   --mode 2  => INFERRED: uses real anchors when present; otherwise fills using interpolation by offset,
#                or fixed per-frame delta if only one anchor exists.
#
# Usage:
#   ./ydvr_extract.sh 00010001.DAT --mode 2
#   ./ydvr_extract.sh /path/to/00010001.DAT --mode 1
#
# Options:
#   --mode 1|2              (default 2)
#   --types "4A,4B,4C"      (default "4A,4B,4C")
#   --iface can0            (default can0)
#   --channel 2             (default 2)
#   --default-delta-us 1000 (default 1000us; inferred mode only)
#   --limit N               (default 0 = no limit)
#
set -euo pipefail

MODE=2
TYPES="4A,4B,4C"
IFACE="can0"
CHANNEL=2
DEFAULT_DELTA_US=1000
LIMIT=0

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <input.DAT> [--mode 1|2] [--types \"4A,4B,4C\"] [--iface can0] [--channel 2] [--default-delta-us 1000] [--limit N]" >&2
  exit 1
fi

INFILE="$1"; shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    --types) TYPES="${2:-}"; shift 2 ;;
    --iface) IFACE="${2:-}"; shift 2 ;;
    --channel) CHANNEL="${2:-}"; shift 2 ;;
    --default-delta-us) DEFAULT_DELTA_US="${2:-}"; shift 2 ;;
    --limit) LIMIT="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '1,120p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$INFILE" ]]; then
  echo "Input file not found: $INFILE" >&2
  exit 1
fi

if [[ "$MODE" != "1" && "$MODE" != "2" ]]; then
  echo "--mode must be 1 or 2" >&2
  exit 1
fi

BASE="$(basename "$INFILE")"
BASE="${BASE%.*}"
ZIPNAME="${BASE}.zip"

# Temp output dir (hidden)
OUTDIR="$(mktemp -d ".${BASE}_out_XXXXXX")"

# Ensure cleanup on error too (but keep zip if already created)
cleanup() {
  if [[ -d "$OUTDIR" ]]; then
    rm -rf "$OUTDIR"
  fi
}
trap cleanup EXIT

export INFILE MODE TYPES IFACE CHANNEL DEFAULT_DELTA_US LIMIT BASE OUTDIR ZIPNAME

python3 - <<'PY'
import os, sys, struct, zipfile
from dataclasses import dataclass
from typing import List, Optional, Tuple
from datetime import datetime, timedelta, timezone
from collections import Counter

INFILE = os.environ["INFILE"]
MODE = int(os.environ["MODE"])
TYPES = os.environ["TYPES"]
IFACE = os.environ["IFACE"]
CHANNEL = int(os.environ["CHANNEL"])
DEFAULT_DELTA_US = int(os.environ["DEFAULT_DELTA_US"])
LIMIT = int(os.environ["LIMIT"])
BASE = os.environ["BASE"]
OUTDIR = os.environ["OUTDIR"]
ZIPNAME = os.environ["ZIPNAME"]

CAN_EFF_MASK = 0x1FFFFFFF

KNOWN_PGNS = {
    59392: "ISO Acknowledgment",
    59904: "ISO Request",
    60928: "ISO Address Claim",
    126992: "System Time",
    127245: "Rudder",
    127250: "Vessel Heading",
    127251: "Rate of Turn",
    127252: "Heave",
    127488: "Engine Parameters, Rapid Update",
    127489: "Engine Parameters, Dynamic",
    127493: "Transmission Parameters, Dynamic",
    128259: "Speed, Water Referenced",
    128267: "Water Depth",
    129025: "Position, Rapid Update",
    129026: "COG & SOG, Rapid Update",
    129029: "GNSS Position Data",
    129038: "AIS Class A Position Report",
    129039: "AIS Class B Position Report",
    130306: "Wind Data",
    130310: "Environmental Parameters",
    130311: "Environmental Parameters (2)",
    130312: "Temperature",
    130316: "Temperature, Extended Range",
    130576: "Small Craft Status",
}

def parse_types(s: str) -> List[int]:
    parts = [p.strip() for p in s.replace(" ", ",").split(",") if p.strip()]
    return [int(p.lower().replace("0x",""), 16) for p in parts]

@dataclass(frozen=True)
class Frame:
    offset: int
    seq: int
    rtype: int
    can_id_raw: int
    data8: bytes

    @property
    def can_id_29(self) -> int:
        return self.can_id_raw & CAN_EFF_MASK

    @property
    def priority(self) -> int:
        return (self.can_id_29 >> 26) & 0x7

    @property
    def dp(self) -> int:
        return (self.can_id_29 >> 24) & 0x1

    @property
    def pf(self) -> int:
        return (self.can_id_29 >> 16) & 0xFF

    @property
    def ps(self) -> int:
        return (self.can_id_29 >> 8) & 0xFF

    @property
    def src(self) -> int:
        return self.can_id_29 & 0xFF

    @property
    def dst(self) -> int:
        return self.ps if self.pf < 240 else 255

    @property
    def pgn(self) -> int:
        if self.pf < 240:
            return (self.dp << 16) | (self.pf << 8)
        return (self.dp << 16) | (self.pf << 8) | self.ps

def plausible_can29(can_id_29: int) -> bool:
    if can_id_29 == 0:
        return False
    if (can_id_29 & 0xFF) == 0xFF:
        return False
    return True

def extract_frames(buf: bytes, rtypes: List[int]) -> List[Frame]:
    want = set(rtypes)
    n = len(buf)
    i = 0
    frames: List[Frame] = []

    def parse_synced(at: int) -> Optional[Frame]:
        if at + 16 > n:
            return None
        if buf[at] != 0xFF or buf[at+1] != 0xFF:
            return None
        seq = buf[at+2]
        rtype = buf[at+3]
        if rtype not in want:
            return None
        can_id_raw = struct.unpack_from("<I", buf, at+4)[0]
        if not plausible_can29(can_id_raw & CAN_EFF_MASK):
            return None
        data8 = buf[at+8:at+16]
        return Frame(offset=at, seq=seq, rtype=rtype, can_id_raw=can_id_raw, data8=data8)

    def parse_packed(at: int) -> Optional[Frame]:
        if at + 14 > n:
            return None
        seq = buf[at]
        rtype = buf[at+1]
        if rtype not in want:
            return None
        can_id_raw = struct.unpack_from("<I", buf, at+2)[0]
        if not plausible_can29(can_id_raw & CAN_EFF_MASK):
            return None
        data8 = buf[at+6:at+14]
        return Frame(offset=at, seq=seq, rtype=rtype, can_id_raw=can_id_raw, data8=data8)

    while i < n:
        f = parse_synced(i)
        if f:
            frames.append(f)
            i += 16
            while True:
                g = parse_packed(i)
                if not g:
                    break
                frames.append(g)
                i += 14
            continue
        i += 1

    frames.sort(key=lambda x: x.offset)
    return frames

def fmt_ts_ms(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d-%H:%M:%S.%f")[:-3]

def decode_time_126992(data8: bytes) -> Optional[datetime]:
    # Strict, common decode:
    # bytes[2:4] u16 days since 1970-01-01 (LE)
    # bytes[4:8] u32 time-of-day in 0.0001s (LE)
    if len(data8) != 8:
        return None
    days = struct.unpack_from("<H", data8, 2)[0]
    tod_1e4 = struct.unpack_from("<I", data8, 4)[0]
    if days in (0xFFFF, 0xFFFE) or tod_1e4 in (0xFFFFFFFF, 0xFFFFFFFE):
        return None
    base = datetime(1970, 1, 1, tzinfo=timezone.utc) + timedelta(days=int(days))
    seconds = tod_1e4 / 10000.0
    if not (0.0 <= seconds < 86402.0):
        return None
    return base + timedelta(seconds=seconds)

def real_timestamp_utc(f: Frame) -> Optional[datetime]:
    if f.pgn == 126992:
        return decode_time_126992(f.data8)
    return None

def build_inferred_timeline(frames: List[Frame], default_delta_us: int) -> List[Optional[datetime]]:
    n = len(frames)
    ts_real: List[Optional[datetime]] = [None] * n
    anchors: List[Tuple[int,int,datetime]] = []

    for i, f in enumerate(frames):
        t = real_timestamp_utc(f)
        ts_real[i] = t
        if t is not None:
            anchors.append((i, f.offset, t))

    if not anchors:
        return ts_real

    ts_out = ts_real[:]
    delta = timedelta(microseconds=int(default_delta_us))

    if len(anchors) == 1:
        idx0, off0, t0 = anchors[0]
        # forward
        cur = t0
        for i in range(idx0, n):
            if ts_out[i] is None:
                ts_out[i] = cur
            cur = (ts_out[i] if ts_out[i] is not None else cur) + delta
        # backward
        cur = t0
        for i in range(idx0, -1, -1):
            if ts_out[i] is None:
                ts_out[i] = cur
            cur = (ts_out[i] if ts_out[i] is not None else cur) - delta
        return ts_out

    anchors.sort(key=lambda x: x[1])

    # before first anchor: step back by delta
    idx_first, off_first, t_first = anchors[0]
    cur = t_first
    for i in range(idx_first, -1, -1):
        if ts_out[i] is None:
            ts_out[i] = cur
        cur = (ts_out[i] if ts_out[i] is not None else cur) - delta

    # after last anchor: step forward by delta
    idx_last, off_last, t_last = anchors[-1]
    cur = t_last
    for i in range(idx_last, n):
        if ts_out[i] is None:
            ts_out[i] = cur
        cur = (ts_out[i] if ts_out[i] is not None else cur) + delta

    # between anchors: interpolate by offset
    for a in range(len(anchors) - 1):
        i0, o0, t0 = anchors[a]
        i1, o1, t1 = anchors[a+1]
        if o1 == o0:
            continue
        span_us = (t1 - t0).total_seconds() * 1_000_000.0
        for i in range(i0+1, i1):
            if ts_out[i] is not None:
                continue
            oi = frames[i].offset
            frac = (oi - o0) / (o1 - o0)
            ts_out[i] = t0 + timedelta(microseconds=span_us * frac)

    return ts_out

def write_outputs(frames: List[Frame], ts_list: List[Optional[datetime]]):
    out_socketcan = os.path.join(OUTDIR, f"{BASE}_socketcan.log")
    out_compact   = os.path.join(OUTDIR, f"{BASE}_compact.txt")
    out_csv       = os.path.join(OUTDIR, f"{BASE}_csv.csv")
    out_decoded   = os.path.join(OUTDIR, f"{BASE}_decoded.txt")

    c = 0
    with open(out_socketcan, "w", encoding="utf-8") as fsock, \
         open(out_compact, "w", encoding="utf-8") as fcmp, \
         open(out_csv, "w", encoding="utf-8") as fcsv, \
         open(out_decoded, "w", encoding="utf-8") as fdec:

        fdec.write("# Offset | Type | Seq | TS(UTC) | CANID29 | PGN | Pri | Src | Dst | Data | Name\n")
        fdec.write("-" * 140 + "\n")

        for i, f in enumerate(frames):
            if LIMIT and c >= LIMIT:
                break
            ts = ts_list[i]
            ts_str = "" if ts is None else fmt_ts_ms(ts)
            epoch = "NA" if ts is None else f"{ts.timestamp():.6f}"

            canid_hex = f"{f.can_id_29:08X}"
            payload_hex_sp = " ".join(f"{b:02X}" for b in f.data8)
            payload_hex = f.data8.hex().upper()

            # raw socketcan
            fsock.write(f"({epoch}) {IFACE} {canid_hex}#{payload_hex}\n")

            # compact
            fcmp.write(f"{IFACE}  {canid_hex}   [8]  {payload_hex_sp}\n")

            # csv: ts,channel,pgn,priority,src,dst,len,b0..b7 (lower hex)
            b = [f"{x:02x}" for x in f.data8]
            fcsv.write(",".join([
                ts_str,
                str(CHANNEL),
                str(f.pgn),
                str(f.priority),
                str(f.src),
                str(f.dst),
                "8",
                *b
            ]) + "\n")

            # decoded table
            name = KNOWN_PGNS.get(f.pgn, "Unknown")
            fdec.write(
                f"{f.offset:08X} | 0x{f.rtype:02X} | {f.seq:02X} | {ts_str:23s} | {canid_hex} | "
                f"{f.pgn:6d} | {f.priority} | {f.src:3d} | {f.dst:3d} | {payload_hex_sp:<23s} | {name}\n"
            )
            c += 1

    return [out_socketcan, out_compact, out_csv, out_decoded], c

def make_zip(zipname: str, files: List[str]):
    with zipfile.ZipFile(zipname, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for f in files:
            z.write(f, arcname=os.path.basename(f))

def stats(frames: List[Frame]):
    pgn_hist = Counter(f.pgn for f in frames)
    rt_hist = Counter(f.rtype for f in frames)
    anchors = sum(1 for f in frames if real_timestamp_utc(f) is not None)

    print(f"[+] Extracted frames: {len(frames)}")
    print("[+] By record type:")
    for rt, cnt in sorted(rt_hist.items()):
        print(f"    0x{rt:02X}: {cnt}")
    print(f"[+] Real time anchors (PGN 126992 decode): {anchors}")
    print("[+] Top PGNs:")
    for pgn, cnt in pgn_hist.most_common(20):
        nm = KNOWN_PGNS.get(pgn, "Unknown")
        print(f"    {pgn:6d}  {nm[:45]:45s}  {cnt}")

def main():
    with open(INFILE, "rb") as f:
        buf = f.read()

    rtypes = parse_types(TYPES)
    frames = extract_frames(buf, rtypes)

    print(f"[+] File: {INFILE}")
    print(f"[+] Size: {len(buf):,} bytes")
    print(f"[+] Types: {', '.join('0x%02X'%t for t in rtypes)}")
    print(f"[+] Mode: {MODE} ({'real-only' if MODE==1 else 'inferred'})")

    stats(frames)

    if MODE == 1:
        ts_list = [real_timestamp_utc(f) for f in frames]
    else:
        ts_list = build_inferred_timeline(frames, default_delta_us=DEFAULT_DELTA_US)

    files, written = write_outputs(frames, ts_list)

    make_zip(ZIPNAME, files)

    # Print only what matters (zip)
    print(f"[+] Wrote {written} frames into zip: {ZIPNAME}")

if __name__ == "__main__":
    main()
PY

# At this point python has written files into $OUTDIR and zipped them into $ZIPNAME.
# Now remove temp output dir, leaving ONLY the zip.
rm -rf "$OUTDIR"
trap - EXIT

echo "[+] Done. Only output: $ZIPNAME"

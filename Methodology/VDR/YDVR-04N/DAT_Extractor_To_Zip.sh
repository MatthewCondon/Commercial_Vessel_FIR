#!/usr/bin/env bash
# ydvr_extract.sh — YDVR-04N .DAT -> extract CAN29 frames, write zips
#
# What it does:
#   - Accepts a single .DAT file OR a directory containing multiple .DAT files
#   - Extracts frames from record types (default 0x4A,0x4B,0x4C)
#   - Always produces exactly ONE zip file:
#       Single input : <base>.zip
#       Multiple inputs: combined_<timestamp>.zip
#     The zip contains four files — raw data only, no headers or separators:
#       socketcan.log    — SocketCAN log format, frames in time order
#       compact.txt      — candump compact format, frames in time order
#       data.csv         — CSV, frames in time order
#       decoded.txt      — human-readable decoded table, frames in time order
#   - Deletes all temp dirs so NO loose output files remain (zip only)
#
# Timestamp modes:
#   --mode 1  => VDR REAL (default-like behaviour of YDVR Converter / Actisense NMEA Reader):
#                PGN 126992 frames are the authoritative UTC wall-clock anchors. Every other
#                frame on the bus is timestamped by linear interpolation between the two
#                surrounding 126992 anchors (by frame index). Frames before the first anchor
#                or after the last anchor are left blank/NA — no extrapolation is performed,
#                because there is no verified clock reference to extrapolate from.
#   --mode 2  => INFERRED: same anchor-based interpolation as mode 1, but additionally
#                extrapolates outside the anchored region using the mean inter-anchor rate
#                (or --default-delta-us when <2 anchors). Useful when GPS/time source was
#                late to lock or dropped out before the end of the recording.
#
# Usage:
#   ./ydvr_extract.sh 00010001.DAT --mode 2
#   ./ydvr_extract.sh /path/to/recordings/ --mode 2
#   ./ydvr_extract.sh /path/to/00010001.DAT --mode 1
#
# Options:
#   --mode 1|2              (default 2)
#   --types "4A,4B,4C"      (default "4A,4B,4C")
#   --iface can0            (default can0)
#   --channel 2             (default 2)
#   --default-delta-us 1000 (default 1000us; inferred mode fallback only)
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
  echo "Usage: $0 <input.DAT | directory> [--mode 1|2] [--types \"4A,4B,4C\"] [--iface can0] [--channel 2] [--default-delta-us 1000] [--limit N]" >&2
  exit 1
fi

INPUT="$1"; shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)             MODE="${2:-}";             shift 2 ;;
    --types)            TYPES="${2:-}";            shift 2 ;;
    --iface)            IFACE="${2:-}";            shift 2 ;;
    --channel)          CHANNEL="${2:-}";          shift 2 ;;
    --default-delta-us) DEFAULT_DELTA_US="${2:-}"; shift 2 ;;
    --limit)            LIMIT="${2:-}";            shift 2 ;;
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

if [[ "$MODE" != "1" && "$MODE" != "2" ]]; then
  echo "--mode must be 1 or 2" >&2
  exit 1
fi

# ── Collect input files ──────────────────────────────────────────────────────

declare -a INFILES=()

if [[ -d "$INPUT" ]]; then
  while IFS= read -r -d '' f; do
    INFILES+=("$f")
  done < <(find "$INPUT" -maxdepth 1 -iname "*.dat" -type f -print0 | sort -z)
  if [[ ${#INFILES[@]} -eq 0 ]]; then
    echo "No .DAT files found in directory: $INPUT" >&2
    exit 1
  fi
  echo "[+] Directory mode: found ${#INFILES[@]} .DAT file(s) in $INPUT"
elif [[ -f "$INPUT" ]]; then
  INFILES+=("$INPUT")
else
  echo "Input not found (not a file or directory): $INPUT" >&2
  exit 1
fi

# ── Shared temp dir for all per-file output files ────────────────────────────

SHARED_OUTDIR="$(mktemp -d ".ydvr_shared_out_XXXXXX")"

global_cleanup() {
  [[ -d "$SHARED_OUTDIR" ]] && rm -rf "$SHARED_OUTDIR"
}
trap global_cleanup EXIT

# ── Per-file processing (writes 4 raw data files into SHARED_OUTDIR) ────────

process_file() {
  local INFILE="$1"

  local BASE
  BASE="$(basename "$INFILE")"
  BASE="${BASE%.*}"

  export INFILE MODE TYPES IFACE CHANNEL DEFAULT_DELTA_US LIMIT BASE SHARED_OUTDIR

python3 - <<'PY'
import os, sys, struct, zipfile
from dataclasses import dataclass
from typing import List, Optional, Tuple
from datetime import datetime, timedelta, timezone
from collections import Counter

INFILE          = os.environ["INFILE"]
MODE            = int(os.environ["MODE"])
TYPES           = os.environ["TYPES"]
IFACE           = os.environ["IFACE"]
CHANNEL         = int(os.environ["CHANNEL"])
DEFAULT_DELTA_US= int(os.environ["DEFAULT_DELTA_US"])
LIMIT           = int(os.environ["LIMIT"])
BASE            = os.environ["BASE"]
SHARED_OUTDIR   = os.environ["SHARED_OUTDIR"]

CAN_EFF_MASK = 0x1FFFFFFF

KNOWN_PGNS = {
    59392:  "ISO Acknowledgment",
    59904:  "ISO Request",
    60928:  "ISO Address Claim",
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
    """
    Parse synced records (0xFF 0xFF header, 16 bytes) followed by optional
    packed records (14 bytes, no header sentinel). Sorted by byte offset.
    """
    want = set(rtypes)
    n    = len(buf)
    i    = 0
    frames: List[Frame] = []

    def parse_synced(at: int) -> Optional[Frame]:
        if at + 16 > n:
            return None
        if buf[at] != 0xFF or buf[at+1] != 0xFF:
            return None
        seq        = buf[at+2]
        rtype      = buf[at+3]
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
        seq        = buf[at]
        rtype      = buf[at+1]
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
    """
    NMEA2000 PGN 126992 – System Time
      bytes[0]    SID (ignored)
      bytes[1]    Source (bits 3-0, ignored)
      bytes[2:4]  Days since 1970-01-01, uint16 LE
      bytes[4:8]  Seconds of day × 10000, uint32 LE
    """
    if len(data8) != 8:
        return None
    days    = struct.unpack_from("<H", data8, 2)[0]
    tod_raw = struct.unpack_from("<I", data8, 4)[0]
    if days    in (0xFFFF, 0xFFFE):
        return None
    if tod_raw in (0xFFFFFFFF, 0xFFFFFFFE):
        return None
    base    = datetime(1970, 1, 1, tzinfo=timezone.utc) + timedelta(days=int(days))
    seconds = tod_raw / 10000.0
    if not (0.0 <= seconds < 86402.0):
        return None
    return base + timedelta(seconds=seconds)

def real_timestamp_utc(f: Frame) -> Optional[datetime]:
    if f.pgn == 126992:
        return decode_time_126992(f.data8)
    return None

# ── Timestamp engine ─────────────────────────────────────────────────────────
#
# Shared logic used by both modes:
#
#  • Interpolation always uses FRAME INDEX as the time proxy, not byte offset.
#    Mixed 16-B synced / 14-B packed records mean equal byte-distance ≠ equal
#    time-distance. Frame index is a faithful proxy within a single recording.
#
#  • PGN 126992 anchors that decode to the same UTC second as a previous anchor
#    are discarded (keep first). Duplicate seconds produce zero-length intervals
#    that break interpolation and distort the mean rate calculation.
#
#  • The anchor's own frame always receives the exact decoded UTC time; it is
#    never overwritten by interpolation.
#
# Mode 1 — VDR real (mirrors YDVR Converter / Actisense NMEA Reader behaviour):
#   - Interpolates between every pair of adjacent PGN 126992 anchors.
#   - Frames before the first anchor and after the last anchor stay None (blank).
#   - No extrapolation: if the GPS hadn't locked yet, those frames get no time.
#   - This is what professional VDR decoders do: the bus time IS the 126992 time,
#     and every frame between two 126992 broadcasts is linearly interpolated.
#
# Mode 2 — Inferred (extends mode 1 for incomplete recordings):
#   - Same interpolation as mode 1.
#   - Additionally extrapolates outside the anchored region using the mean
#     µs/frame rate derived from all anchor pairs.
#   - Fallback to DEFAULT_DELTA_US when fewer than 2 usable anchors exist.

def _collect_anchors(frames: List[Frame]) -> List[Tuple[int, datetime]]:
    """
    Extract PGN 126992 wall-clock anchors from the frame list.
    Returns a list of (frame_index, utc_datetime) sorted by index,
    deduplicated so no two anchors share the same UTC second.
    """
    raw: List[Tuple[int, datetime]] = []
    for i, f in enumerate(frames):
        t = real_timestamp_utc(f)
        if t is not None:
            raw.append((i, t))

    seen: set = set()
    anchors: List[Tuple[int, datetime]] = []
    for idx, t in raw:
        key = t.replace(microsecond=0)
        if key not in seen:
            seen.add(key)
            anchors.append((idx, t))

    anchors.sort(key=lambda x: x[0])
    return anchors

def _interpolate_between_anchors(
    ts_out: List[Optional[datetime]],
    anchors: List[Tuple[int, datetime]],
) -> None:
    """
    Linear interpolation by frame index between every adjacent anchor pair.
    The anchor frames themselves are already set and are not overwritten.
    """
    for a in range(len(anchors) - 1):
        i0, t0 = anchors[a]
        i1, t1 = anchors[a + 1]
        if i1 <= i0 + 1:
            continue   # no frames sit between these two anchors
        span_us     = (t1 - t0).total_seconds() * 1_000_000.0
        frame_count = i1 - i0
        for i in range(i0 + 1, i1):
            if ts_out[i] is not None:
                continue   # already an anchor — never overwrite
            ts_out[i] = t0 + timedelta(microseconds=span_us * (i - i0) / frame_count)

def build_real_timeline(frames: List[Frame]) -> List[Optional[datetime]]:
    """
    Mode 1 — VDR real.

    Every frame between two PGN 126992 broadcasts gets a UTC timestamp by
    linear interpolation over frame index (identical to how YDVR Converter,
    Actisense NMEA Reader, and OpenCPN's log importer assign times).

    Frames before the first 126992 anchor or after the last 126992 anchor
    remain None — there is no verified reference clock for those regions,
    so no timestamp is fabricated.
    """
    n = len(frames)
    ts_out: List[Optional[datetime]] = [None] * n

    anchors = _collect_anchors(frames)
    if not anchors:
        # No 126992 at all — every frame stays blank in strict real mode
        return ts_out

    # Plant exact times on anchor frames
    for idx, t in anchors:
        ts_out[idx] = t

    # Interpolate between pairs
    _interpolate_between_anchors(ts_out, anchors)

    # Frames outside the anchored region stay None — intentional.
    return ts_out

def build_inferred_timeline(
    frames: List[Frame],
    default_delta_us: int,
) -> List[Optional[datetime]]:
    """
    Mode 2 — Inferred.

    Same anchor-based interpolation as mode 1, extended with extrapolation
    outside the anchored region so every frame gets a timestamp even when the
    GPS lock was late or dropped before the recording ended.
    """
    n = len(frames)
    ts_out: List[Optional[datetime]] = [None] * n

    anchors = _collect_anchors(frames)

    if not anchors:
        # No 126992 at all — synthesise uniform spacing from frame 0
        delta = timedelta(microseconds=default_delta_us)
        base  = datetime(1970, 1, 1, tzinfo=timezone.utc)
        for i in range(n):
            ts_out[i] = base + delta * i
        return ts_out

    # Plant exact times on anchor frames
    for idx, t in anchors:
        ts_out[idx] = t

    # Interpolate between anchor pairs
    _interpolate_between_anchors(ts_out, anchors)

    # Mean µs/frame across all anchor pairs — used for extrapolation
    if len(anchors) >= 2:
        total_us      = (anchors[-1][1] - anchors[0][1]).total_seconds() * 1_000_000.0
        total_frames  = anchors[-1][0] - anchors[0][0]
        mean_delta_us = total_us / total_frames if total_frames > 0 else float(default_delta_us)
    else:
        mean_delta_us = float(default_delta_us)

    delta = timedelta(microseconds=max(mean_delta_us, 1.0))

    # Extrapolate before first anchor (walk backwards)
    i_first, t_first = anchors[0]
    for i in range(i_first - 1, -1, -1):
        if ts_out[i] is None:
            ts_out[i] = t_first - delta * (i_first - i)

    # Extrapolate after last anchor (walk forwards)
    i_last, t_last = anchors[-1]
    for i in range(i_last + 1, n):
        if ts_out[i] is None:
            ts_out[i] = t_last + delta * (i - i_last)

    return ts_out

# ── Output writers ────────────────────────────────────────────────────────────

def write_per_file_outputs(frames: List[Frame], ts_list: List[Optional[datetime]]) -> int:
    """
    Append this file's frames to the four shared output files in SHARED_OUTDIR.
    Files are opened in append mode so multiple DAT files accumulate in order.
    No headers, banners, or comment lines are written — raw data only.
    """
    out_socketcan = os.path.join(SHARED_OUTDIR, "socketcan.log")
    out_compact   = os.path.join(SHARED_OUTDIR, "compact.txt")
    out_csv       = os.path.join(SHARED_OUTDIR, "data.csv")
    out_decoded   = os.path.join(SHARED_OUTDIR, "decoded.txt")

    c = 0
    with open(out_socketcan, "a", encoding="utf-8") as fsock, \
         open(out_compact,   "a", encoding="utf-8") as fcmp,  \
         open(out_csv,       "a", encoding="utf-8") as fcsv,  \
         open(out_decoded,   "a", encoding="utf-8") as fdec:

        for i, f in enumerate(frames):
            if LIMIT and c >= LIMIT:
                break

            ts     = ts_list[i]
            ts_str = "" if ts is None else fmt_ts_ms(ts)
            epoch  = "NA" if ts is None else f"{ts.timestamp():.6f}"

            canid_hex      = f"{f.can_id_29:08X}"
            payload_hex_sp = " ".join(f"{b:02X}" for b in f.data8)
            payload_hex    = f.data8.hex().upper()

            fsock.write(f"({epoch}) {IFACE} {canid_hex}#{payload_hex}\n")
            fcmp.write( f"{IFACE}  {canid_hex}   [8]  {payload_hex_sp}\n")

            b = [f"{x:02x}" for x in f.data8]
            fcsv.write(",".join([
                ts_str, str(CHANNEL), str(f.pgn), str(f.priority),
                str(f.src), str(f.dst), "8", *b,
            ]) + "\n")

            name = KNOWN_PGNS.get(f.pgn, "Unknown")
            fdec.write(
                f"{f.offset:08X} | 0x{f.rtype:02X} | {f.seq:02X} | {ts_str:23s} | {canid_hex} | "
                f"{f.pgn:6d} | {f.priority} | {f.src:3d} | {f.dst:3d} | {payload_hex_sp:<23s} | {name}\n"
            )
            c += 1

    return c

def stats(frames: List[Frame]):
    pgn_hist = Counter(f.pgn   for f in frames)
    rt_hist  = Counter(f.rtype for f in frames)
    anchors  = sum(1 for f in frames if real_timestamp_utc(f) is not None)
    print(f"[+] Extracted frames : {len(frames)}")
    print("[+] By record type:")
    for rt, cnt in sorted(rt_hist.items()):
        print(f"    0x{rt:02X}: {cnt}")
    print(f"[+] Real time anchors (PGN 126992): {anchors}")
    print("[+] Top PGNs:")
    for pgn, cnt in pgn_hist.most_common(20):
        nm = KNOWN_PGNS.get(pgn, "Unknown")
        print(f"    {pgn:6d}  {nm[:45]:45s}  {cnt}")

def main():
    with open(INFILE, "rb") as fh:
        buf = fh.read()

    rtypes = parse_types(TYPES)
    frames = extract_frames(buf, rtypes)

    print(f"[+] File  : {INFILE}")
    print(f"[+] Size  : {len(buf):,} bytes")
    print(f"[+] Types : {', '.join('0x%02X' % t for t in rtypes)}")
    if MODE == 1:
        mode_label = "VDR real (126992-anchored interpolation, no extrapolation)"
    else:
        mode_label = "inferred (126992-anchored interpolation + extrapolation)"
    print(f"[+] Mode  : {MODE} — {mode_label}")

    stats(frames)

    if MODE == 1:
        ts_list = build_real_timeline(frames)
    else:
        ts_list = build_inferred_timeline(frames, default_delta_us=DEFAULT_DELTA_US)

    written = write_per_file_outputs(frames, ts_list)

    print(f"[+] Wrote {written} frames from {BASE}")

if __name__ == "__main__":
    main()
PY

  echo "[+] Done: $BASE"
}

# ── Main processing loop ─────────────────────────────────────────────────────

TOTAL=${#INFILES[@]}
OK=0
FAIL=0
declare -a PROCESSED_BASES=()

for INFILE in "${INFILES[@]}"; do
  echo ""
  echo "════════════════════════════════════════"
  echo "[>] Processing: $INFILE"
  echo "════════════════════════════════════════"

  BASE_NAME="$(basename "$INFILE")"
  BASE_NAME="${BASE_NAME%.*}"

  if process_file "$INFILE"; then
    (( OK += 1 )) || true
    PROCESSED_BASES+=("$BASE_NAME")
  else
    echo "[!] FAILED: $INFILE" >&2
    (( FAIL += 1 )) || true
  fi
done

echo ""
echo "════════════════════════════════════════"
echo "[+] Summary: $OK/$TOTAL succeeded, $FAIL failed"
echo "════════════════════════════════════════"

# ── Build the single output zip ──────────────────────────────────────────────
#
# Always exactly one zip regardless of how many DAT files were processed.
# Named after the input basename (single file) or combined_<timestamp> (many).
# Contains four files: socketcan.log, compact.txt, data.csv, decoded.txt.
# Raw data only — no headers, banners, or comment lines of any kind.

if [[ ${#PROCESSED_BASES[@]} -eq 0 ]]; then
  echo "[!] No files processed successfully — nothing to zip." >&2
  rm -rf "$SHARED_OUTDIR"
  trap - EXIT
  exit 1
fi

if [[ ${#PROCESSED_BASES[@]} -eq 1 ]]; then
  FINAL_ZIP="${PROCESSED_BASES[0]}.zip"
else
  FINAL_ZIP="combined_$(date -u +%Y%m%d_%H%M%S).zip"
fi

export SHARED_OUTDIR FINAL_ZIP
BASES_JOINED="$(printf '%s\n' "${PROCESSED_BASES[@]}")"
export BASES_JOINED

python3 - <<'PY'
import os, zipfile

SHARED_OUTDIR = os.environ["SHARED_OUTDIR"]
FINAL_ZIP     = os.environ["FINAL_ZIP"]
BASES         = [b for b in os.environ["BASES_JOINED"].splitlines() if b]

data_files = [
    os.path.join(SHARED_OUTDIR, "socketcan.log"),
    os.path.join(SHARED_OUTDIR, "compact.txt"),
    os.path.join(SHARED_OUTDIR, "data.csv"),
    os.path.join(SHARED_OUTDIR, "decoded.txt"),
]

with zipfile.ZipFile(FINAL_ZIP, "w", compression=zipfile.ZIP_DEFLATED) as z:
    for path in data_files:
        if os.path.exists(path):
            z.write(path, arcname=os.path.basename(path))

# Count total frame lines written (socketcan lines start with '(' or 'NA')
total = 0
sock_path = os.path.join(SHARED_OUTDIR, "socketcan.log")
if os.path.exists(sock_path):
    with open(sock_path, encoding="utf-8") as fh:
        for ln in fh:
            if ln.startswith("(") or ln.startswith("NA"):
                total += 1

print(f"[+] Output zip   : {FINAL_ZIP}")
print(f"[+] Total frames : {total:,} (from {len(BASES)} source file(s))")
print(f"[+] Contents     : socketcan.log  compact.txt  data.csv  decoded.txt")
PY

rm -rf "$SHARED_OUTDIR"
trap - EXIT

echo ""
echo "[+] All done. Output: $FINAL_ZIP"

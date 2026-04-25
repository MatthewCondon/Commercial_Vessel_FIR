#!/usr/bin/env python3
"""
nmea_to_pcap.py
Converts a timestamped NMEA 0183 / AIS log file into a PCAP file
suitable for loading in Wireshark with the fkie-cad maritime-dissector.

Transport mapping (mirrors common real-world UDP port conventions):
  NMEA 0183 sentences  → UDP dst 10110  (NMEA standard port)
  AIS VDM/VDO          → UDP dst 10110  (same port; dissector auto-detects)
  BWALR / ERALR        → UDP dst 10110

Usage:
  python nmea_to_pcap.py input.log output.pcap
  python nmea_to_pcap.py input.log            # writes output.pcap next to input

Checksum behaviour (default: --fix-checksums ON):
  Sentences with a trailing space before '*HH' (e.g. "ALARM *54") have their
  checksum recomputed from the actual payload so Wireshark shows no CORRUPT
  warning.  Pass --no-fix-checksums to keep the original bytes verbatim.
"""

import struct
import sys
import os
import re
import argparse
from datetime import datetime, timezone

# ---------------------------------------------------------------------------
# PCAP writer (no external dependencies)
# ---------------------------------------------------------------------------

PCAP_GLOBAL_HEADER = struct.pack(
    "<IHHiIII",
    0xA1B2C3D4,   # magic number (little-endian, microsecond resolution)
    2, 4,         # major / minor version
    0,            # timezone offset (UTC)
    0,            # timestamp accuracy
    65535,        # snap length
    1,            # link type: Ethernet (DLT_EN10MB)
)


def pcap_packet(ts_sec: int, ts_usec: int, data: bytes) -> bytes:
    """Wrap raw bytes in a pcap packet record."""
    length = len(data)
    header = struct.pack("<IIII", ts_sec, ts_usec, length, length)
    return header + data


# ---------------------------------------------------------------------------
# Ethernet / IP / UDP framing helpers
# ---------------------------------------------------------------------------

SRC_MAC  = bytes.fromhex("AABBCCDDEEFF")
DST_MAC  = bytes.fromhex("FFFFFFFFFFFF")   # broadcast
SRC_IP   = bytes([192, 168, 1, 10])
DST_IP   = bytes([239, 192, 0, 1])         # NMEA multicast group
ETHERTYPE_IPV4 = b"\x08\x00"

NMEA_PORT = 10110   # IANA-assigned NMEA 0183 port


def udp_frame(payload: bytes, src_port: int = 60001, dst_port: int = NMEA_PORT) -> bytes:
    """Build a complete Ethernet/IPv4/UDP frame containing payload."""
    # UDP header (no checksum — valid for IPv4 when 0)
    udp_len = 8 + len(payload)
    udp_hdr = struct.pack(">HHHH", src_port, dst_port, udp_len, 0)
    udp_data = udp_hdr + payload

    # IPv4 header (no options, no checksum computed for simplicity)
    ip_total = 20 + len(udp_data)
    ip_hdr = struct.pack(
        ">BBHHHBBH4s4s",
        0x45,           # version=4, IHL=5
        0,              # DSCP/ECN
        ip_total,
        0,              # identification
        0x4000,         # flags: Don't Fragment
        64,             # TTL
        17,             # protocol: UDP
        0,              # checksum (0 = unchecked; Wireshark accepts this)
        SRC_IP,
        DST_IP,
    )

    # Ethernet frame
    eth = DST_MAC + SRC_MAC + ETHERTYPE_IPV4
    return eth + ip_hdr + udp_data


# ---------------------------------------------------------------------------
# NMEA checksum utilities
# ---------------------------------------------------------------------------

# Matches the checksum field: optional whitespace before *, then two hex digits
_CHKSUM_RE = re.compile(rb'\s*\*([0-9A-Fa-f]{2})$')


def nmea_checksum(body: bytes) -> int:
    """XOR of all bytes between '$'/'!' and '*' (exclusive)."""
    chk = 0
    for b in body:
        chk ^= b
    return chk


def fix_sentence_checksum(sentence: bytes) -> tuple[bytes, str]:
    """
    Recompute the NMEA checksum from the actual payload and return a corrected
    sentence.  Also strips any stray whitespace that precedes the '*HH' field
    (a common logging artefact, e.g. "ALARM *54").

    Returns (sentence, status) where status is 'ok', 'fixed', or 'no_checksum'.
    """
    if not sentence or sentence[0:1] not in (b'$', b'!'):
        return sentence, 'no_checksum'

    star_idx = sentence.rfind(b'*')
    if star_idx == -1:
        return sentence, 'no_checksum'

    m = _CHKSUM_RE.search(sentence[star_idx:])
    if not m:
        return sentence, 'no_checksum'

    claimed   = int(m.group(1), 16)
    body_raw  = sentence[1:star_idx]
    body      = body_raw.rstrip()   # strip trailing spaces before '*'
    correct   = nmea_checksum(body)

    if claimed == correct and body == body_raw:
        return sentence, 'ok'

    fixed = sentence[0:1] + body + b'*' + f'{correct:02X}'.encode()
    return fixed, 'fixed'


# ---------------------------------------------------------------------------
# Log parser
# ---------------------------------------------------------------------------

def parse_line(line: str):
    """
    Parse one line of the format:
      YYYY-MM-DD HH:MM:SS UTC | <sentence>
    Returns (datetime, sentence_bytes) or None if line is invalid.
    """
    line = line.strip()
    if not line or "|" not in line:
        return None

    ts_part, _, sentence = line.partition("|")
    sentence = sentence.strip()
    if not sentence:
        return None

    ts_part = ts_part.strip()
    # Remove trailing UTC label if present
    ts_part = ts_part.replace(" UTC", "").strip()

    try:
        dt = datetime.strptime(ts_part, "%Y-%m-%d %H:%M:%S")
        dt = dt.replace(tzinfo=timezone.utc)
    except ValueError:
        return None

    return dt, sentence.encode("ascii", errors="replace")


# ---------------------------------------------------------------------------
# Main conversion
# ---------------------------------------------------------------------------

def convert(input_path: str, output_path: str, fix_checksums: bool = True):
    packets_written = 0
    checksums_fixed = 0
    errors = 0

    with open(input_path, "r", encoding="utf-8", errors="replace") as fin, \
         open(output_path, "wb") as fout:

        fout.write(PCAP_GLOBAL_HEADER)

        # Track sub-second ordering within the same timestamp
        prev_ts = None
        usec_counter = 0

        for lineno, line in enumerate(fin, 1):
            result = parse_line(line)
            if result is None:
                if line.strip():
                    print(f"  [warn] line {lineno} skipped: {line.rstrip()!r}")
                    errors += 1
                continue

            dt, payload = result

            # Optionally repair checksums (strip stray whitespace, recompute)
            if fix_checksums:
                payload, status = fix_sentence_checksum(payload)
                if status == 'fixed':
                    checksums_fixed += 1

            # Add a tiny microsecond offset for lines sharing the same second
            # so Wireshark preserves ordering.
            ts_sec = int(dt.timestamp())
            if ts_sec == prev_ts:
                usec_counter += 1000   # 1 ms apart
            else:
                usec_counter = 0
            prev_ts = ts_sec

            # NMEA sentence → UDP payload → Ethernet frame → pcap record
            frame = udp_frame(payload + b"\r\n")
            record = pcap_packet(ts_sec, usec_counter, frame)
            fout.write(record)
            packets_written += 1

    print(f"\nDone. {packets_written} packets written to: {output_path}")
    if fix_checksums and checksums_fixed:
        print(f"       {checksums_fixed} checksum(s) recomputed (trailing-space artefact stripped).")
    if errors:
        print(f"       {errors} lines skipped (see warnings above).")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Convert a timestamped NMEA 0183 log to PCAP (Ethernet/UDP/port 10110)."
    )
    parser.add_argument("input",  help="Input log file")
    parser.add_argument("output", nargs="?", help="Output .pcap file (default: input basename + .pcap)")
    parser.add_argument(
        "--no-fix-checksums",
        dest="fix_checksums",
        action="store_false",
        default=True,
        help="Keep original checksum bytes verbatim instead of recomputing them",
    )
    args = parser.parse_args()

    inp = args.input
    out = args.output or (os.path.splitext(inp)[0] + ".pcap")

    if not os.path.isfile(inp):
        print(f"Error: input file not found: {inp}")
        sys.exit(1)

    fix = args.fix_checksums
    print(f"Converting: {inp}  →  {out}")
    print(f"Checksum fix: {'enabled' if fix else 'disabled'}")
    convert(inp, out, fix_checksums=fix)

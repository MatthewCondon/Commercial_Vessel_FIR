# This script requires that "candump -L can0 > output.txt" be used before
# Usage: python3 can2pcap.py output.txt
# Output: This will create a ZIP file with PGN-Specific PCAP Files, a summary of frames used with each PCAP, and an all-encompassing PCAP
# Requirement: This requires data in the Raw SocketCAN format

#!/usr/bin/env python3
import argparse
import os
import re
import struct
import sys
import tempfile
import zipfile
from typing import Dict, Optional, Tuple, BinaryIO

# PCAP linktype for SocketCAN
DLT_CAN_SOCKETCAN = 227

# Linux CAN flags (SocketCAN)
CAN_EFF_FLAG = 0x80000000  # extended frame format
CAN_RTR_FLAG = 0x40000000  # remote transmission request
CAN_ERR_FLAG = 0x20000000  # error frame

CAN_EFF_MASK = 0x1FFFFFFF  # 29-bit ID mask

# candump -L example formats commonly seen:
#   (1707325860.123456) can0 18FEEE00#1122334455667788
#   (1707325860.123456) can0 123#DEADBEEF
#   can0 18FEEE00#112233...
CANDUMP_L_RE = re.compile(
    r"""^\s*
        (?:\((?P<ts>\d+(?:\.\d+)?)\)\s+)?      # optional (timestamp)
        (?P<if>\S+)\s+                         # interface
        (?P<canid>[0-9A-Fa-f]+)                # CAN ID in hex
        \#
        (?P<data>[0-9A-Fa-fRr]*)               # data bytes hex, or 'R' (RTR)
        \s*$
    """,
    re.VERBOSE,
)


def pgn_from_canid(can_id_29: int) -> int:
    """
    NMEA2000 / J1939-style 29-bit identifier:
      bits 26-28: Priority (3)
      bit  25   : Reserved
      bit  24   : Data Page (DP)
      bits 16-23: PF
      bits  8-15: PS
      bits  0-7 : SA

    PGN rules:
      - PDU1 (PF < 240): PGN = DP:PF:00
      - PDU2 (PF >=240): PGN = DP:PF:PS
    """
    dp = (can_id_29 >> 24) & 0x1
    pf = (can_id_29 >> 16) & 0xFF
    ps = (can_id_29 >> 8) & 0xFF
    if pf < 240:
        return (dp << 16) | (pf << 8) | 0x00
    return (dp << 16) | (pf << 8) | ps


def parse_candump_l_line(line: str) -> Optional[Tuple[Optional[float], str, int, bytes, bool, bool]]:
    """
    Returns: (timestamp_or_None, iface, can_id_raw, data_bytes, is_rtr, is_extended_id)
    """
    m = CANDUMP_L_RE.match(line)
    if not m:
        return None

    ts_s = m.group("ts")
    ts = float(ts_s) if ts_s is not None else None

    iface = m.group("if")
    canid_hex = m.group("canid")
    data_field = m.group("data")

    # RTR appears as ...#R in some candump outputs
    if data_field.lower() == "r":
        is_rtr = True
        data_bytes = b""
    else:
        is_rtr = False
        # hex string -> bytes; allow odd length by padding (shouldn't happen, but be resilient)
        if len(data_field) % 2 == 1:
            data_field = "0" + data_field
        try:
            data_bytes = bytes.fromhex(data_field) if data_field else b""
        except ValueError:
            return None

    can_id_raw = int(canid_hex, 16)
    is_ext = can_id_raw > 0x7FF  # heuristic: > 11-bit implies extended
    return ts, iface, can_id_raw, data_bytes, is_rtr, is_ext


def pcap_global_header_le(linktype: int, snaplen: int = 65535) -> bytes:
    """
    PCAP (not pcapng) global header, little-endian.
    """
    magic = 0xA1B2C3D4
    ver_major = 2
    ver_minor = 4
    thiszone = 0
    sigfigs = 0
    return struct.pack("<IHHIIII", magic, ver_major, ver_minor, thiszone, sigfigs, snaplen, linktype)


def pcap_packet_header_le(ts_sec: int, ts_usec: int, incl_len: int, orig_len: int) -> bytes:
    return struct.pack("<IIII", ts_sec, ts_usec, incl_len, orig_len)


def socketcan_can_frame(can_id_with_flags: int, data: bytes) -> bytes:
    """
    Linux 'struct can_frame' on the wire for DLT_CAN_SOCKETCAN (16 bytes):
      can_id (u32), can_dlc(u8), pad(3), data(8)
    NOTE: CAN ID endianness in captures has historically been messy; we emit can_id as big-endian
    because that's commonly what decoders expect for DLT_CAN_SOCKETCAN. :contentReference[oaicite:1]{index=1}
    """
    dlc = min(len(data), 8)
    payload = data[:8].ljust(8, b"\x00")
    # can_id as big-endian u32, rest as bytes
    return struct.pack(">I", can_id_with_flags) + bytes([dlc]) + b"\x00\x00\x00" + payload


def main():
    ap = argparse.ArgumentParser(
        description="Convert candump -L output into All_PGN.pcap + per-PGN pcaps, zipped as PGN_Pcaps.zip"
    )
    ap.add_argument(
        "input",
        nargs="?",
        default="-",
        help="candump -L log file, or '-' to read from stdin (default: '-')",
    )
    ap.add_argument(
        "--zip",
        default="PGN_Pcaps.zip",
        help="Zip output name (default: PGN_Pcaps.zip)",
    )
    args = ap.parse_args()

    # Open input
    if args.input == "-":
        lines = sys.stdin
    else:
        lines = open(args.input, "r", encoding="utf-8", errors="replace")

    gh = pcap_global_header_le(DLT_CAN_SOCKETCAN, snaplen=65535)

    writers: Dict[int, BinaryIO] = {}
    created_paths: Dict[int, str] = {}
    counts: Dict[int, int] = {}

    # If no timestamps are present, we synthesize them.
    synth_ts = 1700000000.0  # arbitrary epoch anchor
    synth_step = 0.001       # 1ms per frame
    last_ts = None

    with tempfile.TemporaryDirectory(prefix="pgn_pcaps_") as tmpdir:
        all_path = os.path.join(tmpdir, "All_PGN.pcap")
        all_w = open(all_path, "wb")
        all_w.write(gh)

        def get_writer(pgn: int) -> BinaryIO:
            if pgn in writers:
                return writers[pgn]
            out_path = os.path.join(tmpdir, f"{pgn}.pcap")
            wf = open(out_path, "wb")
            wf.write(gh)
            writers[pgn] = wf
            created_paths[pgn] = out_path
            counts[pgn] = 0
            return wf

        total_lines = 0
        parsed_lines = 0
        total_frames = 0

        for line in lines:
            total_lines += 1
            parsed = parse_candump_l_line(line)
            if not parsed:
                continue
            parsed_lines += 1

            ts, iface, can_id_raw, data_bytes, is_rtr, is_ext = parsed

            # timestamp handling
            if ts is None:
                if last_ts is None:
                    ts = synth_ts
                else:
                    ts = last_ts + synth_step
            last_ts = ts

            ts_sec = int(ts)
            ts_usec = int(round((ts - ts_sec) * 1_000_000.0))
            if ts_usec >= 1_000_000:
                ts_sec += 1
                ts_usec -= 1_000_000

            # Build can_id with flags
            can_id = can_id_raw
            if is_ext:
                can_id |= CAN_EFF_FLAG
            if is_rtr:
                can_id |= CAN_RTR_FLAG

            frame = socketcan_can_frame(can_id, data_bytes)
            ph = pcap_packet_header_le(ts_sec, ts_usec, len(frame), len(frame))

            # Write to All_PGN.pcap (everything, including standard + extended, data + RTR)
            all_w.write(ph)
            all_w.write(frame)
            total_frames += 1

            # For per-PGN pcaps: only extended data frames (skip standard, RTR, ERR)
            if not is_ext:
                continue
            if is_rtr:
                continue
            if (can_id & CAN_ERR_FLAG) != 0:
                continue

            can29 = can_id_raw & CAN_EFF_MASK  # raw 29-bit ID (no flags)
            pgn = pgn_from_canid(can29)

            wf = get_writer(pgn)
            wf.write(ph)
            wf.write(frame)
            counts[pgn] += 1

        all_w.close()

        # Close per-PGN writers
        for wf in writers.values():
            wf.close()

        # Build zip
        with zipfile.ZipFile(args.zip, "w", compression=zipfile.ZIP_DEFLATED) as z:
            z.write(all_path, arcname="All_PGN.pcap")

            for pgn, path in sorted(created_paths.items()):
                z.write(path, arcname=os.path.basename(path))

            summary_path = os.path.join(tmpdir, "pgn_summary.txt")
            with open(summary_path, "w", encoding="utf-8") as s:
                s.write(f"Input: {args.input}\n")
                s.write("Source: candump -L text\n")
                s.write(f"Total input lines: {total_lines}\n")
                s.write(f"Parsed candump lines: {parsed_lines}\n")
                s.write(f"Total frames written to All_PGN.pcap: {total_frames}\n")
                s.write("Per-PGN pcaps: extended (EFF) non-RTR frames only\n")
                s.write(f"Distinct PGNs: {len(counts)}\n")
                s.write(f"Total frames written to PGN pcaps: {sum(counts.values())}\n\n")
                for pgn, n in sorted(counts.items(), key=lambda x: (-x[1], x[0])):
                    s.write(f"{pgn}: {n} frames\n")
            z.write(summary_path, arcname="pgn_summary.txt")

    # Close input file if we opened it
    if args.input != "-":
        lines.close()

    print(f"[+] Wrote {args.zip}")
    print("[+] Contains: All_PGN.pcap, <PGN>.pcap files, pgn_summary.txt")


if __name__ == "__main__":
    main()

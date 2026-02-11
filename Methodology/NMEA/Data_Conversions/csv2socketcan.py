# This script converts CSV NMEA 2000 data to Raw SocketCAN format
# It requires a CSV file, which may be recovered from the VDR. It will output to a file you name in the command line.
# Usage: python3 csv2socketcan.py oldfile.csv newfile.log

#!/usr/bin/env python3
import argparse
import datetime as dt

def ts_to_epoch(ts: str) -> float:
    # 2026-01-22-20:21:19.472
    d = dt.datetime.strptime(ts, "%Y-%m-%d-%H:%M:%S.%f")
    return d.timestamp()

def parse_byte_hex(s: str) -> int:
    # analyzer CSV bytes are hex like "ff", "0a", "00"
    return int(s.strip(), 16) & 0xFF

def is_pdu1(pgn: int) -> bool:
    pf = (pgn >> 8) & 0xFF
    return pf < 240

def make_n2k_can_id(priority: int, pgn: int, src: int, dst: int) -> int:
    """
    NMEA2000 29-bit ID:
      PRI(3) | R(1=0) | DP(1) | PF(8) | PS(8) | SA(8)
    - For PDU1 (PF < 240): PS = DST, and PGN low byte is 0 in canonical PGN
    - For PDU2 (PF >= 240): PS = PGN low byte (group extension)
    """
    dp = (pgn >> 16) & 0x01
    pf = (pgn >> 8) & 0xFF
    ps = pgn & 0xFF

    if is_pdu1(pgn):
        ps_field = dst & 0xFF
    else:
        ps_field = ps  # group extension

    can_id = ((priority & 0x7) << 26) | (dp << 24) | (pf << 16) | (ps_field << 8) | (src & 0xFF)
    return can_id

def main():
    ap = argparse.ArgumentParser(description="Convert candump2analyzer CSV to candump-style SocketCAN text.")
    ap.add_argument("input_csv", help="File produced by: candump can0 | candump2analyzer > file.csv")
    ap.add_argument("output_txt", help="Output SocketCAN/candump-style text file")
    ap.add_argument("--ifname", default="can0", help="Interface name to print (default: can0)")
    ap.add_argument("--priority", type=int, default=3, help="Default N2K priority to use (default: 3)")
    ap.add_argument("--id-width", choices=["auto", "8"], default="8",
                    help="Hex width for CAN ID: '8' prints 8 digits; 'auto' prints without padding (default: 8)")
    args = ap.parse_args()

    with open(args.input_csv, "r", encoding="utf-8", errors="replace") as fin, \
         open(args.output_txt, "w", encoding="utf-8") as fout:

        for lineno, line in enumerate(fin, start=1):
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            # Format:
            # ts,channel,pgn,src,dst,len,byte0,byte1,...
            parts = [p.strip() for p in line.split(",")]
            if len(parts) < 6:
                fout.write(f"# line {lineno} skipped: too few fields | {line}\n")
                continue

            try:
                ts = parts[0]
                # channel = int(parts[1])  # available if you want to map can0/can1
                pgn = int(parts[2])
                src = int(parts[3])
                dst = int(parts[4])
                ln  = int(parts[5])

                data_fields = parts[6:6+ln]
                if len(data_fields) != ln:
                    raise ValueError(f"expected {ln} data bytes, got {len(data_fields)}")

                data = bytes(parse_byte_hex(b) for b in data_fields)

                epoch = ts_to_epoch(ts)
                can_id = make_n2k_can_id(args.priority, pgn, src, dst)

                can_id_str = f"{can_id:08X}" if args.id_width == "8" else f"{can_id:X}"
                data_hex = data.hex().upper()

                fout.write(f"({epoch:.6f}) {args.ifname} {can_id_str}#{data_hex}\n")

            except Exception as e:
                fout.write(f"# line {lineno} skipped: {e} | {line}\n")

if __name__ == "__main__":
    main()

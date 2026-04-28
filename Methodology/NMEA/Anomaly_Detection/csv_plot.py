#!/usr/bin/env python3

import csv
import sys
import matplotlib.pyplot as plt
from datetime import datetime

# =============================
# PGN MEANINGS
# =============================

PGN_MEANINGS = {
    127250: "Heading",
    128259: "Speed",
    128267: "Depth",
}

def get_pgn_name(pgn):
    return PGN_MEANINGS.get(pgn, f"PGN {pgn}")

# =============================
# TIME PARSER
# =============================

def parse_time(ts):
    try:
        return datetime.strptime(ts, "%Y-%m-%d-%H:%M:%S.%f")
    except:
        return None

# =============================
# DECODER
# =============================

def decode_value(pgn, data):
    try:
        # Heading
        if pgn == 127250:
            raw = int(data[0], 16) | (int(data[1], 16) << 8)
            return raw * 0.0001 * 57.2958

        # Speed
        if pgn == 128259:
            raw = int(data[0], 16) | (int(data[1], 16) << 8)
            return raw * 0.01

        # Depth
        if pgn == 128267:
            raw = int.from_bytes(bytes.fromhex("".join(data[:4])), "little")
            return raw * 0.01

        # Fallback (ANY PGN)
        raw = int(data[0], 16) | (int(data[1], 16) << 8)
        return raw

    except:
        return None

# =============================
# EXTRACT SERIES
# =============================

def extract_series(path, target_pgn):
    times = []
    values = []

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.reader(f)

        for row in reader:
            if len(row) < 8:
                continue

            try:
                ts = parse_time(row[0])
                pgn = int(row[2])
                data = row[7:]
            except:
                continue

            if pgn != target_pgn or ts is None:
                continue

            val = decode_value(pgn, data)

            if val is not None:
                times.append(ts)
                values.append(val)

    return times, values

# =============================
# FIND PGNs
# =============================

def extract_pgns(path):
    found = set()

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.reader(f)

        for row in reader:
            if len(row) < 3:
                continue

            try:
                found.add(int(row[2]))
            except:
                continue

    return sorted(found)

# =============================
# PLOT (COMPARABLE VERSION)
# =============================

def plot_series(series, p1, p2=None):
    if len(series) == 1:
        t, v, label = series[0]

        fig, ax = plt.subplots()
        ax.plot(t, v)
        ax.set_title(label)
        ax.set_xlabel("Time")
        ax.set_ylabel("Value")
        ax.grid()

    else:
        (t1, v1, l1), (t2, v2, l2) = series

        fig, axs = plt.subplots(1, 2, figsize=(12, 5))

        # 🔥 Make Y axes comparable
        y_min = min(min(v1), min(v2))
        y_max = max(max(v1), max(v2))

        # Plot 1
        axs[0].plot(t1, v1)
        axs[0].set_title(l1)
        axs[0].set_ylim(y_min, y_max)
        axs[0].set_xlabel("Time")
        axs[0].set_ylabel("Value")
        axs[0].grid()

        # Plot 2
        axs[1].plot(t2, v2)
        axs[1].set_title(l2)
        axs[1].set_ylim(y_min, y_max)
        axs[1].set_xlabel("Time")
        axs[1].set_ylabel("Value")
        axs[1].grid()

    # =============================
    # SAVE FILE
    # =============================

    filename = f"pgn_{p1}" if not p2 else f"pgn_{p1}_vs_{p2}"
    fig.tight_layout()
    fig.savefig(filename + ".png", dpi=300)

    print(f"\nSaved: {filename}.png")

    plt.show()

# =============================
# MAIN
# =============================

def main():
    if len(sys.argv) < 2:
        print("Usage: python script.py file.csv")
        return

    path = sys.argv[1]

    pgns = extract_pgns(path)

    print("\nPGNs found:")
    for p in pgns:
        print(p, "-", get_pgn_name(p))

    try:
        p1 = int(input("\nEnter first PGN: "))
    except:
        return

    p2_input = input("Enter second PGN (or press enter): ")

    series = []

    t1, v1 = extract_series(path, p1)
    series.append((t1, v1, get_pgn_name(p1)))

    p2 = None
    if p2_input.strip():
        p2 = int(p2_input)
        t2, v2 = extract_series(path, p2)
        series.append((t2, v2, get_pgn_name(p2)))

    plot_series(series, p1, p2)

if __name__ == "__main__":
    main()

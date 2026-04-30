#!/usr/bin/env python3
"""
CPU graph for ironbar script module.
Reads /proc/stat to get per-core CPU usage.
Outputs a colored Pango markup string with block chars.
"""

import time

BLOCKS = [" ", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]


def read_stat():
    cores = {}
    with open("/proc/stat") as f:
        for line in f:
            if not line.startswith("cpu"):
                continue
            parts = line.split()
            name = parts[0]
            if name == "cpu":
                continue  # skip aggregate, we want individual cores
            vals = list(map(int, parts[1:]))
            idle = vals[3] + (vals[4] if len(vals) > 4 else 0)  # idle + iowait
            total = sum(vals)
            cores[name] = (idle, total)
    return cores


def compute_usage(prev, curr):
    usage = {}
    for name in curr:
        if name not in prev:
            usage[name] = 0.0
            continue
        idle_d  = curr[name][0] - prev[name][0]
        total_d = curr[name][1] - prev[name][1]
        if total_d == 0:
            usage[name] = 0.0
        else:
            usage[name] = max(0.0, min(100.0, 100.0 * (1 - idle_d / total_d)))
    return usage


def bar_color(pct):
    if pct >= 80:
        return "#b07b7b"   # @red
    elif pct >= 50:
        return "#bfb48f"   # @yellow
    else:
        return "#7a8ca3"   # @blue


def main():
    t1 = read_stat()
    time.sleep(0.2)
    t2 = read_stat()

    usage = compute_usage(t1, t2)
    if not usage:
        print("CPU")
        return

    # Sort cores: cpu0, cpu1, ...
    cores = sorted(usage.keys(), key=lambda k: int(k[3:]))
    mean = sum(usage[c] for c in cores) / len(cores)

    # Build block graph with per-char color
    graph = ""
    for core in cores:
        pct = usage[core]
        idx = int((pct / 100) * (len(BLOCKS) - 1))
        block = BLOCKS[max(0, min(idx, len(BLOCKS) - 1))]
        col = bar_color(pct)
        graph += f'<span foreground="{col}">{block}</span>'

    mean_col = bar_color(mean)
    label = f'<span foreground="{mean_col}"> {mean:2.0f}%</span>{graph}'
    print(label)


if __name__ == "__main__":
    main()

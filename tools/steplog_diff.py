#!/usr/bin/env python3
"""Compare two Step logs (M2) and report the first line where they differ.

    python tools/steplog_diff.py model.log hdl.log [--ignore tick,phase]

The format is described in prototipos/tron_fpga/model/steplog.py: one line
per Step outcome or prepared Round, space-separated key=value fields. Blank
lines and lines starting with `#` are skipped, so a testbench may add
comments. Exit status: 0 when the logs match, 1 at the first difference,
2 on a usage error.
"""

import argparse
import sys


def read_log(path):
    with open(path, encoding="utf-8") as f:
        lines = [l.strip() for l in f]
    return [l for l in lines if l and not l.startswith("#")]


def fields(line):
    return dict(item.split("=", 1) for item in line.split())


def compare(a_lines, b_lines, ignore=()):
    """None if equal, else (line number, {field: (a, b)}) for the first difference."""
    for n, (a, b) in enumerate(zip(a_lines, b_lines), 1):
        fa, fb = fields(a), fields(b)
        keys = [k for k in dict.fromkeys(list(fa) + list(fb)) if k not in ignore]
        diff = {k: (fa.get(k, "<missing>"), fb.get(k, "<missing>"))
                for k in keys if fa.get(k) != fb.get(k)}
        if diff:
            return n, diff
    if len(a_lines) != len(b_lines):
        n = min(len(a_lines), len(b_lines)) + 1
        return n, {"<lines>": (len(a_lines), len(b_lines))}
    return None


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("a")
    ap.add_argument("b")
    ap.add_argument("--ignore", default="", help="comma-separated fields to skip")
    args = ap.parse_args(argv)
    a, b = read_log(args.a), read_log(args.b)
    found = compare(a, b, tuple(f for f in args.ignore.split(",") if f))
    if found is None:
        print(f"match: {len(a)} lines")
        return 0
    n, diff = found
    print(f"first difference at line {n}:")
    if n <= len(a):
        print(f"  {args.a}: {a[n - 1]}")
    if n <= len(b):
        print(f"  {args.b}: {b[n - 1]}")
    for k, (va, vb) in diff.items():
        print(f"  {k}: {va} != {vb}")
    return 1


if __name__ == "__main__":
    sys.exit(main())

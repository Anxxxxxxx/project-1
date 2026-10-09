#!/usr/bin/env python3
"""Summarize Salmon quantification logs into a QC table.

Usage:
    python salmon_qc.py LOG_OR_DIR [LOG_OR_DIR ...] [-o qc.csv] [--min-rate 70]

Directories are searched recursively for files named *quant*.log.
"""
import argparse
import csv
import re
import sys
from datetime import datetime
from pathlib import Path

COLUMNS = [
    "sample", "library_type", "observed_fragments", "mapped_fragments",
    "mapping_rate", "equivalence_classes", "frag_len_mean", "frag_len_sd",
    "runtime_min", "status",
]


def parse_log(path):
    """Return a dict of QC values parsed from one Salmon log file."""
    fields = {}
    for line in Path(path).read_text().splitlines():
        if ":" in line:
            key, _, value = line.partition(":")
            fields[key.strip().lower()] = value.strip()

    row = {"sample": sample_name(path)}
    row["library_type"] = fields.get("library type", "")
    row["observed_fragments"] = to_int(fields.get("observed fragments"))
    row["mapped_fragments"] = to_int(fields.get("mapped fragments"))
    row["mapping_rate"] = to_float(fields.get("mapping rate", "").rstrip("%"))
    row["equivalence_classes"] = to_int(fields.get("number of equivalence classes"))

    m = re.match(r"([\d.]+)\s*\(([\d.]+)\)", fields.get("fragment length mean (sd)", ""))
    row["frag_len_mean"] = float(m.group(1)) if m else None
    row["frag_len_sd"] = float(m.group(2)) if m else None

    row["runtime_min"] = runtime_minutes(fields.get("start"), fields.get("end"))
    return row


def sample_name(path):
    """Use the parent directory name (Salmon's usual per-sample output dir), else the file stem."""
    path = Path(path)
    parent = path.parent.name
    if parent in ("", ".", "logs", "aux_info"):
        parent = path.parent.parent.name if parent in ("logs", "aux_info") else ""
    return parent or path.stem


def runtime_minutes(start, end):
    fmt = "%a %b %d %H:%M:%S %Y"
    try:
        delta = datetime.strptime(end, fmt) - datetime.strptime(start, fmt)
    except (TypeError, ValueError):
        return None
    return round(delta.total_seconds() / 60, 1)


def to_int(value):
    try:
        return int(value.replace(",", ""))
    except (AttributeError, ValueError):
        return None


def to_float(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def find_logs(inputs):
    for item in inputs:
        p = Path(item)
        if p.is_dir():
            yield from sorted(p.rglob("*quant*.log"))
        elif p.is_file():
            yield p
        else:
            print(f"warning: {item} not found, skipping", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("inputs", nargs="+", help="Salmon log files or directories")
    parser.add_argument("-o", "--output", help="write CSV here (default: stdout)")
    parser.add_argument("--min-rate", type=float, default=70.0,
                        help="flag samples with mapping rate below this %% (default 70)")
    args = parser.parse_args()

    rows = []
    for log in find_logs(args.inputs):
        row = parse_log(log)
        rate = row["mapping_rate"]
        row["status"] = "UNKNOWN" if rate is None else ("LOW" if rate < args.min_rate else "OK")
        rows.append(row)

    if not rows:
        sys.exit("error: no Salmon logs found")

    out = open(args.output, "w", newline="") if args.output else sys.stdout
    writer = csv.DictWriter(out, fieldnames=COLUMNS)
    writer.writeheader()
    writer.writerows(rows)
    if args.output:
        out.close()

    low = [r["sample"] for r in rows if r["status"] != "OK"]
    print(f"{len(rows)} sample(s) checked, {len(low)} flagged"
          + (f": {', '.join(low)}" if low else ""), file=sys.stderr)


if __name__ == "__main__":
    main()

"""Collect deterministic file-prefix samples for the initial suitability audit."""
import argparse
import csv
import json
from concurrent.futures import ThreadPoolExecutor
from itertools import islice
from pathlib import Path

from source import DATASET, project_record, remote_records


def collect(index, rows, output):
    filename = f"traffic_data_{index}.json"
    target = output / f"sample_{index}.csv"
    if target.exists():
        with target.open(encoding="utf-8", newline="") as stream:
            count = sum(1 for _ in csv.DictReader(stream))
        if count == rows:
            return {"file": filename, "rows": count, "cached": True}
    stream = remote_records(filename)
    try:
        with target.with_suffix(".partial").open("w", encoding="utf-8", newline="") as dest:
            writer = None
            count = 0
            for record in islice(stream, rows):
                projected = project_record(record)
                if writer is None:
                    writer = csv.DictWriter(dest, fieldnames=list(projected))
                    writer.writeheader()
                writer.writerow(projected)
                count += 1
        target.with_suffix(".partial").replace(target)
    finally:
        stream.close()
    print(f"{filename}: {count} records", flush=True)
    return {"file": filename, "rows": count, "cached": False}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--rows-per-file", type=int, default=5000)
    parser.add_argument("--output", type=Path, default=Path("output/smarttraffic_eta/sample"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=3) as pool:
        results = list(pool.map(lambda i: collect(i, args.rows_per_file, args.output), range(10)))
    manifest = {"dataset": DATASET, "synthetic": True,
                "sampling": "First N records in each of 10 files; not a random/full-dataset sample",
                "files": results}
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()

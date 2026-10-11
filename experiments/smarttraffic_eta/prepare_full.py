"""Stream ALL ten IoT files into compressed traffic-only CSVs, validating ZIP CRC."""
import argparse
import csv
import gzip
import hashlib
import json
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

from source import DATASET, project_record, remote_records


def process_file(index, output):
    output = Path(output)
    filename = f"traffic_data_{index}.json"
    target = output / f"traffic_{index}.csv.gz"
    receipt = output / f"traffic_{index}.receipt.json"
    if target.exists() and receipt.exists():
        info = json.loads(receipt.read_text(encoding="utf-8"))
        with target.open("rb") as cached:
            digest = hashlib.file_digest(cached, "sha256").hexdigest()
        if digest == info["sha256"]:
            return info
    count = 0
    with gzip.open(target.with_suffix(".partial"), "wt", encoding="utf-8", newline="") as dest:
        writer = None
        for record in remote_records(filename):
            row = project_record(record)
            if writer is None:
                writer = csv.DictWriter(dest, fieldnames=list(row))
                writer.writeheader()
            writer.writerow(row)
            count += 1
            if count % 250000 == 0:
                print(f"{filename}: {count:,} rows", flush=True)
    target.with_suffix(".partial").replace(target)
    with target.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    info = {"source": filename, "rows": count, "sha256": digest, "zip_crc_verified": True}
    receipt.write_text(json.dumps(info, indent=2), encoding="utf-8")
    print(f"Finished {filename}: {count:,}", flush=True)
    return info


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("output/smarttraffic_eta/full"))
    parser.add_argument("--workers", type=int, default=3)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(process_file, i, str(args.output)) for i in range(10)]
        results = [f.result() for f in as_completed(futures)]
    (args.output / "manifest.json").write_text(json.dumps({
        "dataset": DATASET, "synthetic": True, "scope": "All records in all ten IoT JSON files",
        "total_records": sum(r["rows"] for r in results),
        "files": sorted(results, key=lambda r: r["source"]),
    }, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()

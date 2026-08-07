from __future__ import annotations

import argparse
import shutil
import urllib.request
import zipfile
from pathlib import Path


DATASET_URL = (
    "https://www.kaggle.com/api/v1/datasets/download/"
    "thanhnguyen2612/traffic-flow-data-in-ho-chi-minh-city-viet-nam"
    "?datasetVersionNumber=6"
)
REQUIRED_FILES = {
    "nodes.csv",
    "segments.csv",
    "segment_status.csv",
    "streets.csv",
    "train.csv",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Download public HCMC traffic data.")
    parser.add_argument(
        "--output-dir", type=Path, default=Path("data/hcm_traffic_raw")
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    archive = output_dir / "hcm_traffic.zip"

    request = urllib.request.Request(
        DATASET_URL,
        headers={"User-Agent": "GiaoHang-ETA-Benchmark/1.0"},
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        with archive.open("wb") as destination:
            shutil.copyfileobj(response, destination)

    with zipfile.ZipFile(archive) as package:
        members = {Path(item.filename).name: item for item in package.infolist()}
        missing = REQUIRED_FILES - members.keys()
        if missing:
            raise RuntimeError(f"Dataset archive is missing: {sorted(missing)}")
        for filename in sorted(REQUIRED_FILES):
            source = members[filename]
            target = (output_dir / filename).resolve()
            if output_dir not in target.parents:
                raise RuntimeError(f"Unsafe archive path: {filename}")
            with package.open(source) as zipped, target.open("wb") as extracted:
                shutil.copyfileobj(zipped, extracted)

    print(f"Downloaded {len(REQUIRED_FILES)} CSV files to {output_dir}")


if __name__ == "__main__":
    main()

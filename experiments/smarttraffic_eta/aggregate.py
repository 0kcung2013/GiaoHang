"""Aggregate motorbike labels by road/time; weights retain every valid observation."""
import argparse
import json
from collections import Counter
from pathlib import Path

import pandas as pd


def clean_motorbikes(frame):
    selected = frame[frame.vehicle_type == "Motorbike"].copy()
    selected["time"] = pd.to_datetime(selected.timestamp, errors="coerce")
    for key in ["latitude", "longitude", "speed_kmph"]:
        selected[key] = pd.to_numeric(selected[key], errors="coerce")
    selected = selected.dropna(subset=["time", "latitude", "longitude", "speed_kmph", "street", "district"])
    selected = selected[selected.latitude.between(-90, 90) & selected.longitude.between(-180, 180) & selected.speed_kmph.between(0, 90)]
    selected["road"] = selected.district + "|" + selected.street
    return selected


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=Path("output/smarttraffic_eta/full"))
    parser.add_argument("--output", type=Path, default=Path("output/smarttraffic_eta/full_model"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((args.input / "manifest.json").read_text())
    parts, geography = [], []
    vehicle_counts = Counter()
    total = valid = 0
    for file in sorted(args.input.glob("traffic_*.csv.gz")):
        for chunk in pd.read_csv(file, chunksize=100000):
            vehicle_counts.update(chunk.vehicle_type.value_counts().to_dict())
            total += len(chunk)
            frame = clean_motorbikes(chunk)
            valid += len(frame)
            frame["speed_squared"] = frame.speed_kmph ** 2
            parts.append(frame.groupby(["road", "time"]).agg(
                count=("speed_kmph", "size"), speed_sum=("speed_kmph", "sum"),
                speed_sq_sum=("speed_squared", "sum"), minimum=("speed_kmph", "min"), maximum=("speed_kmph", "max")).reset_index())
            geography.append(frame.groupby("road").agg(
                lat_min=("latitude", "min"), lat_max=("latitude", "max"),
                lon_min=("longitude", "min"), lon_max=("longitude", "max")).reset_index())
        print(f"Aggregated {file.name}: {total:,} total records", flush=True)
    if total != manifest["total_records"]:
        raise ValueError("Input record count differs from acquisition manifest")
    grouped = pd.concat(parts).groupby(["road", "time"]).agg(
        count=("count", "sum"), speed_sum=("speed_sum", "sum"),
        speed_sq_sum=("speed_sq_sum", "sum"), minimum=("minimum", "min"), maximum=("maximum", "max")).reset_index()
    grouped["speed_kmph"] = grouped.speed_sum / grouped["count"]
    grouped.to_csv(args.output / "road_time_labels.csv.gz", index=False)
    pd.concat(geography).groupby("road").agg(
        lat_min=("lat_min", "min"), lat_max=("lat_max", "max"),
        lon_min=("lon_min", "min"), lon_max=("lon_max", "max")).to_csv(args.output / "road_coordinate_bounds.csv")
    (args.output / "data_audit.json").write_text(json.dumps({
        "total_records": total, "vehicle_counts": dict(vehicle_counts),
        "valid_motorbike_records": valid,
        "invalid_motorbike_records": vehicle_counts["Motorbike"] - valid,
        "road_time_groups": len(grouped), "roads": grouped.road.nunique(),
        "first_time": str(grouped.time.min()), "last_time": str(grouped.time.max()),
        "timestamp_assumption": "Asia/Ho_Chi_Minh; source does not specify offset",
        "aggregation": "All valid motorbike rows contribute; weighted group means preserve squared-loss training objective",
        "duplicates": "No global record-ID deduplication: source has no observation ID; every source row counts once",
    }, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()

"""Audit local motorbike labels to select demonstrable peak/off-peak hours."""
import argparse
import csv
import gzip
import json
from pathlib import Path


def audit(labels):
    hours = {hour: {"observations": 0, "speed_sum": 0.0} for hour in range(24)}
    days, roads = set(), set()
    with gzip.open(labels, "rt", encoding="utf-8", newline="") as stream:
        for row in csv.DictReader(stream):
            timestamp = row["time"]
            count = int(row["count"])
            group = hours[int(timestamp[11:13])]
            group["observations"] += count
            group["speed_sum"] += float(row["speed_sum"])
            days.add(timestamp[:10])
            roads.add(row["road"])
    result = []
    for hour, group in hours.items():
        count = group["observations"]
        result.append({"hour": hour, "observations": count,
                       "mean_speed_kmh": group["speed_sum"] / count if count else None})
    return {"source": str(labels), "vehicle_type": "Motorbike", "synthetic": True,
            "aggregation": "Observation-weighted means, all validated motorbike records",
            "dates": sorted(days), "roads": len(roads), "hours": result,
            "selected_hours": {"peak": 7, "off_peak": 14},
            "forecast_reference_date": "2024-04-03", "timezone": "Asia/Ho_Chi_Minh"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--labels", type=Path,
                        default=Path("output/smarttraffic_eta/full_model/road_time_labels.csv.gz"))
    parser.add_argument("--output", type=Path,
                        default=Path("output/smarttraffic_eta/full_model/traffic_demo_hours.json"))
    args = parser.parse_args()
    report = audit(args.labels)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps({key: report["hours"][hour] for key, hour in report["selected_hours"].items()}))


if __name__ == "__main__":
    main()

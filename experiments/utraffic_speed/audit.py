"""Reproducible audit; source files are read only, derived files stay separate."""
import argparse
import json
from pathlib import Path

import numpy as np

from data import chronological_split, load_labels


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", type=Path, default=Path("data/hcm_traffic_raw"))
    parser.add_argument("--output-dir", type=Path, default=Path("output/utraffic_speed/audit"))
    args = parser.parse_args()
    labels, roads, audit = load_labels(args.data_dir)
    splits, split_info = chronological_split(labels)
    audit["split"] = split_info
    coverage = labels.groupby("segment_id").agg(rows=("velocity", "size"), days=("local_date", "nunique"), hours=("hour_bin", "nunique"), mean_speed=("velocity", "mean"))
    audit["coverage"] = {"rows_per_segment_quantiles": {str(k): float(v) for k, v in coverage.rows.quantile([0, .25, .5, .75, .9, 1]).items()},
                         "segments_single_observation": int(coverage.rows.eq(1).sum()),
                         "segments_multiple_hours": int(coverage.hours.gt(1).sum())}
    audit["hour_pairs"] = []
    for first, second in ((7, 14), (7, 12), (8, 14), (17, 14)):
        counts = labels[labels.hour_bin.isin([first, second])].groupby(["segment_id", "hour_bin"]).size().unstack(fill_value=0)
        both = counts.get(first, 0).gt(0) & counts.get(second, 0).gt(0)
        audit["hour_pairs"].append({"hours": [first, second], "segments_both_hours": int(both.sum())})
    args.output_dir.mkdir(parents=True, exist_ok=True)
    labels.to_pickle(args.output_dir / "labels.pkl")
    roads.to_pickle(args.output_dir / "roads.pkl")
    coverage.to_csv(args.output_dir / "segment_coverage.csv")
    labels.groupby("hour_bin").agg(rows=("velocity", "size"), mean_speed=("velocity", "mean"), median_speed=("velocity", "median"), segments=("segment_id", "nunique")).to_csv(args.output_dir / "hour_coverage.csv")
    labels.groupby("local_date").agg(rows=("velocity", "size"), mean_speed=("velocity", "mean"), segments=("segment_id", "nunique")).to_csv(args.output_dir / "date_coverage.csv")
    (args.output_dir / "audit.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2, default=int), encoding="utf-8")
    print(json.dumps(audit, ensure_ascii=False, indent=2, default=int))


if __name__ == "__main__":
    main()

"""Date-cluster uncertainty and macro checks expose temporal sample imbalance."""
import json
from pathlib import Path

import numpy as np
import pandas as pd


def main():
    root = Path(__file__).resolve().parents[2]
    directory = root / "output/utraffic_speed/model"
    frame = pd.read_csv(directory / "test_predictions.csv")
    local = pd.to_datetime(frame.updated_at, utc=True, format="mixed").dt.tz_convert("Asia/Ho_Chi_Minh")
    frame["date"] = local.dt.strftime("%Y-%m-%d")
    frame = frame[frame.velocity.gt(0)].copy()
    methods = ["fixed_25_kmh", "past_segment_hour_mean", "time_only", "road_time", "road_time_ids"]
    for name in methods:
        frame[name + "_error"] = np.abs(frame.length_m * 3.6 / frame[name] - frame.length_m * 3.6 / frame.velocity)
    by_date = frame.groupby("date").agg(rows=("velocity", "size"), **{name: (name + "_error", "sum") for name in methods})
    rng = np.random.default_rng(42)
    draws = rng.integers(0, len(by_date), size=(2000, len(by_date)))
    output = {"bootstrap_unit": "whole UTC+7 date, 2000 draws, seed 42; conditional on frozen model", "days": len(by_date), "comparisons": {}}
    count = by_date.rows.to_numpy()[draws].sum(axis=1)
    for other in methods:
        if other == "road_time":
            continue
        delta = by_date[other].to_numpy() - by_date.road_time.to_numpy()
        bootstrap = delta[draws].sum(axis=1) / count
        output["comparisons"][other] = {"improvement_mae_seconds": float(delta.sum() / by_date.rows.sum()),
                                        "date_cluster_95_interval_seconds": np.quantile(bootstrap, [.025, .975]).tolist(),
                                        "equal_date_mean_improvement_seconds": float((delta / by_date.rows).mean())}
    by_date.to_csv(directory / "test_date_errors.csv")
    (directory / "uncertainty.json").write_text(json.dumps(output, indent=2), encoding="utf-8")
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()

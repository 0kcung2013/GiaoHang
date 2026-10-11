"""Weighted training on all motorbike labels; evaluation on individual held-out rows."""
import argparse
import json
from pathlib import Path

import joblib
import lightgbm as lgb
import numpy as np
import pandas as pd

from aggregate import clean_motorbikes
from model import features


def train(frame, val, roads, include_road):
    model = lgb.LGBMRegressor(objective="regression", n_estimators=400,
        learning_rate=.04, num_leaves=15, max_depth=4, min_child_samples=20,
        reg_lambda=1, random_state=42, n_jobs=4, verbosity=-1)
    model.fit(features(frame, roads, include_road), frame.speed_kmph,
        sample_weight=frame["count"],
        eval_set=[(features(val, roads, include_road), val.speed_kmph)],
        eval_sample_weight=[val["count"]],
        callbacks=[lgb.early_stopping(30, verbose=False)])
    return model


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=Path("output/smarttraffic_eta/full"))
    parser.add_argument("--output", type=Path, default=Path("output/smarttraffic_eta/full_model"))
    args = parser.parse_args()
    frame = pd.read_csv(args.output / "road_time_labels.csv.gz", parse_dates=["time"])
    dates = sorted(frame.time.dt.normalize().unique())
    if len(dates) < 5:
        raise ValueError("Need at least five dates for a day-based split")
    val_start, test_start = pd.Timestamp(dates[-2]), pd.Timestamp(dates[-1])
    training = frame[frame.time < val_start]
    validation = frame[(frame.time >= val_start) & (frame.time < test_start)]
    testing = frame[frame.time >= test_start]
    roads = sorted(training.road.unique())
    models = {"road_time_lightgbm": train(training, validation, roads, True),
              "time_only_lightgbm": train(training, validation, roads, False)}
    average = float(training.speed_sum.sum() / training["count"].sum())
    # Road/hour mean is a stronger non-ML baseline, learned using training data only.
    profile_frame = training.assign(hour=training.time.dt.hour)
    profile = profile_frame.groupby(["road", "hour"])[["speed_sum", "count"]].sum()
    profile = profile.speed_sum / profile["count"]
    totals = {name: {"absolute": 0., "squared": 0.} for name in [*models, "fixed_25", "train_mean", "road_hour_mean"]}
    n = 0
    sum_y = sum_y2 = 0.
    for file in sorted(args.input.glob("traffic_*.csv.gz")):
        for chunk in pd.read_csv(file, chunksize=100000):
            batch = clean_motorbikes(chunk)
            batch = batch[batch.time >= test_start]
            if batch.empty:
                continue
            actual = batch.speed_kmph.to_numpy()
            predictions = {name: model.predict(features(batch, roads, name == "road_time_lightgbm")) for name, model in models.items()}
            keys = pd.MultiIndex.from_arrays([batch.road, batch.time.dt.hour])
            predictions.update(fixed_25=np.full(len(batch), 25.), train_mean=np.full(len(batch), average),
                               road_hour_mean=profile.reindex(keys).fillna(average).to_numpy())
            for name, prediction in predictions.items():
                error = prediction - actual
                totals[name]["absolute"] += float(np.abs(error).sum())
                totals[name]["squared"] += float(np.square(error).sum())
            n += len(batch)
            sum_y += actual.sum()
            sum_y2 += np.square(actual).sum()
        print(f"Evaluated {file.name}; held-out records so far: {n:,}", flush=True)
    if n != int(testing["count"].sum()):
        raise ValueError("Test count does not match aggregates")
    scores = {name: {"mae_kmph": value["absolute"]/n,
                    "rmse_kmph": float(np.sqrt(value["squared"]/n)),
                    "r2": 1-value["squared"]/(sum_y2-sum_y**2/n)} for name, value in totals.items()}
    report = {"dataset": "ren294/iot-car-hcmcity", "dataset_version": 1, "synthetic": True,
              "target": "Expected motorbike speed (km/h); not actual delivery duration",
              "train_records": int(training["count"].sum()), "validation_records": int(validation["count"].sum()),
              "test_records": n, "validation_start_local": str(val_start), "test_start_local": str(test_start),
              "timestamp_assumption": "Asia/Ho_Chi_Minh",
              "train_mean_kmph": average, "metrics": scores,
              "best_iterations": {k: v.best_iteration_ for k,v in models.items()},
              "approved_for_runtime": False}
    (args.output / "benchmark.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    for name, model in models.items():
        artifact = {"model": model, "roads": roads, "include_road": name == "road_time_lightgbm",
                    "timezone": "Asia/Ho_Chi_Minh", "synthetic": True, "approved_for_runtime": False}
        joblib.dump(artifact, args.output / f"{name}.joblib")
        (args.output / f"{name}.json").write_text(json.dumps(model.booster_.dump_model()), encoding="utf-8")
        pd.DataFrame({"feature": model.feature_name_, "gain": model.booster_.feature_importance(importance_type="gain")}).to_csv(args.output / f"{name}_importance.csv", index=False)
    print(json.dumps(report, indent=2), flush=True)


if __name__ == "__main__":
    main()

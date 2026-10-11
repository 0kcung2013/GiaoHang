"""Evaluate learnable road/time speed patterns before replacing the ETA model."""
import argparse
import json
from pathlib import Path

import joblib
import lightgbm as lgb
import numpy as np
import pandas as pd
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score


def features(frame, roads):
    hour = frame.time.dt.hour + frame.time.dt.minute / 60
    dow = frame.time.dt.dayofweek
    result = pd.DataFrame(index=frame.index)
    result["road"] = pd.Categorical(frame.road, categories=roads)
    result["latitude"] = frame.latitude
    result["longitude"] = frame.longitude
    for name, value, period in [("hour", hour, 24), ("weekday", dow, 7)]:
        result[f"{name}_sin"] = np.sin(2 * np.pi * value / period)
        result[f"{name}_cos"] = np.cos(2 * np.pi * value / period)
    result["weekend"] = (dow >= 5).astype(int)
    return result


def metrics(actual, predicted):
    return {"mae_kmph": float(mean_absolute_error(actual, predicted)),
            "rmse_kmph": float(np.sqrt(mean_squared_error(actual, predicted))),
            "r2": float(r2_score(actual, predicted))}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=Path("output/smarttraffic_eta/sample"))
    parser.add_argument("--output", type=Path, default=Path("output/smarttraffic_eta/audit"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    source = pd.concat([pd.read_csv(p) for p in sorted(args.input.glob("sample_*.csv"))], ignore_index=True)
    frame = source[source.vehicle_type == "Motorbike"].copy()
    # Source timestamps have no offset. HCMC local time is an explicit audit assumption.
    frame["time"] = pd.to_datetime(frame.timestamp, errors="coerce").dt.tz_localize("Asia/Ho_Chi_Minh")
    for col in ["speed_kmph", "latitude", "longitude"]:
        frame[col] = pd.to_numeric(frame[col], errors="coerce")
    frame = frame.dropna(subset=["time", "speed_kmph", "latitude", "longitude", "street", "district"])
    frame = frame[frame.speed_kmph.between(0, 90) & frame.latitude.between(-90, 90) & frame.longitude.between(-180, 180)]
    frame = frame.drop_duplicates().sort_values("time")
    frame["road"] = frame.district + "|" + frame.street
    times = frame.time.drop_duplicates().sort_values().tolist()
    if len(times) < 10:
        raise ValueError("Insufficient distinct times for chronological holdout")
    val_start, test_start = times[int(len(times)*.7)], times[int(len(times)*.85)]
    train = frame[frame.time < val_start]
    val = frame[(frame.time >= val_start) & (frame.time < test_start)]
    test = frame[frame.time >= test_start]
    roads = sorted(train.road.unique())
    x_train, x_val, x_test = [features(f, roads) for f in [train, val, test]]
    model = lgb.LGBMRegressor(objective="regression", n_estimators=400, learning_rate=.04,
                             num_leaves=15, max_depth=4, min_child_samples=100,
                             reg_lambda=1, random_state=42, n_jobs=4, verbosity=-1)
    model.fit(x_train, train.speed_kmph, eval_set=[(x_val, val.speed_kmph)],
              eval_metric="l2", callbacks=[lgb.early_stopping(30, verbose=False)])
    actual = test.speed_kmph.to_numpy()
    predictions = {"lightgbm": model.predict(x_test),
                   "fixed_25": np.full(len(test), 25.),
                   "train_mean": np.full(len(test), train.speed_kmph.mean()),
                   "train_median": np.full(len(test), train.speed_kmph.median())}
    scores = {name: metrics(actual, pred) for name, pred in predictions.items()}
    improvement = 1 - scores["lightgbm"]["mae_kmph"] / min(scores["train_mean"]["mae_kmph"], scores["train_median"]["mae_kmph"])
    # Explicit exploratory gate; passing still requires full-data and route validation.
    passes = improvement >= .05 and scores["lightgbm"]["r2"] > 0
    report = {
        "dataset": "ren294/iot-car-hcmcity", "synthetic": True,
        "sampling": "Prefix sample from every file; NOT full-dataset evaluation",
        "timestamp_assumption": "Naive source timestamps interpreted as Asia/Ho_Chi_Minh",
        "source_rows": len(source), "motorbike_rows": len(frame),
        "unique_times": len(times), "roads": frame.road.nunique(),
        "time_min": str(frame.time.min()), "time_max": str(frame.time.max()),
        "latitude_range": [float(frame.latitude.min()), float(frame.latitude.max())],
        "longitude_range": [float(frame.longitude.min()), float(frame.longitude.max())],
        "speed_summary": frame.speed_kmph.describe().to_dict(),
        "train_rows": len(train), "validation_rows": len(val), "test_rows": len(test),
        "validation_start": str(val_start), "test_start": str(test_start),
        "test_unseen_roads": int((~test.road.isin(roads)).sum()),
        "best_iteration": model.best_iteration_, "metrics": scores,
        "mae_improvement_over_best_constant": improvement,
        "gate": "MAE at least 5% below best train-only constant and R2 > 0",
        "passes_exploratory_gate": bool(passes), "approved_for_runtime": False,
        "limitations": ["Speed labels, not measured delivery or segment traversal times",
                        "Road/coordinate consistency not map-matched",
                        "Prefix sampling may omit patterns in other records"],
    }
    (args.output / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    joblib.dump({"model": model, "roads": roads, "approved_for_runtime": False}, args.output / "candidate.joblib")
    pd.DataFrame({"feature": x_train.columns, "gain": model.booster_.feature_importance(importance_type="gain")}).to_csv(args.output / "importance.csv", index=False)
    test.assign(predicted_speed=predictions["lightgbm"]).to_csv(args.output / "test_predictions.csv", index=False)
    print(json.dumps(report, indent=2), flush=True)


if __name__ == "__main__":
    main()

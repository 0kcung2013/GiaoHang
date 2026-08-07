from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from lightgbm import LGBMRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error
from sklearn.pipeline import Pipeline


FEATURE_NAMES = [
    "route_midpoint_lat",
    "route_midpoint_lng",
    "hour_sin",
    "hour_cos",
    "dow_sin",
    "dow_cos",
    "is_weekend",
    "is_peak_hour",
]

LOS_MULTIPLIER = {
    "A": 1.00,
    "B": 1.15,
    "C": 1.35,
    "D": 1.60,
    "E": 2.00,
    "F": 2.50,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Train a compact historical-congestion model from HCMC UTraffic data."
    )
    parser.add_argument(
        "--data-dir", type=Path, default=Path("data/hcm_traffic_raw")
    )
    parser.add_argument(
        "--output-dir", type=Path, default=Path("output/hcm_traffic_eta")
    )
    return parser.parse_args()


def is_peak_hour(local_time: pd.Series) -> pd.Series:
    minute = local_time.dt.hour * 60 + local_time.dt.minute
    return (
        ((minute >= 6 * 60 + 30) & (minute < 9 * 60))
        | ((minute >= 16 * 60 + 30) & (minute < 19 * 60 + 30))
    ).astype(float)


def build_features(frame: pd.DataFrame) -> pd.DataFrame:
    local_time = frame["local_time"]
    hour = local_time.dt.hour + local_time.dt.minute / 60.0
    day_of_week = local_time.dt.weekday.astype(float)
    return pd.DataFrame(
        {
            "route_midpoint_lat": frame["route_midpoint_lat"].astype(float),
            "route_midpoint_lng": frame["route_midpoint_lng"].astype(float),
            "hour_sin": np.sin(2 * math.pi * hour / 24),
            "hour_cos": np.cos(2 * math.pi * hour / 24),
            "dow_sin": np.sin(2 * math.pi * day_of_week / 7),
            "dow_cos": np.cos(2 * math.pi * day_of_week / 7),
            "is_weekend": (day_of_week >= 5).astype(float),
            "is_peak_hour": is_peak_hour(local_time),
        },
        index=frame.index,
    )[FEATURE_NAMES]


def prepare_data(data_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, pd.Timestamp]:
    status = pd.read_csv(data_dir / "train.csv")
    period_parts = status["period"].str.extract(r"period_(\d{1,2})_(\d{2})")
    minute_offset = period_parts[0].astype(int) * 60 + period_parts[1].astype(int)
    status["local_time"] = pd.to_datetime(status["date"]) + pd.to_timedelta(
        minute_offset, unit="m"
    )
    status["updated_at"] = status["local_time"].dt.tz_localize(
        "Asia/Ho_Chi_Minh"
    ).dt.tz_convert("UTC")
    status["route_midpoint_lat"] = (
        status["lat_snode"] + status["lat_enode"]
    ) / 2
    status["route_midpoint_lng"] = (
        status["long_snode"] + status["long_enode"]
    ) / 2
    status["target_multiplier"] = status["LOS"].map(LOS_MULTIPLIER)
    status = status.dropna(
        subset=["target_multiplier", "route_midpoint_lat", "route_midpoint_lng"]
    ).sort_values("updated_at")

    cutoff = status["updated_at"].quantile(0.8)
    train = status[status["updated_at"] < cutoff].copy()
    test = status[status["updated_at"] >= cutoff].copy()
    for frame in (train, test):
        frame["target_log_multiplier"] = np.log(frame["target_multiplier"])
    return train, test, cutoff


def main() -> None:
    args = parse_args()
    train, test, cutoff = prepare_data(args.data_dir)
    x_train = build_features(train)
    x_test = build_features(test)
    y_train = train["target_log_multiplier"]
    y_test = test["target_log_multiplier"]

    pipeline = Pipeline(
        [
            (
                "model",
                LGBMRegressor(
                    objective="regression_l1",
                    n_estimators=72,
                    learning_rate=0.045,
                    num_leaves=15,
                    max_depth=4,
                    min_child_samples=80,
                    subsample=0.9,
                    colsample_bytree=1.0,
                    reg_lambda=0.25,
                    random_state=42,
                    verbosity=-1,
                ),
            )
        ]
    )
    pipeline.fit(x_train, y_train)

    predicted_log = pipeline.predict(x_test)
    predicted_multiplier = np.exp(predicted_log).clip(1.0, 2.5)
    actual_multiplier = test["target_multiplier"].to_numpy()
    heuristic_multiplier = np.where(
        x_test["is_peak_hour"].to_numpy() == 1, 1.25, 1.10
    )
    metrics = {
        "model_multiplier_mae": float(
            mean_absolute_error(actual_multiplier, predicted_multiplier)
        ),
        "heuristic_multiplier_mae": float(
            mean_absolute_error(actual_multiplier, heuristic_multiplier)
        ),
        "model_log_rmse": float(mean_squared_error(y_test, predicted_log) ** 0.5),
    }

    args.output_dir.mkdir(parents=True, exist_ok=True)
    joblib.dump(pipeline, args.output_dir / "model_lightgbm.joblib")
    pd.DataFrame(
        {
            "feature": FEATURE_NAMES,
            "importance": pipeline.named_steps["model"].feature_importances_,
        }
    ).sort_values("importance", ascending=False).to_csv(
        args.output_dir / "feature_importance.csv", index=False
    )
    pd.DataFrame([metrics]).to_csv(args.output_dir / "metrics.csv", index=False)
    metadata = {
        "model_version": "hcm_utraffic_lgbm_v1",
        "dataset": "Traffic Flow data in Ho Chi Minh City, Viet Nam (UTraffic)",
        "dataset_scope": "TP.HCM historical traffic",
        "is_realtime": False,
        "supported_bounds": {
            "min_lat": float(train["route_midpoint_lat"].quantile(0.01)),
            "max_lat": float(train["route_midpoint_lat"].quantile(0.99)),
            "min_lng": float(train["route_midpoint_lng"].quantile(0.01)),
            "max_lng": float(train["route_midpoint_lng"].quantile(0.99)),
        },
        "feature_names": FEATURE_NAMES,
        "train_rows": len(train),
        "test_rows": len(test),
        "split_utc": cutoff.isoformat(),
        "source_min_utc": train["updated_at"].min().isoformat(),
        "source_max_utc": test["updated_at"].max().isoformat(),
        "metrics": metrics,
    }
    (args.output_dir / "metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    report = f"""# HCMC historical traffic ETA model

- Dataset: UTraffic / Ho Chi Minh City traffic flow.
- Target: historical LOS converted to a congestion multiplier.
- Split: chronological at `{cutoff.isoformat()}`.
- Train/test: {len(train):,}/{len(test):,} observations.
- Model multiplier MAE: {metrics['model_multiplier_mae']:.4f}.
- Existing peak heuristic multiplier MAE: {metrics['heuristic_multiplier_mae']:.4f}.

This is a historical congestion prior, not live traffic and not a delivery-time model.
It uses the route midpoint to learn broad spatial patterns but does not replace OSRM.
The Flutter app applies it only inside the supported TP.HCM bounds and keeps the
existing ETA fallback elsewhere.
"""
    (args.output_dir / "report.md").write_text(report, encoding="utf-8")
    print(json.dumps(metadata, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

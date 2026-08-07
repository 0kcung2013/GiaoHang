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
    "route_midpoint_lat", "route_midpoint_lng", "hour_sin", "hour_cos",
    "dow_sin", "dow_cos", "is_weekend", "is_peak_hour",
    "road_length_meters", "road_speed_limit_kmh", "road_level",
    "historical_speed_ratio",
]
LOS_MULTIPLIER = {"A": 1.00, "B": 1.15, "C": 1.35, "D": 1.60, "E": 2.00, "F": 2.50}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Train a historical congestion model from all five HCMC UTraffic CSV files."
    )
    parser.add_argument("--data-dir", type=Path, default=Path("data/hcm_traffic_raw"))
    parser.add_argument("--output-dir", type=Path, default=Path("output/hcm_traffic_eta"))
    return parser.parse_args()


def is_peak_hour(local_time: pd.Series) -> pd.Series:
    minute = local_time.dt.hour * 60 + local_time.dt.minute
    return (((minute >= 390) & (minute < 540)) | ((minute >= 990) & (minute < 1140))).astype(float)


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
            "road_length_meters": frame["road_length_meters"].astype(float),
            "road_speed_limit_kmh": frame["road_speed_limit_kmh"].astype(float),
            "road_level": frame["road_level"].astype(float),
            "historical_speed_ratio": frame["historical_speed_ratio"].astype(float),
        },
        index=frame.index,
    )[FEATURE_NAMES]


def load_road_network(data_dir: Path) -> pd.DataFrame:
    nodes = pd.read_csv(data_dir / "nodes.csv").rename(
        columns={"_id": "node_id", "lat": "node_lat", "long": "node_lng"}
    )[["node_id", "node_lat", "node_lng"]]
    streets = pd.read_csv(data_dir / "streets.csv").rename(
        columns={"_id": "street_id", "max_velocity": "street_speed_limit_kmh"}
    )[["street_id", "street_speed_limit_kmh"]]
    segments = pd.read_csv(data_dir / "segments.csv").rename(
        columns={
            "_id": "segment_id", "max_velocity": "segment_speed_limit_kmh",
            "street_level": "segment_level", "length": "segment_length_meters",
        }
    )[["segment_id", "s_node_id", "e_node_id", "street_id", "segment_speed_limit_kmh", "segment_level", "segment_length_meters"]]
    starts = nodes.rename(columns={"node_id": "s_node_id", "node_lat": "start_lat", "node_lng": "start_lng"})
    ends = nodes.rename(columns={"node_id": "e_node_id", "node_lat": "end_lat", "node_lng": "end_lng"})
    roads = segments.merge(starts, on="s_node_id", how="inner").merge(ends, on="e_node_id", how="inner").merge(streets, on="street_id", how="left")
    roads["route_midpoint_lat"] = (roads["start_lat"] + roads["end_lat"]) / 2
    roads["route_midpoint_lng"] = (roads["start_lng"] + roads["end_lng"]) / 2
    roads["road_length_meters"] = roads["segment_length_meters"].fillna(100.0)
    roads["road_speed_limit_kmh"] = roads["segment_speed_limit_kmh"].fillna(roads["street_speed_limit_kmh"]).fillna(35.0)
    roads["road_level"] = roads["segment_level"].fillna(3.0)
    return roads[["segment_id", "route_midpoint_lat", "route_midpoint_lng", "road_length_meters", "road_speed_limit_kmh", "road_level"]]


def build_historical_speed_profile(data_dir: Path, roads: pd.DataFrame, cutoff: pd.Timestamp) -> pd.Series:
    """Freeze the profile before the test period to prevent time leakage."""
    status = pd.read_csv(data_dir / "segment_status.csv")
    status["updated_at"] = pd.to_datetime(status["updated_at"], utc=True)
    status = status.merge(roads[["segment_id", "road_speed_limit_kmh"]], on="segment_id", how="inner")
    status = status[(status["updated_at"] < cutoff) & status["velocity"].between(3, 90) & status["road_speed_limit_kmh"].gt(0)].copy()
    status["speed_ratio"] = (status["road_speed_limit_kmh"] / status["velocity"]).clip(1.0, 2.5)
    return status.groupby("segment_id")["speed_ratio"].mean()


def prepare_data(data_dir: Path) -> tuple[pd.DataFrame, pd.DataFrame, pd.Timestamp, pd.DataFrame]:
    labels = pd.read_csv(data_dir / "train.csv")
    period = labels["period"].str.extract(r"period_(\d{1,2})_(\d{2})")
    offset = period[0].astype(int) * 60 + period[1].astype(int)
    labels["local_time"] = pd.to_datetime(labels["date"]) + pd.to_timedelta(offset, unit="m")
    labels["updated_at"] = labels["local_time"].dt.tz_localize("Asia/Ho_Chi_Minh").dt.tz_convert("UTC")
    labels["target_multiplier"] = labels["LOS"].map(LOS_MULTIPLIER)
    labels = labels.dropna(subset=["target_multiplier"]).sort_values("updated_at")
    cutoff = labels["updated_at"].quantile(0.8)

    roads = load_road_network(data_dir)
    profile = build_historical_speed_profile(data_dir, roads, cutoff)
    roads["historical_speed_ratio"] = roads["segment_id"].map(profile).fillna(float(profile.mean()))
    # Rebuild the geometry and road attributes from nodes/segments/streets,
    # rather than relying on duplicates in the label CSV.
    labels = labels[["segment_id", "local_time", "updated_at", "target_multiplier"]].merge(roads, on="segment_id", how="inner")
    labels = labels.dropna(
        subset=[
            "route_midpoint_lat",
            "route_midpoint_lng",
            "road_length_meters",
            "road_speed_limit_kmh",
            "road_level",
            "historical_speed_ratio",
        ]
    )
    train = labels[labels["updated_at"] < cutoff].copy()
    test = labels[labels["updated_at"] >= cutoff].copy()
    for frame in (train, test):
        frame["target_log_multiplier"] = np.log(frame["target_multiplier"])
    profile_rows = roads[roads["segment_id"].isin(labels["segment_id"].unique())].copy()
    return train, test, cutoff, profile_rows


def main() -> None:
    args = parse_args()
    train, test, cutoff, profile_rows = prepare_data(args.data_dir)
    x_train, x_test = build_features(train), build_features(test)
    pipeline = Pipeline([("model", LGBMRegressor(
        objective="regression_l1", n_estimators=72, learning_rate=0.045,
        num_leaves=15, max_depth=4, min_child_samples=80, subsample=0.9,
        colsample_bytree=1.0, reg_lambda=0.25, random_state=42, verbosity=-1,
    ))])
    pipeline.fit(x_train, train["target_log_multiplier"])
    prediction = np.exp(pipeline.predict(x_test)).clip(1.0, 2.5)
    actual = test["target_multiplier"].to_numpy()
    heuristic = np.where(x_test["is_peak_hour"].to_numpy() == 1, 1.25, 1.10)
    metrics = {
        "model_multiplier_mae": float(mean_absolute_error(actual, prediction)),
        "heuristic_multiplier_mae": float(mean_absolute_error(actual, heuristic)),
        "model_log_rmse": float(mean_squared_error(test["target_log_multiplier"], np.log(prediction)) ** 0.5),
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    joblib.dump(pipeline, args.output_dir / "model_lightgbm.joblib")
    profile_rows.to_csv(args.output_dir / "road_profiles.csv", index=False)
    pd.DataFrame({"feature": FEATURE_NAMES, "importance": pipeline.named_steps["model"].feature_importances_}).sort_values("importance", ascending=False).to_csv(args.output_dir / "feature_importance.csv", index=False)
    pd.DataFrame([metrics]).to_csv(args.output_dir / "metrics.csv", index=False)
    metadata = {
        "model_version": "hcm_utraffic_lgbm_v2_road_profile",
        "dataset": "Traffic Flow data in Ho Chi Minh City, Viet Nam (UTraffic)",
        "dataset_scope": "TP.HCM historical traffic", "is_realtime": False,
        "source_files": ["nodes.csv", "segments.csv", "segment_status.csv", "streets.csv", "train.csv"],
        "historical_profile_cutoff_utc": cutoff.isoformat(),
        "feature_names": FEATURE_NAMES, "train_rows": len(train), "test_rows": len(test),
        "road_profile_rows": len(profile_rows), "split_utc": cutoff.isoformat(),
        "metrics": metrics,
    }
    (args.output_dir / "metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    (args.output_dir / "report.md").write_text(
        "# HCMC historical traffic ETA model\n\n"
        "- Dataset: five UTraffic CSV files (nodes, segments, segment_status, streets, train).\n"
        f"- Split: chronological at `{cutoff.isoformat()}`.\n"
        f"- Train/test: {len(train):,}/{len(test):,} observations.\n"
        f"- Road profiles exported for Flutter: {len(profile_rows):,}.\n"
        f"- Model multiplier MAE: {metrics['model_multiplier_mae']:.4f}.\n"
        f"- Peak-hour baseline MAE: {metrics['heuristic_multiplier_mae']:.4f}.\n\n"
        "The velocity profile is historical, frozen before the test period; it is not realtime traffic.\n",
        encoding="utf-8",
    )
    print(json.dumps(metadata, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

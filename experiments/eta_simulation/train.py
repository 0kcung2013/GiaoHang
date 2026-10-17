"""Learn synthetic route delay ratios; entire origin areas stay out of training."""
from __future__ import annotations

import argparse
import json
import math
from datetime import datetime, timedelta, timezone
from pathlib import Path

import joblib
import lightgbm as lgb
import numpy as np
import pandas as pd

from features import FEATURE_NAMES, static_features, timed_features
from simulator import SIMULATOR_VERSION, expected_seconds, simulate_seconds


def metrics(frame, seconds):
    values = np.asarray(seconds, float)
    actual = frame.simulated_travel_s.to_numpy(float)
    if not np.isfinite(values).all() or (values <= 0).any():
        raise ValueError("INVALID_PREDICTION")
    error = values - actual
    relative = np.abs(error) / actual
    per_route = pd.Series(np.abs(error)).groupby(frame.route_id.to_numpy()).mean()
    return {"rows": len(frame), "routes": int(frame.route_id.nunique()),
            "mae_seconds": float(np.abs(error).mean()), "bias_seconds": float(error.mean()),
            "p90_absolute_seconds": float(np.quantile(np.abs(error), .9)),
            "mean_absolute_percentage": float(relative.mean()), "p90_absolute_percentage": float(np.quantile(relative, .9)),
            "within_15_percent": float((relative <= .15).mean()),
            "equal_route_mae_seconds": float(per_route.mean())}


def main():
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", type=Path, default=root / "output/eta_simulation")
    parser.add_argument("--samples-per-route", type=int, default=48)
    args = parser.parse_args()
    context = json.loads((args.directory / "context.json").read_text(encoding="utf-8"))
    routes = json.loads((args.directory / "routes.json").read_text(encoding="utf-8"))
    rng = np.random.default_rng(20261013)
    static, areas = {}, {}
    for record in routes:
        route_id = record["route_id"]
        static[route_id] = static_features(record["route"], context)
        p = record["route"]["geometry"]["coordinates"][0]
        areas[route_id] = f"{math.floor(p[0] / .01)},{math.floor(p[1] / .01)}"
    groups = sorted(set(areas.values()))
    rng.shuffle(groups)
    train_end, validation_end = int(len(groups) * .7), int(len(groups) * .85)
    group_split = {g: "train" if i < train_end else "validation" if i < validation_end else "test" for i, g in enumerate(groups)}
    rows = []
    monday = datetime(2026, 10, 5, tzinfo=timezone(timedelta(hours=7)))
    for record in routes:
        route_id = record["route_id"]
        for sample in range(args.samples_per_route):
            weekday = int(rng.integers(0, 7))
            minute = int(rng.integers(0, 1440))
            at = (monday + timedelta(days=weekday, minutes=minute)).isoformat()
            f = timed_features(static[route_id], at)
            actual = simulate_seconds(f, rng)
            baseline = record["route"]["duration"]
            rows.append({"sample_id": f"{route_id}_{sample}", "route_id": route_id,
                         "origin_area": areas[route_id], "split": group_split[areas[route_id]], "departure_at": at,
                         **f, "baseline_s": baseline, "expected_travel_s": expected_seconds(f),
                         "simulated_travel_s": actual, "delay_s": actual - baseline,
                         "delay_ratio": actual / baseline - 1, "label_source": "simulation"})
    frame = pd.DataFrame(rows)
    frame.to_csv(args.directory / "simulated_trips.csv", index=False)
    splits = {name: frame[frame.split.eq(name)].copy() for name in ["train", "validation", "test"]}
    if any(part.empty for part in splits.values()):
        raise ValueError("EMPTY_ROUTE_SPLIT")
    for first, second in [("train", "validation"), ("train", "test"), ("validation", "test")]:
        assert set(splits[first].route_id).isdisjoint(splits[second].route_id)
        assert set(splits[first].origin_area).isdisjoint(splits[second].origin_area)
    train, validation, test = (splits[name] for name in ["train", "validation", "test"])
    candidates, winner, best = [], None, math.inf
    for leaves, depth in [(31, 6), (63, 8)]:
        model = lgb.LGBMRegressor(objective="regression", metric="None", n_estimators=650, learning_rate=.04,
                                 num_leaves=leaves, max_depth=depth, min_child_samples=60, reg_lambda=1,
                                 random_state=20261012, n_jobs=4, deterministic=True, force_col_wise=True, verbosity=-1)

        def validation_metric(actual, prediction):
            values = validation.baseline_s.to_numpy() * np.clip(1 + prediction, .5, 5)
            return "travel_mae_seconds", metrics(validation, values)["mae_seconds"], False

        model.fit(train[FEATURE_NAMES], train.delay_ratio,
                  eval_X=validation[FEATURE_NAMES], eval_y=validation.delay_ratio,
                  eval_metric=validation_metric, callbacks=[lgb.early_stopping(55, verbose=False)])
        prediction = validation.baseline_s.to_numpy() * np.clip(1 + model.predict(validation[FEATURE_NAMES]), .5, 5)
        score = metrics(validation, prediction)
        candidates.append({"leaves": leaves, "depth": depth, "trees": model.best_iteration_, "validation": score})
        print(json.dumps(candidates[-1]), flush=True)
        if score["mae_seconds"] < best:
            winner, best = model, score["mae_seconds"]
    # Freeze the validation winner before this first test read.
    joblib.dump(winner, args.directory / "model.joblib")
    predicted = test.baseline_s.to_numpy() * np.clip(1 + winner.predict(test[FEATURE_NAMES]), .5, 5)
    test_predictions = test.copy()
    test_predictions["predicted_travel_s"] = predicted
    test_predictions.to_csv(args.directory / "test_predictions.csv", index=False)
    reference = metrics(test, predicted)
    baselines = {"road_profile": metrics(test, test.baseline_s), "fixed_25_kmh": metrics(test, test.distance_km * 144),
                 "simulator_expected_without_random_noise": metrics(test, test.expected_travel_s)}
    acceptance = {"mean_absolute_percentage_at_most_10_percent": reference["mean_absolute_percentage"] <= .1,
                  "p90_absolute_percentage_at_most_15_percent": reference["p90_absolute_percentage"] <= .15,
                  "beats_road_profile_mae": reference["mae_seconds"] < baselines["road_profile"]["mae_seconds"],
                  "beats_fixed_25_mae": reference["mae_seconds"] < baselines["fixed_25_kmh"]["mae_seconds"]}
    by_distance = {}
    for name, mask in {"under_1_km": test.distance_km.lt(1), "1_to_5_km": test.distance_km.between(1, 5),
                       "over_5_to_15_km": test.distance_km.gt(5) & test.distance_km.le(15), "over_15_km": test.distance_km.gt(15)}.items():
        if mask.any():
            by_distance[name] = metrics(test.loc[mask], predicted[mask.to_numpy()])
    report = {"model_version": "hcm_synthetic_route_eta_v1", "is_synthetic": True, "simulator_version": SIMULATOR_VERSION,
              "selection": "validation travel MAE; test and complete origin areas held out", "feature_names": FEATURE_NAMES,
              "model_target": "delay_ratio = synthetic_travel_seconds / routing_baseline_seconds - 1",
              "split": {name: {"rows": len(part), "routes": int(part.route_id.nunique()), "origin_areas": int(part.origin_area.nunique())} for name, part in splits.items()},
              "origin_areas_disjoint": True, "route_ids_disjoint": True, "candidates": candidates,
              "test": reference, "baselines": baselines, "test_by_distance": by_distance, "acceptance": acceptance,
              "status": "passed_synthetic_benchmark" if all(acceptance.values()) else "needs_improvement",
              "label_limit": "Synthetic traffic rules with 3.5% random variation; does not measure real-world ETA accuracy"}
    (args.directory / "benchmark.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    pd.DataFrame({"feature": FEATURE_NAMES, "gain": winner.booster_.feature_importance(importance_type="gain")}).sort_values("gain", ascending=False).to_csv(args.directory / "feature_importance.csv", index=False)
    print(json.dumps({"split": report["split"], "test": reference, "baselines": baselines, "acceptance": acceptance}, indent=2), flush=True)


if __name__ == "__main__":
    main()

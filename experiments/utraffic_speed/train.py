"""Validation selects configurations; untouched chronological test compares methods."""
from __future__ import annotations

import argparse
import json
import platform
import time
from pathlib import Path

import joblib
import lightgbm as lgb
import numpy as np
import pandas as pd
import sklearn

from data import chronological_split
from features import FEATURE_SCOPES, features, speed_from_output
from metrics import evaluate, hierarchical_baseline, subgroups

VERSION = "hcm_utraffic_segment_speed_v1"
# All choices declared before test evaluation; the test is never used by early stopping.
CAPACITIES = [(15, 4, 80), (31, 6, 40)]
OBJECTIVES = [("raw_l1", "regression_l1", "raw"), ("raw_l2", "regression", "raw"), ("log1p_l2", "regression", "log1p")]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--audit-dir", type=Path, default=Path("output/utraffic_speed/audit"))
    parser.add_argument("--output-dir", type=Path, default=Path("output/utraffic_speed/model"))
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    labels = pd.read_pickle(args.audit_dir / "labels.pkl")
    splits, split_info = chronological_split(labels)
    train, validation, test = (splits[k] for k in ("train", "validation", "test"))
    metadata = {"version": VERSION, "split": split_info, "selection": "minimum validation d/v duration MAE seconds; speed MAE breaks ties",
                "duration_reference": "segment.length_m * 3.6 / observed_velocity; positive labels only",
                "speed_prediction_bounds_kmh": [1, 90], "zero_policy": "retained as speed labels; excluded only from d/v metrics; predicted speed floored at 1 for finite runtime duration",
                "is_synthetic": False, "is_realtime": False, "uses_app_gps": False,
                "versions": {"python": platform.python_version(), "lightgbm": lgb.__version__, "numpy": np.__version__, "pandas": pd.__version__, "sklearn": sklearn.__version__},
                "validation_candidates": [], "selected_by_scope": {}, "test": {}}
    # Baselines are fixed before inspecting test results.
    metadata["test"]["fixed_25_kmh"] = {"metrics": evaluate(test, np.full(len(test), 25.0)), "subgroups": subgroups(test, np.full(len(test), 25.0), train)}
    baseline_test, levels = hierarchical_baseline(train, test)
    baseline_val, _ = hierarchical_baseline(train, validation)
    metadata["test"]["past_segment_hour_mean"] = {"metrics": evaluate(test, baseline_test), "subgroups": subgroups(test, baseline_test, train), "fallback_levels": levels}
    metadata["baseline_validation"] = evaluate(validation, baseline_val)
    winners = {}
    for scope in FEATURE_SCOPES:
        x_train, x_val = features(train, scope), features(validation, scope)
        best_key, best = None, None
        for objective_name, objective, target in OBJECTIVES:
            y_train = np.log1p(train.velocity) if target == "log1p" else train.velocity
            y_val = np.log1p(validation.velocity) if target == "log1p" else validation.velocity

            def eta_metric(actual, output):
                score = evaluate(validation, speed_from_output(output, target))
                return "duration_mae_seconds", score["duration_mae_seconds"], False

            for leaves, depth, minimum in CAPACITIES:
                started = time.perf_counter()
                model = lgb.LGBMRegressor(objective=objective, metric="None", n_estimators=600, learning_rate=.045,
                                         num_leaves=leaves, max_depth=depth, min_child_samples=minimum,
                                         reg_lambda=.5, random_state=42, n_jobs=4, verbosity=-1,
                                         deterministic=True, force_col_wise=True)
                model.fit(x_train, y_train, eval_X=x_val, eval_y=y_val, eval_metric=eta_metric,
                          callbacks=[lgb.early_stopping(60, verbose=False)])
                values = speed_from_output(model.predict(x_val), target)
                score = evaluate(validation, values)
                candidate = {"scope": scope, "objective_name": objective_name, "target": target,
                             "num_leaves": leaves, "max_depth": depth, "min_child_samples": minimum,
                             "trees": model.best_iteration_, "seconds": time.perf_counter() - started, "validation": score}
                metadata["validation_candidates"].append(candidate)
                key = (score["duration_mae_seconds"], score["speed_mae_kmh"])
                print(json.dumps({"scope": scope, "objective": objective_name, "leaves": leaves, "trees": model.best_iteration_, "val_duration_mae_s": key[0], "val_speed_mae": key[1]}), flush=True)
                if best_key is None or key < best_key:
                    best_key, best = key, {"model": model, "scope": scope, "target": target, "candidate": candidate}
        winners[scope] = best
        metadata["selected_by_scope"][scope] = best["candidate"]
        joblib.dump(best, args.output_dir / f"{scope}.joblib")
    # Select deployable candidate strictly from validation; freeze before test.
    selected = min(winners, key=lambda scope: (metadata["selected_by_scope"][scope]["validation"]["duration_mae_seconds"], metadata["selected_by_scope"][scope]["validation"]["speed_mae_kmh"]))
    metadata["selected_scope"] = selected
    predictions = test[["source_row", "segment_id", "updated_at", "velocity", "length_m"]].copy()
    predictions["fixed_25_kmh"] = 25.0
    predictions["past_segment_hour_mean"] = baseline_test
    for scope, artifact in winners.items():
        values = speed_from_output(artifact["model"].predict(features(test, scope)), artifact["target"])
        metadata["test"][scope] = {"metrics": evaluate(test, values), "subgroups": subgroups(test, values, train)}
        predictions[scope] = values
        pd.DataFrame({"feature": FEATURE_SCOPES[scope], "gain": artifact["model"].booster_.feature_importance(importance_type="gain"), "splits": artifact["model"].feature_importances_}).sort_values("gain", ascending=False).to_csv(args.output_dir / f"{scope}_importance.csv", index=False)
    predictions.to_csv(args.output_dir / "test_predictions.csv", index=False)
    (args.output_dir / "benchmark.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2, default=int), encoding="utf-8")
    print(json.dumps({"selected_scope": selected, "test": {k: v["metrics"] for k, v in metadata["test"].items()}}, indent=2), flush=True)


if __name__ == "__main__":
    main()

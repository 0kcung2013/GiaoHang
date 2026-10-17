"""Diagnose frozen predictions and map speed bands; never train or install a model."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import confusion_matrix

from data import chronological_split, sha256
from features import features, speed_from_output
from metrics import evaluate


METHODS = ["fixed_25_kmh", "past_segment_hour_mean", "time_only", "road_time", "road_time_ids"]
BANDS = ["red_le_28", "orange_gt_28_le_34", "yellow_gt_34_le_40", "green_gt_40"]


def speed_bands(values):
    # Exactly the current UI's <=28, (28,34], (34,40], >40 boundaries.
    return np.searchsorted([28.0, 34.0, 40.0], np.asarray(values, float), side="left")


def diagnose(frame, predicted):
    predicted = np.asarray(predicted, float)
    actual = frame.velocity.to_numpy(float)
    result = evaluate(frame, predicted)
    observed, forecast = speed_bands(actual), speed_bands(predicted)
    counts = confusion_matrix(observed, forecast, labels=range(4))
    row_counts = counts.sum(axis=1)
    result.update({
        "observed_red_percent": float((observed == 0).mean() * 100),
        "predicted_red_percent": float((forecast == 0).mean() * 100),
        "exact_display_band_accuracy": float((observed == forecast).mean()),
        "display_band_macro_recall": float((np.diag(counts)[row_counts > 0] / row_counts[row_counts > 0]).mean()),
        "confusion_rows_observed_columns_predicted": counts.tolist(),
        "predicted_red_rows": int((forecast == 0).sum()),
        "false_red_rows": int(((forecast == 0) & (observed != 0)).sum()),
        "above_28_observed_rows": int((observed != 0).sum()),
        "above_28_observed_predicted_red_percent": float((forecast[observed != 0] == 0).mean() * 100) if (observed != 0).any() else None,
        "predicted_red_observed_above_28_percent": float((observed[forecast == 0] != 0).mean() * 100) if (forecast == 0).any() else None,
        "observed_speed_mean": float(actual.mean()),
        "predicted_speed_mean": float(predicted.mean()),
        "observed_speed_quantiles": {str(q): float(np.quantile(actual, q)) for q in [.1, .25, .5, .75, .9]},
        "predicted_speed_quantiles": {str(q): float(np.quantile(predicted, q)) for q in [.1, .25, .5, .75, .9]},
    })
    return result


def main():
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=root / "output/utraffic_speed/reassessment")
    args = parser.parse_args()
    labels_path = root / "output/utraffic_speed/audit/labels.pkl"
    predictions_path = root / "output/utraffic_speed/model/test_predictions.csv"
    artifact_path = root / "output/utraffic_speed/model/road_time.joblib"
    labels = pd.read_pickle(labels_path)
    splits, split_info = chronological_split(labels)
    train, test = splits["train"], splits["test"].sort_values("source_row").reset_index(drop=True)
    predictions = pd.read_csv(predictions_path).sort_values("source_row").reset_index(drop=True)
    if predictions.source_row.duplicated().any() or not np.array_equal(test.source_row, predictions.source_row):
        raise ValueError("Predictions are not the original chronological test rows")
    for field in ["segment_id", "velocity", "length_m"]:
        if not np.allclose(test[field], predictions[field], rtol=0, atol=1e-10):
            raise ValueError(f"Prediction label/road mismatch: {field}")
    if not test.updated_at.equals(pd.to_datetime(predictions.updated_at, utc=True, format="mixed")):
        raise ValueError("Prediction observation times differ from audited test")
    artifact = joblib.load(artifact_path)
    if artifact["scope"] != "road_time":
        raise ValueError("Unexpected selected model")
    recomputed = speed_from_output(artifact["model"].predict(features(test, artifact["scope"])), artifact["target"])
    maximum_error = float(np.max(np.abs(recomputed - predictions.road_time)))
    if maximum_error > 1e-8:
        raise ValueError(f"Frozen model does not reproduce saved test predictions: {maximum_error}")
    runtime_path = root / "output/utraffic_speed/runtime/model.json"
    app_path = root / "packages/giaohang_mobile/assets/ml/utraffic_model.json"
    runtime = json.loads(runtime_path.read_text(encoding="utf-8"))
    app = json.loads(app_path.read_text(encoding="utf-8"))
    inference_fields = ["version", "payload", "target", "feature_names", "minimum_speed_kmh", "maximum_speed_kmh"]
    if any(runtime[key] != app[key] for key in inference_fields):
        raise ValueError("Research inference contract differs from the app model")
    methods = {name: diagnose(test, predictions[name]) for name in METHODS}
    support = test.segment_id.map(train.groupby("segment_id").size()).fillna(0)
    groups = {
        "actual_1_to_2": test.velocity.between(1, 2),
        "actual_3_to_28": test.velocity.between(3, 28),
        "actual_above_28": test.velocity.gt(28),
        "actual_above_40": test.velocity.gt(40),
        "seen_in_train": support.gt(0),
        "unseen_in_train": support.eq(0),
        "one_to_three_train_observations": support.between(1, 3),
    }
    subgroup_results = {
        name: {method: diagnose(test.loc[mask], predictions.loc[mask, method]) for method in METHODS}
        for name, mask in groups.items() if mask.any()
    }
    hour_results = {
        str(int(hour)): diagnose(test.loc[indices], predictions.loc[indices, "road_time"])
        for hour, indices in test.groupby("hour_bin").groups.items()
    }
    split_distributions = {
        name: {"rows": len(frame), "red_percent": float(frame.velocity.le(28).mean() * 100),
               "low_1_2_percent": float(frame.velocity.between(1, 2).mean() * 100),
               "median_speed": float(frame.velocity.median())}
        for name, frame in splits.items()
    }
    # Macro/date errors expose domination by repeatedly observed roads or days.
    errors = pd.DataFrame({"segment_id": test.segment_id, "local_date": test.local_date})
    for method in METHODS:
        errors[method] = np.abs(predictions[method].to_numpy() - test.velocity.to_numpy())
    macro_errors = {method: {
        "equal_segment_speed_mae": float(errors.groupby("segment_id")[method].mean().mean()),
        "equal_date_speed_mae": float(errors.groupby("local_date")[method].mean().mean()),
    } for method in METHODS}
    uncertainty = json.loads((root / "output/utraffic_speed/model/uncertainty.json").read_text(encoding="utf-8"))
    protected = [artifact_path, predictions_path, runtime_path, app_path,
                 root / "supabase/functions/_shared/delivery_eta_model_data.mjs"]
    result = {
        "scope": "diagnostic reanalysis of an already inspected chronological test; no retraining or model selection",
        "label_unit": "km/h working assumption, not explicitly verified by publisher",
        "ground_truth_limit": "dataset observation labels only; no measured 2026 traffic or delivery ETA",
        "map_bands": BANDS, "split": split_info, "split_distributions": split_distributions,
        "recomputed_frozen_model_maximum_error": maximum_error,
        "app_export_inference_identical": True, "input_sha256": {str(p.relative_to(root)): sha256(p) for p in protected},
        "methods": methods, "subgroups": subgroup_results, "by_local_hour": hour_results,
        "macro_speed_errors": macro_errors, "existing_duration_uncertainty": uncertainty,
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "reassessment.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    pd.DataFrame(methods).T[["rows", "speed_mae_kmh", "speed_bias_kmh", "duration_mae_seconds",
                           "macro_segment_duration_mae_seconds", "predicted_red_percent",
                           "above_28_observed_predicted_red_percent", "exact_display_band_accuracy",
                           "display_band_macro_recall"]].to_csv(args.output_dir / "method_summary.csv")
    pd.DataFrame(methods["road_time"]["confusion_rows_observed_columns_predicted"], index=BANDS, columns=BANDS).to_csv(args.output_dir / "speed_band_confusion.csv")
    print(json.dumps({"output": str(args.output_dir), "prediction_maximum_error": maximum_error,
                      "methods": {name: {key: score[key] for key in ["speed_mae_kmh", "speed_bias_kmh", "predicted_red_percent", "above_28_observed_predicted_red_percent"]} for name, score in methods.items()},
                      "selected_model_groups": {name: {key: scores["road_time"][key] for key in ["rows", "speed_mae_kmh", "speed_bias_kmh", "duration_mae_seconds"]} for name, scores in subgroup_results.items()}}, indent=2))


if __name__ == "__main__":
    main()

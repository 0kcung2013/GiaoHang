"""Speed errors and d/v reference duration, never measured order-delivery ETA."""
import numpy as np
import pandas as pd


def evaluate(frame: pd.DataFrame, predicted) -> dict:
    actual = frame.velocity.to_numpy(float)
    predicted = np.asarray(predicted, dtype=float)
    if predicted.shape != actual.shape or not np.isfinite(predicted).all() or (predicted <= 0).any():
        raise ValueError("Invalid predicted speed")
    speed_error = predicted - actual
    positive = actual > 0
    result = {"rows": len(actual), "speed_mae_kmh": float(np.abs(speed_error).mean()),
              "speed_rmse_kmh": float(np.sqrt(np.square(speed_error).mean())),
              "speed_bias_kmh": float(speed_error.mean()), "duration_rows": int(positive.sum()),
              "zero_duration_excluded": int((~positive).sum())}
    if not positive.any():
        return result
    reference = frame.length_m.to_numpy(float)[positive] * 3.6 / actual[positive]
    error = frame.length_m.to_numpy(float)[positive] * 3.6 / predicted[positive] - reference
    normalized = 3600 / predicted[positive] - 3600 / actual[positive]
    result.update({"duration_mae_seconds": float(np.abs(error).mean()),
                   "duration_rmse_seconds": float(np.sqrt(np.square(error).mean())),
                   "duration_bias_seconds": float(error.mean()),
                   "duration_p90_abs_seconds": float(np.quantile(np.abs(error), .90)),
                   "duration_mae_seconds_per_km": float(np.abs(normalized).mean()),
                   "duration_reference_mean_seconds": float(reference.mean()),
                   "duration_wape": float(np.abs(error).sum() / reference.sum()),
                   "macro_segment_duration_mae_seconds": float(pd.Series(np.abs(error)).groupby(frame.segment_id.to_numpy()[positive]).mean().mean())})
    return result


def subgroups(frame, predicted, train) -> dict:
    support = frame.segment_id.map(train.groupby("segment_id").size()).fillna(0)
    masks = {"seen_segment": support.gt(0), "unseen_segment": support.eq(0),
             "sparse_train_segment_le_3": support.between(1, 3),
             "low_speed_1_2": frame.velocity.between(1, 2), "speed_ge_3": frame.velocity.ge(3),
             "zero_speed": frame.velocity.eq(0), "missing_speed_limit": frame.max_speed_missing.eq(1)}
    values = np.asarray(predicted)
    return {name: evaluate(frame.loc[mask], values[mask.to_numpy()]) for name, mask in masks.items() if mask.any()}


def hierarchical_baseline(train, other):
    # Only the training past; validation/test observations never update these means.
    groups = train.groupby(["segment_id", "hour_bin"]).velocity.agg(["mean", "size"])
    segment = train.groupby("segment_id").velocity.agg(["mean", "size"])
    hour = train.groupby("hour_bin").velocity.agg(["mean", "size"])
    result, levels = [], []
    for row in other.itertuples():
        value, level = float(train.velocity.mean()), "global"
        for key, table, minimum, label in ((row.hour_bin, hour, 30, "hour"), (row.segment_id, segment, 3, "segment"), ((row.segment_id, row.hour_bin), groups, 3, "segment_hour")):
            if key in table.index and table.loc[key, "size"] >= minimum:
                value, level = float(table.loc[key, "mean"]), label
        result.append(np.clip(value, 1, 90))
        levels.append(level)
    return np.asarray(result), pd.Series(levels).value_counts().to_dict()

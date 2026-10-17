"""Finite, numeric feature contract shared by Python / JS / Dart."""
import numpy as np
import pandas as pd

from data import ROAD_FEATURES

TIME_FEATURES = ["hour", "weekday", "weekend", "hour_sin", "hour_cos"]
FEATURE_SCOPES = {"time_only": TIME_FEATURES,
                  "road_time": TIME_FEATURES + ROAD_FEATURES,
                  "road_time_ids": TIME_FEATURES + ROAD_FEATURES + ["segment_code", "street_code"]}


def features(frame: pd.DataFrame, scope: str) -> pd.DataFrame:
    local = frame.local_time
    hour = local.dt.hour + local.dt.minute / 60.0
    values = {"hour": hour, "weekday": local.dt.weekday.astype(float),
              "weekend": local.dt.weekday.ge(5).astype(float),
              "hour_sin": np.sin(hour * 2 * np.pi / 24), "hour_cos": np.cos(hour * 2 * np.pi / 24)}
    for name in FEATURE_SCOPES[scope]:
        if name not in values:
            values[name] = frame[name].astype(float)
    result = pd.DataFrame(values, index=frame.index)[FEATURE_SCOPES[scope]]
    if not np.isfinite(result).all().all():
        raise ValueError("Non-finite feature input")
    return result


def speed_from_output(values, target: str):
    raw = np.asarray(values, dtype=float)
    if target == "log1p":
        raw = np.expm1(raw)
    return np.clip(raw, 1.0, 90.0)

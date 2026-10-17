"""Check leakage boundaries, oracle independence and the declared benchmark."""
import json
from pathlib import Path

import numpy as np
import pandas as pd

from features import FEATURE_NAMES, timed_features
from simulator import expected_seconds, simulate_seconds

DIRECTORY = Path(__file__).resolve().parents[2] / "output/eta_simulation"


def test_routes_and_origin_areas_are_disjoint():
    data = pd.read_csv(DIRECTORY / "simulated_trips.csv", usecols=["route_id", "origin_area", "split", "label_source"])
    assert len(data) == 115200
    assert data.route_id.nunique() == 2400
    assert data.label_source.eq("simulation").all()
    parts = {name: data[data.split.eq(name)] for name in ["train", "validation", "test"]}
    for first, second in [("train", "validation"), ("train", "test"), ("validation", "test")]:
        assert set(parts[first].route_id).isdisjoint(parts[second].route_id)
        assert set(parts[first].origin_area).isdisjoint(parts[second].origin_area)
    assert not set(FEATURE_NAMES).intersection({"route_id", "sample_id", "split", "origin_area", "simulated_travel_s", "expected_travel_s", "delay_s", "delay_ratio"})


def test_simulator_is_reproducible_and_separate_from_model():
    row = pd.read_csv(DIRECTORY / "simulated_trips.csv", nrows=1).iloc[0]
    features = {name: float(row[name]) for name in FEATURE_NAMES}
    assert simulate_seconds(features, np.random.default_rng(72)) == simulate_seconds(features, np.random.default_rng(72))
    at_peak = timed_features(features, "2026-10-07T18:00:00+07:00")
    at_off = timed_features(features, "2026-10-07T12:00:00+07:00")
    assert expected_seconds(at_peak) > expected_seconds(at_off)
    assert timed_features(features, "2026-10-07T11:00:00Z") == at_peak
    assert simulate_seconds(features, np.random.default_rng(73)) != simulate_seconds(features, np.random.default_rng(72))


def test_frozen_synthetic_benchmark_meets_predeclared_goals():
    benchmark = json.loads((DIRECTORY / "benchmark.json").read_text(encoding="utf-8"))
    external = json.loads((DIRECTORY / "osrm_benchmark.json").read_text(encoding="utf-8"))
    assert benchmark["is_synthetic"] is True
    assert all(benchmark["acceptance"].values())
    assert all(external["acceptance"].values())
    assert external["predictor_frozen_before_probe"] is True
    assert external["routes"] == 40 and external["cases"] == 160
    assert external["failures"] == []

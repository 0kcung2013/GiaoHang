"""Focused regression checks for leakage, dangerous matches and profile invariants."""
import json
import math
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from data import chronological_split
from features import features
from route_profile import RoadMatcher, build_profile
from runtime_model import SpeedModel

ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture(scope="module")
def artifacts():
    directory = ROOT / "output/utraffic_speed/runtime"
    model = SpeedModel(json.loads((directory / "model.json").read_text(encoding="utf-8")))
    matcher = RoadMatcher(json.loads((directory / "network.json").read_text(encoding="utf-8")))
    return model, matcher


def test_chronological_split_and_no_velocity_input():
    labels = pd.read_pickle(ROOT / "output/utraffic_speed/audit/labels.pkl")
    splits, _ = chronological_split(labels)
    assert splits["train"].updated_at.max() < splits["validation"].updated_at.min() < splits["test"].updated_at.min()
    sample = labels.head(100).copy()
    expected = features(sample, "road_time")
    sample["velocity"] = -999
    pd.testing.assert_frame_equal(features(sample, "road_time"), expected)


def test_all_low_velocity_and_zero_labels_preserved():
    audit = json.loads((ROOT / "output/utraffic_speed/audit/audit.json").read_text(encoding="utf-8"))
    assert audit["raw_rows"] == audit["kept_rows"] + sum(audit["excluded"].values())
    assert audit["positive_below_3"] == 23865
    assert audit["zero_velocity_rows"] == 446
    assert audit["excluded"]["conflicting_segment_time"] == 0


def tiny_matcher(parallel=False):
    fields = ["segment_id", "s_node_id", "e_node_id", "start_lat", "start_lng", "end_lat", "end_lng", "training_count"]
    roads = [[1, 10, 11, 10.78, 106.66, 10.78, 106.661, 4]]
    if parallel:
        roads.append([2, 20, 21, 10.78002, 106.66, 10.78002, 106.661, 3])
    return RoadMatcher({"fields": fields, "roads": roads, "bounds": {"min_lat": 10.7, "max_lat": 10.9, "min_lng": 106.6, "max_lng": 106.8},
                        "matching_policy": {"maximum_lateral_meters": 8, "maximum_heading_degrees": 20, "endpoint_slack_meters": 3, "ambiguity_margin_meters": 3, "probe_meters": 20}})


def test_reverse_direction_rejected():
    assert tiny_matcher().match([106.6604, 10.78], [106.6603, 10.78])[0] is None


def test_turn_and_off_road_rejected():
    matcher = tiny_matcher()
    assert matcher.match([106.6603, 10.78], [106.6603, 10.7801])[0] is None
    assert matcher.match([106.6603, 10.781], [106.6604, 10.781])[0] is None


def test_parallel_ambiguity_not_random_nearest():
    matcher = tiny_matcher(parallel=True)
    assert matcher.match([106.6603, 10.78001], [106.6604, 10.78001])[1] == "ambiguous_parallel_or_overlapping"
    road, method = matcher.match([106.6603, 10.78001], [106.6604, 10.78001], (10, 11))
    assert road["segment_id"] == 1 and method == "directed_nodes_and_geometry"


def test_node_ids_do_not_override_wrong_geometry():
    assert tiny_matcher().match([106.6603, 10.781], [106.6604, 10.781], (10, 11))[0] is None


def test_outside_scope_and_invalid_coordinates():
    matcher = tiny_matcher()
    assert matcher.match([106.6603, 11], [106.6604, 11])[1] == "outside_scope"
    assert matcher.match([float("nan"), 10.78], [106.6604, 10.78])[1] == "outside_scope"


@pytest.mark.parametrize("value", [None, 0, -1, math.nan, math.inf, 91])
def test_invalid_model_speed_falls_back(value):
    class InvalidModel:
        metadata = {"version": "invalid-test-model"}
        def speed_at(self, road, at):
            return value
    route = {"distance": 200, "geometry": {"coordinates": [[106.6602, 10.78], [106.6608, 10.78]]}}
    profile = build_profile(route, "2020-12-16T18:00:00+07:00", InvalidModel(), tiny_matcher())
    assert profile["travel_minutes"] == pytest.approx(.48)
    assert not profile["used_ai"]
    assert all(s["speed_kmh"] == 25 for s in profile["speed_profile"])


def test_partial_ai_does_not_discard_good_sections():
    class Constant:
        metadata = {"version": "test"}
        def speed_at(self, road, at):
            return 10
    route = {"distance": 1000, "geometry": {"coordinates": [[106.66, 10.78], [106.661, 10.78], [106.662, 10.78]]}}
    profile = build_profile(route, "2020-12-16T18:00:00+07:00", Constant(), tiny_matcher())
    assert profile["used_ai"] and not profile["all_sections_ai"]
    assert 0 < profile["ai_coverage_ratio"] < 1
    assert profile["travel_minutes"] > 1000 * .06 / 25
    assert profile["travel_minutes"] == pytest.approx(sum(s["travel_minutes"] for s in profile["speed_profile"]))


def test_real_profiles_cover_exact_osrm_distance_and_share_speeds(artifacts):
    model, matcher = artifacts
    fixtures = json.loads((ROOT / "output/utraffic_speed/runtime/route_parity.json").read_text(encoding="utf-8"))
    for case in fixtures:
        profile = build_profile(case["route"], case["at"], model, matcher)
        sections = profile["speed_profile"]
        assert sections[0]["start_meters"] == 0
        assert sections[-1]["end_meters"] == case["route"]["distance"]
        assert all(a["end_meters"] == b["start_meters"] for a, b in zip(sections, sections[1:]))
        assert all(0 < s["speed_kmh"] <= 90 for s in sections)
        reconstructed = sum((s["end_meters"] - s["start_meters"]) * .06 / s["speed_kmh"] for s in sections)
        assert reconstructed == pytest.approx(profile["travel_minutes"], abs=1e-8)


def test_timezone_identity_and_invalid_feature_guard(artifacts):
    model, _ = artifacts
    case = json.loads((ROOT / "output/utraffic_speed/runtime/parity.json").read_text(encoding="utf-8"))[0]
    assert model.features_at(case["road"], "2020-12-16T18:00:00+07:00") == model.features_at(case["road"], "2020-12-16T11:00:00Z")
    with pytest.raises(ValueError):
        model.predict([np.nan] * len(model.metadata["feature_names"]))



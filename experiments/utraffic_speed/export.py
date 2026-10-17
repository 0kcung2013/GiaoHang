"""Export research artifacts ONLY; applying these to app/Edge requires approval."""
import argparse
import base64
import json
import struct
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

from data import chronological_split
from features import FEATURE_SCOPES, features, speed_from_output

ROAD_FIELDS = ["segment_id", "s_node_id", "e_node_id", "start_lat", "start_lng", "end_lat", "end_lng", "length_m", "max_speed", "max_speed_missing", "level", "level_missing", "type_code", "bearing_sin", "bearing_cos", "segment_code", "street_code", "training_count"]
BOUNDS = {"min_lat": 10.740268807, "max_lat": 10.88658775, "min_lng": 106.58906115, "max_lng": 106.7949388485}
DRIVING_TYPES = {"motorway", "motorway_link", "trunk", "trunk_link", "primary", "primary_link", "secondary", "secondary_link", "tertiary", "tertiary_link", "residential", "service", "unclassified", "bridge"}


def flatten_tree(tree):
    """Keep the ETA1 numeric tree format independent of retired experiments."""
    nodes = []

    def visit(node):
        index = len(nodes)
        nodes.append(None)
        if "leaf_value" in node:
            nodes[index] = (-1, float(node["leaf_value"]), -1, -1, 1)
            return index
        left = visit(node["left_child"])
        right = visit(node["right_child"])
        nodes[index] = (int(node["split_feature"]), float(node["threshold"]),
                        left, right, 1 if bool(node.get("default_left", True)) else 0)
        return index

    visit(tree)
    return [node for node in nodes if node is not None]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=Path("output/utraffic_speed/runtime"))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    benchmark = json.loads((root / "output/utraffic_speed/model/benchmark.json").read_text(encoding="utf-8"))
    scope = benchmark["selected_scope"]
    artifact = joblib.load(root / f"output/utraffic_speed/model/{scope}.joblib")
    trees = artifact["model"].booster_.dump_model()["tree_info"]
    payload = bytearray(b"ETA1") + struct.pack("<H", len(trees))
    for tree in trees:
        if "==" in json.dumps(tree["tree_structure"]):
            raise ValueError("Runtime supports numeric trees only")
        nodes = flatten_tree(tree["tree_structure"])
        payload.extend(struct.pack("<H", len(nodes)))
        for node in nodes:
            payload.extend(struct.pack("<hdhhB", *node))
    model = {"version": benchmark["version"], "source": "UTraffic HCMC historical segment_status velocity", "dataset_version": 6,
             "is_synthetic": False, "is_realtime": False, "feature_names": FEATURE_SCOPES[scope], "scope": scope,
             "target": artifact["target"], "minimum_speed_kmh": 1, "maximum_speed_kmh": 90,
             "velocity_unit": "km/h", "velocity_unit_status": "working inference from free-flow max_velocity scale; publisher data card does not explicitly label unit",
             "bounds": BOUNDS, "payload": base64.b64encode(payload).decode(), "runtime_approved": False}
    labels = pd.read_pickle(root / "output/utraffic_speed/audit/labels.pkl")
    train = chronological_split(labels)[0]["train"]
    roads = pd.read_pickle(root / "output/utraffic_speed/audit/roads.pkl")
    roads["training_count"] = roads.segment_id.map(train.groupby("segment_id").size()).fillna(0).astype(int)
    supported = roads.valid_road & roads.street_type.isin(DRIVING_TYPES)
    for prefix in ("start", "end"):
        supported &= roads[prefix + "_lat"].between(BOUNDS["min_lat"], BOUNDS["max_lat"])
        supported &= roads[prefix + "_lng"].between(BOUNDS["min_lng"], BOUNDS["max_lng"])
    roads = roads.loc[supported].copy()
    network = {"fields": ROAD_FIELDS, "roads": roads[ROAD_FIELDS].to_numpy(float).tolist(),
               "matching_policy": {"maximum_lateral_meters": 8, "maximum_heading_degrees": 20, "endpoint_slack_meters": 3, "ambiguity_margin_meters": 3, "probe_meters": 20},
               "bounds": BOUNDS, "road_scope": "valid driving edges within the existing demo boundary; geometry matching is not map-matching ground truth"}
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "model.json").write_text(json.dumps(model, separators=(",", ":")), encoding="utf-8")
    (args.output_dir / "network.json").write_text(json.dumps(network, separators=(",", ":")), encoding="utf-8")
    sample = labels.groupby("hour_bin", group_keys=False).sample(frac=.03, random_state=42).sort_values("updated_at")
    matrix = features(sample, scope)
    predicted = speed_from_output(artifact["model"].predict(matrix), artifact["target"])
    fixtures = [{"at": row.updated_at.isoformat(), "road": {name: float(getattr(row, name)) for name in FEATURE_SCOPES[scope] if name not in ["hour", "weekday", "weekend", "hour_sin", "hour_cos"]}, "features": x.tolist(), "speed_kmh": float(speed)} for row, x, speed in zip(sample.itertuples(), matrix.to_numpy(), predicted)]
    # Explicit UTC+7 midnight / weekend boundary cases, independent of test labels.
    road = sample.iloc[0]
    boundary_times = ["2020-12-25T23:59:00+07:00", "2020-12-26T00:00:00+07:00", "2021-01-03T23:59:00+07:00", "2021-01-04T00:00:00+07:00"]
    boundary = pd.DataFrame([road] * len(boundary_times))
    boundary["local_time"] = pd.to_datetime(boundary_times, utc=True).tz_convert("Asia/Ho_Chi_Minh")
    x_boundary = features(boundary, scope)
    speeds = speed_from_output(artifact["model"].predict(x_boundary), artifact["target"])
    for at, values, speed in zip(boundary_times, x_boundary.to_numpy(), speeds):
        fixtures.append({"at": at, "road": fixtures[0]["road"], "features": values.tolist(), "speed_kmh": float(speed)})
    (args.output_dir / "parity.json").write_text(json.dumps(fixtures, separators=(",", ":")), encoding="utf-8")
    print(json.dumps({"trees": len(trees), "payload_bytes": len(payload), "roads": len(roads), "parity_cases": len(fixtures), "network_bytes": (args.output_dir / "network.json").stat().st_size, "runtime_approved": False}))


if __name__ == "__main__":
    main()

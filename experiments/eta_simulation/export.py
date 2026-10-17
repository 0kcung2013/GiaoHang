"""Export the fixed LightGBM winner for matching JS/Dart tree evaluation."""
import base64
import json
import struct
from pathlib import Path

import joblib

from features import BOUNDS, FEATURE_NAMES


def flatten(node, result):
    index = len(result)
    result.append(None)
    if "leaf_value" in node:
        result[index] = (-1, float(node["leaf_value"]), -1, -1, 0)
    else:
        left, right = flatten(node["left_child"], result), flatten(node["right_child"], result)
        if node["decision_type"] != "<=":
            raise ValueError("NON_NUMERIC_TREE_SPLIT")
        result[index] = (int(node["split_feature"]), float(node["threshold"]), left, right, int(node.get("default_left", True)))
    return index


def main():
    directory = Path(__file__).resolve().parents[2] / "output/eta_simulation"
    model = joblib.load(directory / "model.joblib")
    trees = model.booster_.dump_model()["tree_info"]
    payload = bytearray(b"ETA1") + struct.pack("<H", len(trees))
    for tree in trees:
        nodes = []
        flatten(tree["tree_structure"], nodes)
        payload += struct.pack("<H", len(nodes))
        for node in nodes:
            payload += struct.pack("<hdhhB", *node)
    metadata = {"version": "hcm_synthetic_route_eta_v1", "target": "route_delay_ratio",
                "feature_names": FEATURE_NAMES, "payload": base64.b64encode(payload).decode(), "trees": len(trees),
                "is_synthetic": True, "uses_realtime_traffic": False, "minimum_multiplier": .5, "maximum_multiplier": 5,
                "bounds": BOUNDS, "minimum_route_meters": 50, "maximum_route_meters": 25000,
                "dataset_label": "ETA mô phỏng TP.HCM", "dataset_scope": "LightGBM học thời gian chạy mô phỏng trên mạng đường Việt Nam"}
    (directory / "model.json").write_text(json.dumps(metadata, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(json.dumps({"trees": len(trees), "numeric_payload_bytes": len(payload), "json_bytes": (directory / "model.json").stat().st_size}))


if __name__ == "__main__":
    main()

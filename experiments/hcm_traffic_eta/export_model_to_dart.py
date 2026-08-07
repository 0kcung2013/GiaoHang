from __future__ import annotations

import argparse
import base64
import struct
from pathlib import Path
from typing import Any

import joblib


MODEL_VERSION = "hcm_utraffic_lgbm_v2_road_profile"
NODE_STRUCT = struct.Struct("<hdhhB")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export HCMC LightGBM to Dart.")
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args()


def flatten_tree(tree: dict[str, Any]) -> list[tuple[int, float, int, int, int]]:
    nodes: list[tuple[int, float, int, int, int] | None] = []

    def visit(node: dict[str, Any]) -> int:
        index = len(nodes)
        nodes.append(None)
        if "leaf_value" in node:
            nodes[index] = (-1, float(node["leaf_value"]), -1, -1, 1)
            return index
        left = visit(node["left_child"])
        right = visit(node["right_child"])
        nodes[index] = (
            int(node["split_feature"]),
            float(node["threshold"]),
            left,
            right,
            1 if bool(node.get("default_left", True)) else 0,
        )
        return index

    visit(tree)
    return [node for node in nodes if node is not None]


def encode_model(model_path: Path) -> tuple[str, int, int]:
    pipeline = joblib.load(model_path)
    booster = pipeline.named_steps["model"].booster_
    trees = [
        flatten_tree(item["tree_structure"])
        for item in booster.dump_model()["tree_info"]
    ]
    payload = bytearray(b"ETA1")
    payload.extend(struct.pack("<H", len(trees)))
    node_count = 0
    for tree in trees:
        payload.extend(struct.pack("<H", len(tree)))
        node_count += len(tree)
        for node in tree:
            payload.extend(NODE_STRUCT.pack(*node))
    return base64.b64encode(payload).decode("ascii"), len(trees), node_count


def dart_source(encoded: str, tree_count: int, node_count: int) -> str:
    chunks = [encoded[index : index + 160] for index in range(0, len(encoded), 160)]
    literals = "\n".join(f"  '{chunk}'" for chunk in chunks)
    return f"""// GENERATED FILE. Do not edit by hand.
// Source: UTraffic historical traffic flow in Ho Chi Minh City.
// Trees: {tree_count}; nodes: {node_count}.

const deliveryEtaAiModelVersion = '{MODEL_VERSION}';
const deliveryEtaAiModelPayload =
{literals};
"""


def main() -> None:
    args = parse_args()
    encoded, tree_count, node_count = encode_model(args.model)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        dart_source(encoded, tree_count, node_count), encoding="utf-8", newline="\n"
    )
    print(
        f"Exported {tree_count} trees / {node_count} nodes to {args.output} "
        f"({args.output.stat().st_size:,} bytes)."
    )


if __name__ == "__main__":
    main()

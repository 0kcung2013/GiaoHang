"""Evaluate frozen predictions within the exported road scope; no reselection."""
import json
from pathlib import Path

import pandas as pd

from data import chronological_split
from metrics import evaluate


def main():
    root = Path(__file__).resolve().parents[2]
    output = root / "output/utraffic_speed"
    network = json.loads((output / "runtime/network.json").read_text(encoding="utf-8"))
    id_index = network["fields"].index("segment_id")
    road_ids = {int(road[id_index]) for road in network["roads"]}
    labels = pd.read_pickle(output / "audit/labels.pkl")
    splits = chronological_split(labels)[0]
    predictions = pd.read_csv(output / "model/test_predictions.csv")
    test = splits["test"]
    # Frozen CSV is joined by original source row, never by a new model fit.
    predictions = predictions.set_index("source_row").loc[test.source_row]
    predictions.index = test.index
    scoped = test.segment_id.isin(road_ids)
    model_report = json.loads((output / "model/benchmark.json").read_text(encoding="utf-8"))
    result = {
        "scope": network["road_scope"],
        "selected_scope": model_report["selected_scope"],
        "selection_unchanged": True,
        "roads_exported": len(road_ids),
        "train_segments_with_labels": int(splits["train"].loc[splits["train"].segment_id.isin(road_ids), "segment_id"].nunique()),
        "all_splits_segments_with_labels": int(labels.loc[labels.segment_id.isin(road_ids), "segment_id"].nunique()),
        "test_rows": int(scoped.sum()),
        "test_segments": int(test.loc[scoped, "segment_id"].nunique()),
        "test": {},
    }
    for name in model_report["test"]:
        result["test"][name] = evaluate(test.loc[scoped], predictions.loc[scoped, name].to_numpy())
    (output / "model/runtime_scope_benchmark.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in result.items() if k != "test"}))
    for name, metrics in result["test"].items():
        print(json.dumps({"model": name, "speed_mae_kmh": metrics["speed_mae_kmh"],
                          "duration_mae_seconds": metrics["duration_mae_seconds"],
                          "macro_segment_duration_mae_seconds": metrics["macro_segment_duration_mae_seconds"]}))


if __name__ == "__main__":
    main()

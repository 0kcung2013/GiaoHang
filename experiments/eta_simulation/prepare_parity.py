"""Compact parity fixtures anchored to Python LightGBM, not JS/Dart outputs."""
import json
from pathlib import Path

import pandas as pd

from features import FEATURE_NAMES


def main():
    directory = Path(__file__).resolve().parents[2] / "output/eta_simulation"
    frame = pd.read_csv(directory / "test_predictions.csv").sample(n=1000, random_state=20261015)
    vectors = [{"features": [float(row[name]) for name in FEATURE_NAMES],
                "expected_ratio": float(row.predicted_travel_s / row.baseline_s - 1)}
               for _, row in frame.iterrows()]
    (directory / "parity_vectors.json").write_text(json.dumps(vectors, separators=(",", ":")), encoding="utf-8")
    routes = json.loads((directory / "parity_routes.json").read_text(encoding="utf-8"))
    for fixture in routes:
        route = fixture["route"]
        fixture["route"] = {"distance": route["distance"], "duration": route["duration"], "geometry": route["geometry"],
                            "legs": [{"annotation": {key: leg.get("annotation", {}).get(key, []) for key in ["nodes", "distance", "duration"]}}
                                     for leg in route.get("legs", [])]}
    (directory / "parity_routes.json").write_text(json.dumps(routes, separators=(",", ":")), encoding="utf-8")
    print(json.dumps({"vector_cases": len(vectors), "route_cases": len(routes),
                      "vectors_bytes": (directory / "parity_vectors.json").stat().st_size,
                      "route_bytes": (directory / "parity_routes.json").stat().st_size}))


if __name__ == "__main__":
    main()

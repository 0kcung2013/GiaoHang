"""Frozen external-route check, <=1 request/second; targets remain synthetic."""
from __future__ import annotations

import argparse
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

from features import FEATURE_NAMES, static_features, supports, timed_features
from simulator import expected_seconds
from train import metrics


def main():
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--routes", type=int, default=40)
    args = parser.parse_args()
    directory = root / "output/eta_simulation"
    context = json.loads((directory / "context.json").read_text(encoding="utf-8"))
    routes = json.loads((directory / "routes.json").read_text(encoding="utf-8"))
    data = pd.read_csv(directory / "test_predictions.csv")
    candidates = data.drop_duplicates("route_id").sample(frac=1, random_state=20261014).route_id.to_list()
    lookup = {record["route_id"]: record["route"] for record in routes}
    cache = directory / "osrm_routes"
    cache.mkdir(exist_ok=True)
    model = joblib.load(directory / "model.joblib")
    timings = ["2026-10-07T07:30:00+07:00", "2026-10-07T12:00:00+07:00",
               "2026-10-07T18:00:00+07:00", "2026-10-10T18:00:00+07:00"]
    records, fixtures, failures, accepted, last_request = [], [], [], 0, 0.0
    for route_id in candidates:
        if accepted >= args.routes:
            break
        path = cache / f"{route_id}.json"
        if path.exists():
            body = json.loads(path.read_text(encoding="utf-8"))
        elif args.fetch:
            points = lookup[route_id]["geometry"]["coordinates"]
            coords = ';'.join(','.join(str(v) for v in point) for point in [points[0], points[-1]])
            query = urllib.parse.urlencode({"overview": "full", "geometries": "geojson", "steps": "true", "annotations": "nodes,distance,duration"})
            url = f"https://router.project-osrm.org/route/v1/driving/{coords}?{query}"
            wait = 1.05 - (time.monotonic() - last_request)
            if wait > 0:
                time.sleep(wait)
            last_request = time.monotonic()
            try:
                request = urllib.request.Request(url, headers={"User-Agent": "GiaoHang-ETA-research/1.0"})
                with urllib.request.urlopen(request, timeout=15) as response:
                    body = json.load(response)
                path.write_text(json.dumps(body, separators=(",", ":")), encoding="utf-8")
            except Exception as error:
                failures.append({"route_id": route_id, "error": type(error).__name__})
                if len(failures) >= 6:
                    break
                continue
        else:
            continue
        route = body.get("routes", [None])[0]
        if body.get("code") != "Ok" or not route or not supports(route):
            failures.append({"route_id": route_id, "error": "routing_outside_demo_or_no_route"})
            continue
        static = static_features(route, context)
        for at in timings:
            features = timed_features(static, at)
            expected = expected_seconds(features)
            prediction = float(route["duration"] * np.clip(1 + model.predict(pd.DataFrame([features])[FEATURE_NAMES])[0], .5, 5))
            records.append({"route_id": route_id, "departure_at": at, **features,
                            "baseline_s": route["duration"], "simulated_travel_s": expected, "predicted_travel_s": prediction})
            fixtures.append({"name": f"{route_id}_{at}", "at": at, "route": route,
                             "features": [features[name] for name in FEATURE_NAMES],
                             "expected_model_seconds": prediction, "simulator_expected_seconds": expected})
        accepted += 1
        if accepted % 10 == 0:
            print(f"Verified {accepted}/{args.routes} unseen OSRM routes", flush=True)
    if not records:
        raise ValueError("NO_OSRM_PROBES_AVAILABLE")
    frame = pd.DataFrame(records)
    score = metrics(frame, frame.predicted_travel_s)
    baseline = metrics(frame, frame.baseline_s)
    report = {"routes": accepted, "cases": len(frame), "predictor_frozen_before_probe": True,
              "targets": "declared simulator expectation, not observed trip durations", "source": "OSRM public routing on held-out OD pairs",
              "model": score, "osrm_baseline": baseline, "failures": failures,
              "acceptance": {"p90_relative_error_at_most_15_percent": score["p90_absolute_percentage"] <= .15,
                             "beats_osrm_baseline_mae": score["mae_seconds"] < baseline["mae_seconds"]}}
    frame.to_csv(directory / "osrm_predictions.csv", index=False)
    (directory / "osrm_benchmark.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    (directory / "parity_routes.json").write_text(json.dumps(fixtures, separators=(",", ":")), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()

"""Offline candidate demonstration: OSRM road lengths + predicted speeds.

No production orders or backend are changed. All output is synthetic-model ETA.
"""
import argparse
import json
import unicodedata
import urllib.request
from datetime import timedelta
from pathlib import Path

import joblib
import pandas as pd

from model import features


def normalize(name):
    value = unicodedata.normalize("NFKD", name.lower().replace("đ", "d"))
    value = "".join(c for c in value if not unicodedata.combining(c))
    value = " ".join(value.split())
    return value.removeprefix("duong ")


def predict_route(route, artifact, accepted):
    accepted = accepted.to_pydatetime()
    lookup = {}
    for road in artifact["roads"]:
        lookup.setdefault(normalize(road.split("|", 1)[1]), []).append(road)
    elapsed = 5.  # Preparation, fixed at assignment.
    detail = []
    matched_distance = total_distance = 0.
    for leg_index, leg in enumerate(route["legs"]):
        leg_minutes = 0.
        for step in leg["steps"]:
            distance = float(step["distance"])
            if distance <= 0:
                continue
            candidates = lookup.get(normalize(step.get("name", "")), [])
            road = candidates[0] if len(candidates) == 1 else "__unknown__"
            when = accepted + timedelta(minutes=elapsed)
            frame = pd.DataFrame({"road": [road], "time": [when.replace(tzinfo=None)]})
            speed = float(artifact["model"].predict(features(frame, artifact["roads"], artifact["include_road"]))[0])
            if not 0 < speed <= 90:
                raise ValueError("Model speed outside valid interval")
            duration = distance / 1000 / speed * 60
            elapsed += duration
            leg_minutes += duration
            total_distance += distance
            if road != "__unknown__":
                matched_distance += distance
        detail.append({"leg": "driver_to_pickup" if leg_index == 0 else "pickup_to_delivery",
                       "distance_m": leg["distance"], "travel_minutes": leg_minutes})
        elapsed += 5.  # Pickup after first leg, handoff after second.
    if len(route["legs"]) != 2 or abs(total_distance-route["distance"]) > 5:
        raise ValueError("Expected two complete OSRM legs")
    return {"synthetic_demo": True, "accepted_at": accepted.isoformat(),
            "predicted_delivery_at": (accepted + timedelta(minutes=elapsed)).isoformat(),
            "total_minutes": elapsed, "service_minutes": 15,
            "fixed_25_total_minutes": route["distance"] / 1000 / 25 * 60 + 15,
            "name_matched_distance_fraction": matched_distance / total_distance if total_distance else 0,
            "road_match_note": "Name-only demo match, not validated segment identity; unknown roads use missing category",
            "legs": detail}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, default=Path("output/smarttraffic_eta/full_model/time_only_lightgbm.joblib"))
    parser.add_argument("--coordinates", default="106.665,10.775;106.675,10.780;106.690,10.790")
    parser.add_argument("--accepted-at", default="2026-10-12T08:00:00+07:00")
    parser.add_argument("--route-cache", type=Path, default=Path("output/smarttraffic_eta/demo_route.json"))
    parser.add_argument("--output", type=Path, default=Path("output/smarttraffic_eta/demo_eta.json"))
    args = parser.parse_args()
    if args.route_cache.exists():
        cached = json.loads(args.route_cache.read_text())
        if cached["coordinates"] != args.coordinates:
            raise ValueError("Use a different cache path for different coordinates")
        route = cached["route"]
    else:
        url = f"https://router.project-osrm.org/route/v1/driving/{args.coordinates}?overview=false&steps=true"
        with urllib.request.urlopen(url, timeout=60) as response:
            payload = json.load(response)
        if payload.get("code") != "Ok":
            raise ValueError("OSRM did not return a route")
        route = payload["routes"][0]
        args.route_cache.parent.mkdir(parents=True, exist_ok=True)
        args.route_cache.write_text(json.dumps({"coordinates": args.coordinates, "route": route}), encoding="utf-8")
    accepted = pd.Timestamp(args.accepted_at)
    if accepted.tzinfo is None:
        raise ValueError("Accepted timestamp must include timezone")
    accepted = accepted.tz_convert("Asia/Ho_Chi_Minh")
    artifact = joblib.load(args.model)  # Only load locally produced artifacts.
    result = predict_route(route, artifact, accepted)
    result["model_file"] = str(args.model)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()

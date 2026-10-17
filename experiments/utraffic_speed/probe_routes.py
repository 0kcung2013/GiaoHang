"""Public read-only OSRM probes; choose demo time from model outputs and support."""
import argparse
import json
import time
import urllib.request
from collections import Counter
from pathlib import Path

import numpy as np
import pandas as pd

from route_profile import RoadMatcher, build_profile
from runtime_model import SpeedModel

ROUTES = {
    "driver_to_pickup": [[106.6765, 10.7790], [106.668400, 10.784900]],
    "existing_demo": [[106.668400, 10.784900], [106.651842, 10.793838]],
    "cmt8_pham_van_dong": [[106.668400, 10.784900], [106.742100, 10.850500]],
    "inner_city": [[106.6765, 10.7790], [106.6850, 10.8030]],
    "pham_van_dong": [[106.6517, 10.817], [106.7550, 10.8310]],
}


def fetch_route(points):
    coordinates = ";".join(",".join(map(str, p)) for p in points)
    url = f"https://router.project-osrm.org/route/v1/driving/{coordinates}?overview=full&geometries=geojson&annotations=nodes,distance&steps=false"
    request = urllib.request.Request(url, headers={"User-Agent": "DATN-GiaoHang-UTraffic-Research/1.0"})
    with urllib.request.urlopen(request, timeout=20) as response:
        data = json.load(response)
    if data.get("code") != "Ok":
        raise ValueError(data.get("code"))
    return {"source_url": url, "endpoints": points, "route": data["routes"][0]}


def summary(profile):
    sections = profile["speed_profile"]
    speeds = [s["speed_kmh"] for s in sections if s["used_ai"]]
    bands = Counter("clear" if s["speed_kmh"] > 40 else "moderate" if s["speed_kmh"] > 34 else "heavy" if s["speed_kmh"] > 28 else "congested" for s in sections if s["used_ai"])
    distance_by_band = Counter()
    for s in sections:
        band = ("unavailable" if not s["used_ai"] else "clear" if s["speed_kmh"] > 40 else "moderate" if s["speed_kmh"] > 34 else "heavy" if s["speed_kmh"] > 28 else "congested")
        distance_by_band[band] += s["end_meters"] - s["start_meters"]
    return {"travel_minutes": profile["travel_minutes"], "ai_coverage_ratio": profile["ai_coverage_ratio"],
            "unique_matched_segments": len(set(s["segment_id"] for s in sections if s["used_ai"])),
            "speed_min_kmh": min(speeds) if speeds else None, "speed_max_kmh": max(speeds) if speeds else None,
            "bands": dict(bands), "distance_by_band_meters": dict(distance_by_band),
            "match_methods": dict(Counter(s["match_method"] for s in sections)),
            "ai_distance_with_training_labels": sum(s["end_meters"] - s["start_meters"] for s in sections if s["used_ai"] and s["training_count"] > 0)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fetch", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = root / "output/utraffic_speed/routes"
    output.mkdir(parents=True, exist_ok=True)
    if args.fetch:
        for name, endpoints in ROUTES.items():
            if (output / f"{name}.json").exists():
                continue
            value = fetch_route(endpoints)
            (output / f"{name}.json").write_text(json.dumps(value, separators=(",", ":")), encoding="utf-8")
            print(f"Fetched {name}: {value['route']['distance']} m", flush=True)
    metadata = json.loads((root / "output/utraffic_speed/runtime/model.json").read_text(encoding="utf-8"))
    model = SpeedModel(metadata)
    matcher = RoadMatcher(json.loads((root / "output/utraffic_speed/runtime/network.json").read_text(encoding="utf-8")))
    train = pd.read_pickle(root / "output/utraffic_speed/audit/labels.pkl")
    # Support uses training only; routes/hours are selected without test labels.
    train = train[train.local_date.lt("2020-12-18")]
    report = {"method": "same OSRM geometry at hourly inputs on Wednesday 2020-12-16; choose supported hours; no artificial speed/color assignment", "routes": {}}
    for name in ROUTES:
        route = json.loads((output / f"{name}.json").read_text(encoding="utf-8"))["route"]
        forecasts, profiles = {}, {}
        for hour in range(6, 20):
            at = f"2020-12-16T{hour:02}:00:00+07:00"
            started = time.perf_counter()
            profile = build_profile(route, at, model, matcher)
            forecast = summary(profile)
            forecast["python_seconds"] = time.perf_counter() - started
            segment_ids = set(s["segment_id"] for s in profile["speed_profile"] if s["used_ai"])
            support = train[train.segment_id.isin(segment_ids) & train.hour_bin.eq(hour)]
            forecast["training_rows_same_route_hour"] = len(support)
            forecast["training_segments_same_route_hour"] = support.segment_id.nunique()
            forecasts[str(hour)] = forecast
            profiles[hour] = profile
        supported = [h for h in range(6, 20) if forecasts[str(h)]["training_segments_same_route_hour"] >= 3]
        if len(supported) < 2:
            selected = None
        else:
            peak = max(supported, key=lambda h: forecasts[str(h)]["travel_minutes"])
            off = min(supported, key=lambda h: forecasts[str(h)]["travel_minutes"])
            selected = {"peak_hour": peak, "off_peak_hour": off,
                        "difference_minutes": forecasts[str(peak)]["travel_minutes"] - forecasts[str(off)]["travel_minutes"]}
            for label, hour in (("peak", peak), ("off_peak", off)):
                (output / f"{name}_{label}_profile.json").write_text(json.dumps(profiles[hour], separators=(",", ":")), encoding="utf-8")
        report["routes"][name] = {"distance_meters": route["distance"], "geometry_points": len(route["geometry"]["coordinates"]), "annotation_nodes": len(route["legs"][0].get("annotation", {}).get("nodes", [])), "forecasts": forecasts, "selected": selected}
        print(json.dumps({"route": name, "distance_meters": route["distance"], "coverage": forecasts["7"]["ai_coverage_ratio"], "selected": selected}, default=int), flush=True)
    (output / "benchmark.json").write_text(json.dumps(report, indent=2, default=int), encoding="utf-8")


if __name__ == "__main__":
    main()

"""Portable route features available before departure; no labels or route IDs."""
from __future__ import annotations

import math
from datetime import datetime, timedelta, timezone

CELL = .0025
BOUNDS = {"min_lat": 10.65, "max_lat": 10.95, "min_lng": 106.50, "max_lng": 106.90}
FEATURE_NAMES = ["distance_km", "baseline_minutes", "base_speed_kmh", "direct_km", "detour_ratio",
                 "minor_road_share", "junction_density", "signal_density", "turns_per_km",
                 "start_lat", "start_lng", "end_lat", "end_lng",
                 "hour", "hour_sin", "hour_cos", "weekday", "weekend"]


def distance(a, b):
    lat1, lat2 = math.radians(a[1]), math.radians(b[1])
    h = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(math.radians(b[0] - a[0]) / 2) ** 2
    return 6371008.8 * 2 * math.atan2(math.sqrt(h), math.sqrt(max(0, 1 - h)))


def cell_key(p):
    return f"{math.floor(p[0] / CELL)},{math.floor(p[1] / CELL)}"


def static_features(route, context):
    points = route["geometry"]["coordinates"]
    meters, seconds = float(route["distance"]), float(route["duration"])
    if not points or len(points) < 2 or not math.isfinite(meters) or not math.isfinite(seconds) or meters <= 0 or seconds <= 0:
        raise ValueError("INVALID_ETA_ROUTE")
    if any(len(p) != 2 or not all(math.isfinite(v) for v in p) or abs(p[0]) > 180 or abs(p[1]) > 90 for p in points):
        raise ValueError("INVALID_ETA_POINTS")
    lengths = [distance(a, b) for a, b in zip(points, points[1:])]
    total = sum(lengths)
    if total <= 0:
        raise ValueError("EMPTY_ETA_GEOMETRY")
    values, turns, previous = [0.0, 0.0, 0.0], 0, None
    cells = context["cells"]
    for a, b, length in zip(points, points[1:], lengths):
        if length <= .1:
            continue
        dx = (b[0] - a[0]) * math.cos(math.radians((a[1] + b[1]) / 2))
        dy = b[1] - a[1]
        bearing = math.atan2(dx, dy)
        if previous is not None and abs(math.atan2(math.sin(bearing - previous), math.cos(bearing - previous))) >= math.pi / 4:
            turns += 1
        previous = bearing
        probes = max(1, math.ceil(length / 100))
        for part in range(probes):
            p = [a[j] + (b[j] - a[j]) * (part + .5) / probes for j in range(2)]
            cell = cells.get(cell_key(p), context["default_cell"])
            for j in range(3):
                values[j] += cell[j] * length / probes / total
    direct = distance(points[0], points[-1]) / 1000
    return {"distance_km": meters / 1000, "baseline_minutes": seconds / 60,
            "base_speed_kmh": min(90, meters / seconds * 3.6), "direct_km": direct,
            "detour_ratio": min(10, meters / max(50, direct * 1000)),
            "minor_road_share": values[0], "junction_density": values[1], "signal_density": values[2],
            "turns_per_km": min(30, turns / max(.1, meters / 1000)),
            "start_lat": points[0][1], "start_lng": points[0][0], "end_lat": points[-1][1], "end_lng": points[-1][0]}


def timed_features(static, at):
    local = datetime.fromisoformat(at.replace("Z", "+00:00")).astimezone(timezone(timedelta(hours=7)))
    hour = local.hour + local.minute / 60
    values = dict(static, hour=hour, hour_sin=math.sin(hour * 2 * math.pi / 24),
                  hour_cos=math.cos(hour * 2 * math.pi / 24), weekday=local.weekday(), weekend=int(local.weekday() >= 5))
    return {name: math.floor(values[name] * 1e6 + .5) / 1e6 for name in FEATURE_NAMES}


def supports(route):
    return 50 <= route["distance"] <= 25000 and all(
        BOUNDS["min_lng"] <= p[0] <= BOUNDS["max_lng"] and BOUNDS["min_lat"] <= p[1] <= BOUNDS["max_lat"]
        for p in route["geometry"]["coordinates"])

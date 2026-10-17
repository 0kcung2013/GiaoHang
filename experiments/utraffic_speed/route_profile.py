"""Conservative directed geometry matches; exact OSRM total distance is preserved."""
import math
from collections import defaultdict
from datetime import datetime, timedelta

METERS_PER_DEGREE = 111195.0802335329
CELL = .001


def append_section(sections, section):
    keys = ("speed_kmh", "used_ai", "segment_id", "match_method", "training_count")
    if sections and all(sections[-1][key] == section[key] for key in keys):
        sections[-1]["end_meters"] = section["end_meters"]
        sections[-1]["travel_minutes"] += section["travel_minutes"]
    else:
        sections.append(section)


def distance(a, b):
    lat1, lat2 = math.radians(a[1]), math.radians(b[1])
    x = math.sin((lat2 - lat1) / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(math.radians(b[0] - a[0]) / 2) ** 2
    return 6371008.8 * 2 * math.atan2(math.sqrt(x), math.sqrt(max(0, 1 - x)))


class RoadMatcher:
    def __init__(self, network):
        self.policy = network["matching_policy"]
        self.bounds = network["bounds"]
        self.roads = [dict(zip(network["fields"], row)) for row in network["roads"]]
        self.grid, self.node_pairs = defaultdict(list), defaultdict(list)
        for index, road in enumerate(self.roads):
            road["midpoint_lat"] = (road["start_lat"] + road["end_lat"]) / 2
            road["midpoint_lng"] = (road["start_lng"] + road["end_lng"]) / 2
            for x in range(math.floor(min(road["start_lng"], road["end_lng"]) / CELL), math.floor(max(road["start_lng"], road["end_lng"]) / CELL) + 1):
                for y in range(math.floor(min(road["start_lat"], road["end_lat"]) / CELL), math.floor(max(road["start_lat"], road["end_lat"]) / CELL) + 1):
                    self.grid[x, y].append(index)
            self.node_pairs[int(road["s_node_id"]), int(road["e_node_id"])].append(index)

    def supports(self, point):
        return len(point) == 2 and all(math.isfinite(v) for v in point) and self.bounds["min_lng"] <= point[0] <= self.bounds["max_lng"] and self.bounds["min_lat"] <= point[1] <= self.bounds["max_lat"]

    def match(self, a, b, node_pair=None):
        if not self.supports(a) or not self.supports(b):
            return None, "outside_scope"
        midpoint = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]
        x, y = math.floor(midpoint[0] / CELL), math.floor(midpoint[1] / CELL)
        candidates = set(i for dx in (-1, 0, 1) for dy in (-1, 0, 1) for i in self.grid[x + dx, y + dy])
        exact = set(self.node_pairs.get(tuple(node_pair), [])) if node_pair else set()
        scored = []
        cosine = math.cos(math.radians(midpoint[1]))
        for i in candidates:
            road = self.roads[i]
            rx = (road["end_lng"] - road["start_lng"]) * cosine * METERS_PER_DEGREE
            ry = (road["end_lat"] - road["start_lat"]) * METERS_PER_DEGREE
            length = math.hypot(rx, ry)
            ex, ey = (b[0] - a[0]) * cosine * METERS_PER_DEGREE, (b[1] - a[1]) * METERS_PER_DEGREE
            edge_length = math.hypot(ex, ey)
            if length == 0 or edge_length == 0 or (rx * ex + ry * ey) / (length * edge_length) < math.cos(math.radians(self.policy["maximum_heading_degrees"])):
                continue
            lateral = 0
            accepted = True
            for p in (a, midpoint, b):
                px = (p[0] - road["start_lng"]) * cosine * METERS_PER_DEGREE
                py = (p[1] - road["start_lat"]) * METERS_PER_DEGREE
                projection = (px * rx + py * ry) / length
                lateral = max(lateral, abs(px * ry - py * rx) / length)
                if projection < -self.policy["endpoint_slack_meters"] or projection > length + self.policy["endpoint_slack_meters"]:
                    accepted = False
            if accepted and lateral <= self.policy["maximum_lateral_meters"]:
                scored.append((lateral, i))
        if not scored:
            return None, "no_directed_geometry_match"
        scored.sort()
        exact_scored = [pair for pair in scored if pair[1] in exact]
        if len(exact_scored) == 1:
            return self.roads[exact_scored[0][1]], "directed_nodes_and_geometry"
        if len(scored) > 1 and scored[1][0] - scored[0][0] < self.policy["ambiguity_margin_meters"]:
            return None, "ambiguous_parallel_or_overlapping"
        return self.roads[scored[0][1]], "directed_geometry"


def build_profile(route, at, model, matcher, fallback_speed=25):
    points = route["geometry"]["coordinates"]
    total = route["distance"]
    start = datetime.fromisoformat(at.replace("Z", "+00:00"))
    if not math.isfinite(total) or total <= 0 or len(points) < 2 or not 0 < fallback_speed <= 90:
        raise ValueError("Invalid route or fallback speed")
    lengths = [distance(a, b) for a, b in zip(points, points[1:])]
    geometry_length = sum(lengths)
    if geometry_length <= 0:
        raise ValueError("Empty geometry")
    annotation = route.get("legs", [{}])[0].get("annotation", {})
    nodes = annotation.get("nodes", [])
    aligned_nodes = len(nodes) == len(points)
    sections, along, minutes, ai_distance = [], 0, 0, 0
    for index, (a, b, length) in enumerate(zip(points, points[1:], lengths)):
        if length <= 0:
            continue
        count = max(1, math.ceil(length / matcher.policy["probe_meters"]))
        for part in range(count):
            first = [a[j] + (b[j] - a[j]) * part / count for j in (0, 1)]
            second = [a[j] + (b[j] - a[j]) * (part + 1) / count for j in (0, 1)]
            pair = (nodes[index], nodes[index + 1]) if aligned_nodes else None
            road, method = matcher.match(first, second, pair)
            forecast = (start + timedelta(minutes=minutes)).isoformat()
            predicted = None
            if road and total <= 25000 and model:
                try:
                    predicted = model.speed_at(road, forecast)
                except (ValueError, OverflowError, KeyError):
                    pass
            used_ai = predicted is not None and math.isfinite(predicted) and 0 < predicted <= 90
            if road and not used_ai:
                method = "distance_outside_scope" if total > 25000 else "model_unavailable_or_invalid"
            speed = predicted if used_ai else fallback_speed
            from_m = along
            along += length / count * total / geometry_length
            travel = (along - from_m) * .06 / speed
            append_section(sections, {"start_meters": from_m, "end_meters": along, "speed_kmh": speed, "used_ai": used_ai,
                             "forecast_at": forecast, "travel_minutes": travel, "segment_id": int(road["segment_id"]) if road else None,
                             "source": "utraffic_lightgbm" if used_ai else "fallback_25_kmh", "match_method": method,
                             "training_count": int(road["training_count"]) if road else 0})
            minutes += travel
            ai_distance += along - from_m if used_ai else 0
    # Correct floating-point accumulation only; no distance from historical segments.
    last = sections[-1]
    correction = total - last["end_meters"]
    minutes += correction * .06 / last["speed_kmh"]
    last["travel_minutes"] += correction * .06 / last["speed_kmh"]
    last["end_meters"] = total
    if last["used_ai"]:
        ai_distance += correction
    return {"distance_meters": total, "route_points": points, "forecast_at": start.isoformat(), "speed_profile": sections,
            "travel_minutes": minutes, "used_ai": ai_distance > 0, "all_sections_ai": all(s["used_ai"] for s in sections),
            "ai_distance_meters": ai_distance, "ai_coverage_ratio": ai_distance / total, "model_version": model.metadata["version"] if model else None}

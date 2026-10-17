"""Build offline sample routes and small spatial features from Vietnam OSM."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import pickle
from collections import defaultdict
from pathlib import Path

import numpy as np
import osmium
from scipy.sparse import csr_matrix
from scipy.sparse.csgraph import connected_components, dijkstra

from features import BOUNDS, CELL, cell_key, distance
from road_details import junction_details

SPEEDS = {"trunk": 55, "trunk_link": 35, "primary": 45, "primary_link": 30,
          "secondary": 40, "secondary_link": 30, "tertiary": 35, "tertiary_link": 25,
          "unclassified": 30, "residential": 25, "living_street": 15, "service": 18, "road": 25}
MINOR = {"unclassified", "residential", "living_street", "service", "road"}


class RoadExtract(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.coords, self.signals, self.edges = {}, set(), {}
        self.adjacent = defaultdict(set)
        self.cells = defaultdict(lambda: [0.0, 0.0, 0, 0])

    def node(self, n):
        if not n.location.valid():
            return
        lat, lng = n.location.lat, n.location.lon
        if BOUNDS["min_lat"] <= lat <= BOUNDS["max_lat"] and BOUNDS["min_lng"] <= lng <= BOUNDS["max_lng"]:
            self.coords[n.id] = (lng, lat)
            if n.tags.get("highway") == "traffic_signals":
                self.signals.add(n.id)

    def way(self, w):
        kind = w.tags.get("highway", "")
        if kind not in SPEEDS or w.tags.get("motorcycle") == "no" or w.tags.get("access") in {"no", "private"}:
            return
        speed = SPEEDS[kind]
        maximum = w.tags.get("maxspeed", "")
        try:
            limit = float(maximum)
            if 5 <= limit <= 90:
                speed = min(speed, limit)
        except ValueError:
            pass
        oneway = w.tags.get("oneway", "")
        forward = oneway != "-1"
        backward = oneway not in {"yes", "true", "1", "-1"} and w.tags.get("junction") != "roundabout"
        refs = [n.ref for n in w.nodes]
        for a, b in zip(refs, refs[1:]):
            if a not in self.coords or b not in self.coords:
                continue
            pa, pb = self.coords[a], self.coords[b]
            meters = distance(pa, pb)
            if meters < .1:
                continue
            seconds = meters / speed * 3.6
            for first, last in ([(a, b)] if forward else []) + ([(b, a)] if backward or oneway == "-1" else []):
                previous = self.edges.get((first, last))
                if previous is None or seconds < previous[0]:
                    self.edges[(first, last)] = (seconds, meters, kind)
            self.adjacent[a].add(b)
            self.adjacent[b].add(a)
            cell = self.cells[cell_key([(pa[j] + pb[j]) / 2 for j in range(2)])]
            cell[0] += meters
            if kind in MINOR:
                cell[1] += meters

    def finish(self):
        used = {n for edge in self.edges for n in edge}
        self.coords = {n: self.coords[n] for n in used}
        for node in used:
            cell = self.cells[cell_key(self.coords[node])]
            cell[2] += int(len(self.adjacent[node]) >= 3)
            cell[3] += int(node in self.signals)
        area = (CELL * 111.195) ** 2 * math.cos(math.radians(10.8))
        cells = {key: [round(v[1] / v[0], 5) if v[0] else .5,
                       round(min(100, v[2] / area), 5), round(min(20, v[3] / area), 5)]
                 for key, v in self.cells.items()}
        return {"version": "hcm_osm_context_v1", "source": "Geofabrik Vietnam OpenStreetMap",
                "license": "ODbL-1.0", "attribution": "OpenStreetMap contributors",
                "source_url": "https://download.geofabrik.de/asia/vietnam.html",
                "bounds": BOUNDS, "cell_degrees": CELL, "cell_fields": ["minor_road_share", "junction_density", "signal_density"],
                "default_cell": [.5, 15, 0], "cells": cells,
                **junction_details(self.coords, self.adjacent)}


def main():
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument("--pbf", type=Path, default=root / "data/vietnam_osm/vietnam-latest.osm.pbf")
    parser.add_argument("--output-dir", type=Path, default=root / "output/eta_simulation")
    parser.add_argument("--routes", type=int, default=2400)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    with args.pbf.open("rb") as handle:
        digest = hashlib.file_digest(handle, "sha256").hexdigest()
    cache = args.output_dir / "graph.pkl"
    if cache.exists():
        recorded = json.loads((args.output_dir / "provenance.json").read_text(encoding="utf-8"))
        if recorded["pbf_sha256"] != digest:
            raise ValueError("OSM source changed: use a new output directory instead of reusing this graph cache")
        graph = pickle.loads(cache.read_bytes())
        context = json.loads((args.output_dir / "context.json").read_text(encoding="utf-8"))
    else:
        print("Extracting the HCMC road graph from Vietnam OSM...", flush=True)
        handler = RoadExtract()
        handler.apply_file(str(args.pbf))
        context = handler.finish()
        graph = {"coords": handler.coords, "edges": handler.edges}
        cache.write_bytes(pickle.dumps(graph, protocol=5))
        (args.output_dir / "context.json").write_text(json.dumps(context, separators=(",", ":")), encoding="utf-8")
    node_ids = sorted(graph["coords"])
    indices = {node: i for i, node in enumerate(node_ids)}
    weights = csr_matrix(([value[0] for value in graph["edges"].values()],
                          ([indices[a] for a, _ in graph["edges"]], [indices[b] for _, b in graph["edges"]])),
                         shape=(len(node_ids), len(node_ids)))
    _, components = connected_components(weights, directed=True, connection="strong")
    component = int(np.bincount(components).argmax())
    eligible = np.flatnonzero(components == component)
    rng = np.random.default_rng(20261012)
    routes, seen = [], set()
    while len(routes) < args.routes:
        start = int(rng.choice(eligible))
        times, predecessors = dijkstra(weights, directed=True, indices=start, return_predecessors=True, limit=4000)
        candidates = []
        for lower, upper in [(12, 60), (60, 180), (180, 600), (600, 1200), (1200, 3000)]:
            group = eligible[np.isfinite(times[eligible]) & (times[eligible] >= lower) & (times[eligible] < upper)]
            rng.shuffle(group)
            candidates.extend(group[:3])
        for end in candidates:
            end = int(end)
            if (start, end) in seen:
                continue
            path_indices, current = [end], end
            while current != start:
                current = int(predecessors[current])
                if current < 0:
                    break
                path_indices.append(current)
            if current != start:
                continue
            ids = [node_ids[i] for i in reversed(path_indices)]
            parts = [graph["edges"][(a, b)] for a, b in zip(ids, ids[1:])]
            meters = sum(p[1] for p in parts)
            if not 100 <= meters <= 25000:
                continue
            seen.add((start, end))
            route = {"distance": meters, "duration": sum(p[0] for p in parts),
                     "geometry": {"coordinates": [list(graph["coords"][n]) for n in ids]},
                     "legs": [{"annotation": {"nodes": ids, "distance": [p[1] for p in parts], "duration": [p[0] for p in parts]}}]}
            routes.append({"route_id": f"HCM_{len(routes):05d}", "baseline_source": "offline OSM road-class profile; not a public OSRM response", "route": route})
            if len(routes) >= args.routes:
                break
        if len(routes) % 200 < 16:
            print(f"Generated {len(routes)}/{args.routes} distinct directed routes", flush=True)
    (args.output_dir / "routes.json").write_text(json.dumps(routes, separators=(",", ":")), encoding="utf-8")
    provenance = {"source": "https://download.geofabrik.de/asia/vietnam.html", "pbf_sha256": digest,
                  "bounds": BOUNDS, "nodes": len(node_ids), "directed_edges": len(graph["edges"]),
                  "context_cells": len(context["cells"]), "largest_strong_component_nodes": len(eligible), "routes": len(routes),
                  "seed": 20261012, "exclusions": "motorways, unsupported highway types, private/no-access and motorcycle=no",
                  "routing_limit": "offline synthetic-route graph does not model OSM turn restrictions; app continues to request OSRM routes"}
    (args.output_dir / "provenance.json").write_text(json.dumps(provenance, indent=2), encoding="utf-8")
    print(json.dumps(provenance, indent=2), flush=True)


if __name__ == "__main__":
    main()

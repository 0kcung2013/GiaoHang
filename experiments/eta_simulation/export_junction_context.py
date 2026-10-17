"""Enrich existing OSM context without changing any training feature or label."""
import json
import pickle
from collections import defaultdict
from pathlib import Path

from road_details import junction_details


def main():
    folder = Path(__file__).resolve().parents[2] / "output/eta_simulation"
    graph = pickle.loads((folder / "graph.pkl").read_bytes())
    context_file = folder / "context.json"
    context = json.loads(context_file.read_text(encoding="utf-8"))
    backup = folder / "context_before_junctions.json"
    if not backup.exists():
        backup.write_bytes(context_file.read_bytes())
    neighbors = defaultdict(set)
    for a, b in graph["edges"]:
        neighbors[a].add(b)
        neighbors[b].add(a)
    context.update(junction_details(graph["coords"], neighbors))
    context_file.write_text(json.dumps(context, separators=(",", ":")), encoding="utf-8")
    print(json.dumps({"junction_points": context["junction_point_count"], "context_bytes": context_file.stat().st_size}))


if __name__ == "__main__":
    main()

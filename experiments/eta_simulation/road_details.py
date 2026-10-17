"""Compact public OSM junction positions for localizing simulated waiting."""
import base64
import math
from collections import defaultdict

CELL_TICKS = 250
COORDINATE_SCALE = 100000


def junction_details(coords, neighbors):
    cells = defaultdict(set)
    for node, adjacent in neighbors.items():
        if len(adjacent) < 3 or node not in coords:
            continue
        lng, lat = coords[node]
        x = math.floor(lng * COORDINATE_SCALE + .5)
        y = math.floor(lat * COORDINATE_SCALE + .5)
        cx, cy = x // CELL_TICKS, y // CELL_TICKS
        cells[f"{cx},{cy}"].add((x % CELL_TICKS, y % CELL_TICKS))
    encoded = {key: base64.b64encode(bytes(v for point in sorted(points) for v in point)).decode("ascii")
               for key, points in sorted(cells.items())}
    return {"junction_detail_version": "osm_junction_points_v1",
            "junction_coordinate_scale": COORDINATE_SCALE,
            "junction_cell_ticks": CELL_TICKS,
            "junction_point_count": sum(len(points) for points in cells.values()),
            "junction_cells": encoded}

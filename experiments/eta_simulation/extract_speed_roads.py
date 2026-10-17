"""Public OSM node attributes for stable road-class predictions, no driver GPS."""
import base64
import json
import math
from collections import defaultdict
from pathlib import Path

import osmium

ROOT = Path(__file__).resolve().parents[2]
BOUNDS = {"min_lat": 10.3, "max_lat": 11.65, "min_lng": 106.2, "max_lng": 107.65}
KINDS = {"trunk": 2, "trunk_link": 1, "primary": 2, "primary_link": 1,
         "secondary": 2, "secondary_link": 1, "tertiary": 2, "tertiary_link": 1,
         "unclassified": 1, "residential": 1, "living_street": 0, "service": 0, "road": 1}


class Roads(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.coords, self.kind, self.bend, self.degree = {}, {}, {}, defaultdict(int)
        self.signals = set()

    def node(self, node):
        if not node.location.valid():
            return
        p = (node.location.lon, node.location.lat)
        if BOUNDS['min_lng'] <= p[0] <= BOUNDS['max_lng'] and BOUNDS['min_lat'] <= p[1] <= BOUNDS['max_lat']:
            self.coords[node.id] = p
            if node.tags.get('highway') == 'traffic_signals':
                self.signals.add(node.id)

    def way(self, way):
        kind = way.tags.get('highway')
        if kind not in KINDS or way.tags.get('motorcycle') == 'no' or way.tags.get('access') in {'no', 'private'}:
            return
        cls = KINDS[kind]
        width = way.tags.get('width', '')
        try:
            if float(width) <= 3.5:
                cls = 0
        except ValueError:
            pass
        refs = [n.ref for n in way.nodes]
        for a, b in zip(refs, refs[1:]):
            if a not in self.coords or b not in self.coords:
                continue
            for n in (a, b):
                self.kind[n] = max(cls, self.kind.get(n, 0))
                self.degree[n] += 1
        for a, b, c in zip(refs, refs[1:], refs[2:]):
            if any(n not in self.coords for n in (a, b, c)):
                continue
            pa, pb, pc = (self.coords[n] for n in (a, b, c))
            cos = math.cos(math.radians(pb[1]))
            first = math.atan2((pb[0]-pa[0])*cos, pb[1]-pa[1])
            second = math.atan2((pc[0]-pb[0])*cos, pc[1]-pb[1])
            angle = abs(math.atan2(math.sin(second-first), math.cos(second-first)))
            bucket = min(3, int(angle / (math.pi / 6)))
            self.bend[b] = max(bucket, self.bend.get(b, 0))


def main():
    output = ROOT / 'output/eta_simulation/speed_road_nodes.json'
    if output.exists():
        print('Reusing public OSM road-node cache', flush=True)
        return
    handler = Roads()
    print('Extracting HCMC road classes and bends from existing Vietnam PBF...', flush=True)
    handler.apply_file(str(ROOT / 'data/vietnam_osm/vietnam-latest.osm.pbf'))
    payload, previous = bytearray(), 0
    for node in sorted(handler.kind):
        delta = node - previous
        while delta >= 128:
            payload.append((delta & 127) | 128)
            delta >>= 7
        payload.append(delta)
        payload.append(handler.kind[node] | (handler.bend.get(node, 0) << 2)
                       | (int(handler.degree[node] >= 3) << 4) | (int(node in handler.signals) << 5))
        previous = node
    detail = {'version': 'hcm_osm_road_nodes_v1', 'bounds': BOUNDS,
              'source': 'Geofabrik Vietnam OpenStreetMap', 'license': 'ODbL-1.0',
              'attribution': 'OpenStreetMap contributors', 'node_count': len(handler.kind),
              'encoding': 'delta unsigned varint node ID then attribute byte: class(2),bend(2),junction(1),signal(1)',
              'payload': base64.b64encode(payload).decode('ascii')}
    output.write_text(json.dumps(detail, separators=(',', ':')), encoding='utf-8')
    print(json.dumps({'nodes': len(handler.kind), 'bytes': output.stat().st_size}), flush=True)


if __name__ == '__main__':
    main()

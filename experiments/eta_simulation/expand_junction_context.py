"""Expand static junction coverage, preserving every existing model feature."""
import json
from collections import defaultdict
from pathlib import Path
import osmium
from road_details import junction_details

ROOT = Path(__file__).resolve().parents[2]
BOUNDS = {"min_lat": 10.3, "max_lat": 11.65, "min_lng": 106.2, "max_lng": 107.65}
ROADS = {"trunk", "trunk_link", "primary", "primary_link", "secondary", "secondary_link",
         "tertiary", "tertiary_link", "unclassified", "residential", "living_street", "service", "road"}

class JunctionExtract(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.coords = {}
        self.neighbors = defaultdict(set)

    def node(self, node):
        if node.location.valid():
            lng, lat = node.location.lon, node.location.lat
            if BOUNDS['min_lng'] <= lng <= BOUNDS['max_lng'] and BOUNDS['min_lat'] <= lat <= BOUNDS['max_lat']:
                self.coords[node.id] = (lng, lat)

    def way(self, way):
        if way.tags.get('highway') not in ROADS or way.tags.get('motorcycle') == 'no' or way.tags.get('access') in {'no', 'private'}:
            return
        previous = None
        for node in way.nodes:
            if previous in self.coords and node.ref in self.coords:
                self.neighbors[previous].add(node.ref)
                self.neighbors[node.ref].add(previous)
            previous = node.ref

def main():
    output = ROOT / 'output/eta_simulation/hcm_expanded_junctions.json'
    if output.exists():
        detail = json.loads(output.read_text(encoding='utf-8'))
    else:
        print('Extracting static HCMC junctions from the existing public OSM PBF...', flush=True)
        handler = JunctionExtract()
        handler.apply_file(str(ROOT / 'data/vietnam_osm/vietnam-latest.osm.pbf'))
        detail = junction_details(handler.coords, handler.neighbors)
        detail.update(junction_bounds=BOUNDS, junction_detail_version='hcm_expanded_osm_junctions_v2')
        output.write_text(json.dumps(detail, separators=(',', ':')), encoding='utf-8')
    for name in ['output/eta_simulation/context.json', 'packages/giaohang_mobile/assets/ml/eta_simulation_context.json']:
        path = ROOT / name
        context = json.loads(path.read_text(encoding='utf-8'))
        original_cells = context['cells']
        context.update(detail)
        assert context['cells'] == original_cells
        path.write_text(json.dumps(context, separators=(',', ':')), encoding='utf-8')
    shared = ROOT / 'supabase/functions/_shared/delivery_eta_sim_data.mjs'
    source = shared.read_text(encoding='utf-8')
    prefix, _ = source.split('export const roadContext=', 1)
    context = json.loads((ROOT / 'packages/giaohang_mobile/assets/ml/eta_simulation_context.json').read_text(encoding='utf-8'))
    shared.write_text(prefix + 'export const roadContext=' + json.dumps(context, separators=(',', ':')) + ';\n', encoding='utf-8')
    print(json.dumps({'junction_points': detail['junction_point_count'], 'junction_cells': len(detail['junction_cells']),
                      'context_bytes': (ROOT / 'packages/giaohang_mobile/assets/ml/eta_simulation_context.json').stat().st_size}), flush=True)

if __name__ == '__main__':
    main()

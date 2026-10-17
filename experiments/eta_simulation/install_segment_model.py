"""Install the verified segment winner without replacing historical benchmarks."""
import json
import base64
import shutil
import gzip
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'output/eta_simulation/segment_ai'


def compact_runs(detail):
    raw = base64.b64decode(detail['payload'])
    output, previous, run_start, run_value, run_count, last, offset = bytearray(), 0, 0, 0, 0, 0, 0

    def put(value):
        while value >= 128:
            output.append((value & 127) | 128)
            value >>= 7
        output.append(value)

    def flush():
        nonlocal previous
        delta = run_start-previous
        output.append(run_value | (64 if delta != 1 else 0) | (128 if run_count > 1 else 0))
        if delta != 1:
            put(delta)
        if run_count > 1:
            put(run_count)
        previous = run_start+run_count-1

    while offset < len(raw):
        delta, factor = 0, 1
        while True:
            byte = raw[offset]
            offset += 1
            delta += (byte & 127)*factor
            factor *= 128
            if byte < 128:
                break
        node, value = last+delta, raw[offset]
        offset += 1
        if run_count and node == last+1 and value == run_value:
            run_count += 1
        else:
            if run_count:
                flush()
            run_start, run_value, run_count = node, value, 1
        last = node
    if run_count:
        flush()
    return {**detail, 'encoding': 'attribute_optional_delta_run_v4',
            'payload': base64.b64encode(output).decode('ascii')}


def main():
    report = json.loads((OUT/'benchmark.json').read_text())
    if report['accepted'] is not True:
        raise ValueError('UNVERIFIED_SEGMENT_MODEL')
    old = json.loads((OUT.parent/'context.json').read_text())
    context = {k: v for k, v in old.items() if not k.startswith('junction_')}
    context['speed_roads'] = compact_runs(json.loads((OUT.parent/'speed_road_nodes.json').read_text()))
    context['version'] = 'hcm_segment_ai_context_v1'
    (OUT/'context.json').write_text(json.dumps(context, separators=(',', ':')), encoding='utf-8')
    assets = ROOT/'packages/giaohang_mobile/assets/ml'
    shutil.copyfile(OUT/'model.json', assets/'eta_simulation_model.json')
    shutil.copyfile(OUT/'context.json', assets/'eta_simulation_context.json')
    shutil.copyfile(OUT/'parity_vectors.json', ROOT/'packages/giaohang_mobile/test/fixtures/eta_simulation_vectors.json')
    names = {'features.mjs': 'delivery_eta_sim_features.mjs', 'model.mjs': 'delivery_eta_sim_model.mjs',
             'profile.mjs': 'delivery_eta_sim_profile.mjs', 'segment_speeds.mjs': 'delivery_eta_sim_segment_speeds.mjs',
             'speed_features.mjs': 'delivery_eta_sim_speed_features.mjs', 'junction_speeds.mjs': 'delivery_eta_sim_junction_speeds.mjs',
             'turn_features.mjs': 'delivery_eta_sim_turn_features.mjs'}
    shared = ROOT/'supabase/functions/_shared'
    for original, target in names.items():
        source = (Path(__file__).parent/'runtime'/original).read_text(encoding='utf-8')
        for before, after in names.items():
            source = source.replace(f"'./{before}'", f"'./{after}'")
        (shared/target).write_text(source, encoding='utf-8')
    metadata = json.loads((OUT/'model.json').read_text(encoding='utf-8'))
    # Only the Edge bundle needs gzip. Flutter keeps its pure-Dart v4 decoder.
    roads = context['speed_roads']
    edge_context = {**context, 'speed_roads': {**roads, 'compression': 'gzip',
        'payload': base64.b64encode(gzip.compress(base64.b64decode(roads['payload']), mtime=0)).decode('ascii')}}
    (shared/'delivery_eta_sim_data.mjs').write_text(
        '// LightGBM trained on synthetic segment speeds and public OSM roads.\n'
        + 'export const modelMetadata=' + json.dumps(metadata, ensure_ascii=False, separators=(',', ':')) + ';\n'
        + 'export const roadContext=' + json.dumps(edge_context, separators=(',', ':')) + ';\n', encoding='utf-8')
    print(json.dumps({'model_bytes': (OUT/'model.json').stat().st_size,
          'context_bytes': (OUT/'context.json').stat().st_size, 'road_nodes': context['speed_roads']['node_count']}))


if __name__ == '__main__':
    main()

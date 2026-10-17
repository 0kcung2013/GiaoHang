"""Train speeds from synthetic labels on public OSM roads; hold out road IDs."""
import base64
import json
import math
import pickle
import struct
import subprocess
from pathlib import Path

import joblib
import lightgbm as lgb
import numpy as np
import pandas as pd

from export import flatten

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'output/eta_simulation/segment_ai'
NAMES = ['road_class', 'bend', 'junction', 'signal', 'peak', 'weekend', 'road_variation', 'turn_intensity']
VERSION = 'hcm_synthetic_segment_speed_v2'


def decode(detail):
    raw = base64.b64decode(detail['payload'])
    values, i, previous = {}, 0, 0
    while i < len(raw):
        delta, shift = 0, 0
        while True:
            byte = raw[i]
            i += 1
            delta |= (byte & 127) << shift
            shift += 7
            if byte < 128:
                break
        previous += delta
        values[previous] = raw[i]
        i += 1
    assert len(values) == detail['node_count']
    return values


def clock(hour, weekend):
    return round(max(math.exp(-.5*((hour-7.8)/1.05)**2), math.exp(-.5*((hour-17.5)/1.25)**2)) * (.65 if weekend else 1), 6)


def features(a, b, kind, nodes, peak, weekend):
    found = [nodes[n] for n in (a, b) if n in nodes]
    return [min(v & 3 for v in found) if found else kind,
            round(max((v >> 2) & 3 for v in found)/3, 6) if found else 0,
            sum((v >> 4) & 1 for v in found)/len(found) if found else 0,
            max((v >> 5) & 1 for v in found) if found else 0, peak, weekend]


def expected(x):
    kind, bend, junction, signal, peak, weekend, variation, turn = np.asarray(x).T
    base = np.select([kind == 0, kind == 1], [23., 37.5], default=48.)
    spread = np.select([kind == 0, kind == 1], [4., 5.], default=4.)
    reduction = np.select([kind == 0, kind == 1], [6., 9.], default=13.)
    cruise = np.clip(base + (variation-.5)*spread - peak*reduction - 6*bend - 1.2*junction - 2.5*signal, 15, 50)
    corner = np.select([kind == 0, kind == 1], [16.5, 18.5], default=20.5) + (variation-.5)*2 - 1.5*peak
    return np.clip(cruise - turn*(cruise-np.minimum(cruise, corner)), 15, 50)


def road_variation(a, b):
    x, y = (np.asarray(a)+np.asarray(b))/2
    return (math.floor(x/.002)*73856093+math.floor(y/.002)*19349663)%1009/1008


def metrics(actual, predicted):
    error = np.abs(actual - predicted)
    return {'mae_kmh': float(error.mean()), 'p90_error_kmh': float(np.quantile(error, .9)),
            'max_error_kmh': float(error.max())}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    nodes = decode(json.loads((OUT.parent/'speed_road_nodes.json').read_text()))
    graph = pickle.loads((OUT.parent/'graph.pkl').read_bytes())
    routes = json.loads((OUT.parent/'routes.json').read_text())
    rng = np.random.default_rng(20261013)
    # Reserve complete routes first. None of their undirected edges enter training.
    reserved = [routes[i] for i in rng.choice(len(routes), 80, replace=False)]
    (OUT/'reserved_routes.json').write_text(json.dumps(reserved), encoding='utf-8')
    subprocess.run(['node', str(Path(__file__).with_name('export_speed_route_features.mjs'))], cwd=ROOT, check=True)
    held_edges = set()
    for record in reserved:
        ids = record['route']['legs'][0]['annotation']['nodes']
        held_edges.update(tuple(sorted((a, b))) for a, b in zip(ids, ids[1:]))
    from extract_speed_roads import KINDS
    groups = {i: [] for i in range(3)}
    for (a, b), (_, meters, kind) in graph['edges'].items():
        if a >= b or tuple(sorted((a, b))) in held_edges or meters < 1:
            continue
        vector = features(a, b, KINDS[kind], nodes, 0, 0)
        groups[int(vector[0])].append((a, b, meters, vector[:4]))
    selected = []
    for kind, edges in groups.items():
        rng.shuffle(edges)
        selected.extend(edges[:6000])
    rng.shuffle(selected)
    split_end = [int(len(selected)*.7), int(len(selected)*.85)]
    rows = []
    for i, (a, b, meters, static) in enumerate(selected):
        split = 'train' if i < split_end[0] else 'validation' if i < split_end[1] else 'test'
        for sample in range(12):
            hour = float(rng.integers(0, 96))/4
            weekend = int(rng.random() < 2/7)
            turn = [0, 0, 0, 0, 0, 0, .15, .35, .55, .75, .9, 1][sample]
            variation = road_variation(graph['coords'][a], graph['coords'][b])
            vector = [*static, clock(hour, weekend), weekend, variation, turn]
            label = float(np.clip(expected([vector])[0] + rng.normal(0, .35), 15, 50))
            rows.append({'road_id': f'{a}:{b}', 'split': split, 'meters': meters,
                         **dict(zip(NAMES, vector)), 'speed_kmh': label, 'label_source': 'synthetic'})
    frame = pd.DataFrame(rows)
    frame.to_csv(OUT/'training_speeds.csv', index=False)
    train, val, test = [frame[frame.split.eq(name)] for name in ['train', 'validation', 'test']]
    assert set(train.road_id).isdisjoint(val.road_id) and set(train.road_id).isdisjoint(test.road_id)
    candidates, winner, best = [], None, math.inf
    for leaves, depth in [(15, 5), (31, 6)]:
        model = lgb.LGBMRegressor(n_estimators=360, learning_rate=.06, num_leaves=leaves,
              max_depth=depth, min_child_samples=40, reg_lambda=1, random_state=20261013,
              n_jobs=4, deterministic=True, force_col_wise=True, verbosity=-1)
        model.fit(train[NAMES], train.speed_kmh, eval_X=val[NAMES], eval_y=val.speed_kmh,
                  eval_metric='l1', callbacks=[lgb.early_stopping(35, verbose=False)])
        score = metrics(val.speed_kmh.to_numpy(), np.clip(model.predict(val[NAMES]), 15, 50))
        candidates.append({'leaves': leaves, 'trees': model.best_iteration_, 'validation': score})
        if score['mae_kmh'] < best:
            winner, best = model, score['mae_kmh']
        print(json.dumps(candidates[-1]), flush=True)
    joblib.dump(winner, OUT/'model.joblib')
    trees = winner.booster_.dump_model()['tree_info']
    payload = bytearray(b'ETA1') + struct.pack('<H', len(trees))
    for tree in trees:
        flat = []
        flatten(tree['tree_structure'], flat)
        payload += struct.pack('<H', len(flat))
        for node in flat:
            payload += struct.pack('<hdhhB', *node)
    metadata = {'version': VERSION, 'target': 'segment_speed_kmh', 'feature_names': NAMES,
                'payload': base64.b64encode(payload).decode(), 'trees': len(trees),
                'minimum_speed_kmh': 15, 'maximum_speed_kmh': 50,
                'is_synthetic': True, 'uses_realtime_traffic': False,
                'dataset_label': 'AI · ETA mô phỏng TP.HCM',
                'dataset_scope': 'LightGBM dự đoán tốc độ từng đoạn từ dữ liệu giao thông mô phỏng'}
    (OUT/'model.json').write_text(json.dumps(metadata, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    test_prediction = np.clip(winner.predict(test[NAMES]), 15, 50)
    test.assign(predicted_speed_kmh=test_prediction).to_csv(OUT/'test_predictions.csv', index=False)
    # Independent route-time benchmark, with all traversed edges held out above.
    route_rows, trace = [], []
    for record in json.loads((OUT/'held_out_route_features.json').read_text()):
        hour = record['hour']
        distances = [s['meters'] for s in record['sections']]
        vectors = [s['features'] for s in record['sections']]
        predicted = np.round(np.clip(winner.predict(pd.DataFrame(vectors, columns=NAMES)), 15, 50), 1)
        actual = expected(vectors)
        actual_seconds = float(np.sum(np.asarray(distances)*3.6/actual))
        predicted_seconds = float(np.sum(np.asarray(distances)*3.6/predicted))
        baseline_seconds = float(np.sum(distances)*3.6/25)
        meters = float(np.sum(distances))
        route_rows.append({'route_id': record['route_id'], 'hour': hour, 'distance_meters': meters,
              'simulated_route_avg_speed_kmh': meters*3.6/actual_seconds,
              'predicted_route_avg_speed_kmh': meters*3.6/predicted_seconds, 'actual_seconds': actual_seconds,
              'predicted_seconds': predicted_seconds, 'baseline_25_seconds': baseline_seconds})
        if len(trace) < 8:
            trace.append({'route_id': record['route_id'], 'hour': hour,
                'segments': [{'features': dict(zip(NAMES, v)), 'meters': d, 'predicted_speed_kmh': float(s),
                              'travel_seconds': d*3.6/s} for v, d, s in zip(vectors, distances, predicted)],
                'predicted_seconds': predicted_seconds})
    audit = pd.DataFrame(route_rows)
    audit.to_csv(OUT/'held_out_routes.csv', index=False)
    relative = np.abs(audit.predicted_seconds-audit.actual_seconds)/audit.actual_seconds
    route_report = {'routes': 80, 'cases': len(audit), 'all_edges_excluded_from_train_validation': True,
        'eta_mae_seconds': float(np.abs(audit.predicted_seconds-audit.actual_seconds).mean()),
        'eta_mape': float(relative.mean()), 'eta_p90_relative_error': float(np.quantile(relative, .9)),
        'baseline_25_mae_seconds': float(np.abs(audit.baseline_25_seconds-audit.actual_seconds).mean())}
    report = {'model_version': VERSION, 'label_source': 'synthetic', 'features': NAMES,
        'selection': 'validation MAE; test road IDs and 80 complete routes held out before sampling',
        'split': {name: {'rows': len(part), 'roads': int(part.road_id.nunique())} for name, part in zip(['train','validation','test'], [train,val,test])},
        'candidates': candidates, 'test_speed': metrics(test.speed_kmh.to_numpy(), test_prediction),
        'held_out_routes': route_report, 'minimum_speed_kmh': 15,
        'limitations': 'Accuracy against synthetic labels, not measured real traffic'}
    report['accepted'] = report['test_speed']['mae_kmh'] < .75 and route_report['eta_p90_relative_error'] < .03
    (OUT/'benchmark.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    (OUT/'prediction_trace.json').write_text(json.dumps(trace, indent=2), encoding='utf-8')
    vectors = test[NAMES].sample(1000, random_state=13).to_numpy()
    (OUT/'parity_vectors.json').write_text(json.dumps([{'features': v.tolist(), 'expected_speed_kmh': float(s)}
          for v, s in zip(vectors, winner.predict(vectors))]), encoding='utf-8')
    pd.DataFrame({'feature': NAMES, 'gain': winner.booster_.feature_importance(importance_type='gain')}).to_csv(OUT/'feature_importance.csv', index=False)
    print(json.dumps(report, indent=2), flush=True)
    if not report['accepted']:
        raise RuntimeError('SYNTHETIC_BENCHMARK_FAILED')


if __name__ == '__main__':
    main()

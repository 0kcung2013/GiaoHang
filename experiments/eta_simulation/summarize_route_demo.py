"""Readable route-average labels for the existing independent demo benchmark."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'output/eta_simulation/segment_ai'


def main():
    routes = json.loads((OUT.parent/'routes.json').read_text(encoding='utf-8'))
    distances = {r['route_id']: sum(r['route']['legs'][0]['annotation']['distance']) for r in routes}
    with (OUT/'held_out_routes.csv').open(encoding='utf-8', newline='') as handle:
        rows = list(csv.DictReader(handle))
    summary = []
    for row in rows:
        meters = distances[row['route_id']]
        actual, predicted = float(row['actual_seconds']), float(row['predicted_seconds'])
        row.update(distance_meters=meters,
                   simulated_route_avg_speed_kmh=meters*3.6/actual,
                   predicted_route_avg_speed_kmh=meters*3.6/predicted)
        speed = row['predicted_route_avg_speed_kmh']
        assert 15-1e-8 <= speed <= 50+1e-8
        assert abs(meters*3.6/speed-predicted) < 1e-6
        summary.append({'route_id': row['route_id'], 'hour': row['hour'],
            'distance_km': meters/1000,
            'simulated_route_avg_speed_kmh': row['simulated_route_avg_speed_kmh'],
            'ai_route_avg_speed_kmh': speed, 'ai_travel_minutes': predicted/60,
            'delivery_leg_with_handoff_minutes': predicted/60+5,
            'label_source': 'synthetic'})
    for name, records in [('held_out_routes.csv', rows), ('route_average_speeds.csv', summary)]:
        with (OUT/name).open('w', encoding='utf-8', newline='') as handle:
            writer = csv.DictWriter(handle, fieldnames=list(records[0]))
            writer.writeheader()
            writer.writerows(records)
    report = {'routes': len({row['route_id'] for row in rows}), 'cases': len(rows),
        'minimum_ai_average_speed_kmh': min(r['ai_route_avg_speed_kmh'] for r in summary),
        'maximum_ai_average_speed_kmh': max(r['ai_route_avg_speed_kmh'] for r in summary),
        'route_time_identity_verified': True, 'this_summary_step_retrains_model': False,
        'average_speed_is_model_derived_summary_not_input': True}
    (OUT/'route_average_verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report), flush=True)


if __name__ == '__main__':
    main()

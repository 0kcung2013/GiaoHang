"""Build a pinned legacy operating-area catalog; see docs/handoff/driver_dispatch_preferences.md.

Requires shapely. Inputs are downloaded explicitly, never during app startup.
"""
import json
import re
import unicodedata
from pathlib import Path
from shapely.geometry import shape, mapping


def normalized(value):
    value = value.lower().replace('đ', 'd').replace('–', ' ')
    value = ''.join(c for c in unicodedata.normalize('NFD', value) if not unicodedata.combining(c))
    value = re.sub(r'^(thanh pho|tinh|thi xa|huyen|quan)\s+', '', value.strip())
    return re.sub(r'[^a-z0-9]', '', value)


def main():
    root = Path(__file__).resolve().parents[1]
    provinces = json.loads((root / 'artifacts/dispatch_provinces.json').read_text())
    adm1 = json.loads((root / 'artifacts/dispatch_adm1.geojson').read_text())['features']
    adm2 = json.loads((root / 'artifacts/dispatch_adm2.geojson').read_text())['features']
    province_shapes = {normalized(f['properties']['shapeName']): shape(f['geometry']) for f in adm1}
    province_shapes['hue'] = province_shapes['thuathienhue']
    district_shapes = {}
    for f in adm2:
        district_shapes.setdefault(normalized(f['properties']['shapeName']), []).append(shape(f['geometry']))
    rows, missing = [], []
    for p in provinces:
        parent = province_shapes.get(normalized(p['name']))
        for d in p['districts']:
            matches = district_shapes.get(normalized(d['name']), [])
            matches = [g for g in matches if parent is not None and parent.covers(g.representative_point())]
            if len(matches) != 1:
                missing.append({'province': p['name'], 'district': d['name'], 'code': d['code']})
                continue
            geom = matches[0].simplify(0.00005, preserve_topology=True)
            boundary = mapping(geom)
            def rounded(value):
                if isinstance(value, (tuple, list)):
                    return [rounded(x) for x in value]
                return round(value, 7)
            boundary['coordinates'] = rounded(boundary['coordinates'])
            rows.append({'id': str(d['code']), 'province_code': str(p['code']),
                         'province_name': p['name'], 'name': d['name'], 'boundary': boundary})
    output = root / 'supabase/data/dispatch_areas'
    output.mkdir(parents=True, exist_ok=True)
    # Small import batches avoid tool/API payload limits.
    for offset in range(0, len(rows), 12):
        batch = rows[offset:offset + 12]
        values = []
        for row in batch:
            def q(v):
                return "'" + str(v).replace("'", "''") + "'"
            values.append('(' + ','.join(q(row[k]) for k in ['id', 'province_code', 'province_name', 'name']) +
                          ',public.ST_Multi(public.ST_CollectionExtract(public.ST_MakeValid(public.ST_SetSRID(public.ST_GeomFromGeoJSON(' +
                          q(json.dumps(row['boundary'], separators=(',', ':'))) + '),4326)),3)))')
        sql = 'INSERT INTO public.driver_operating_areas(id,province_code,province_name,name,boundary) VALUES\n'
        sql += ',\n'.join(values)
        sql += '\nON CONFLICT(id) DO UPDATE SET province_code=excluded.province_code,province_name=excluded.province_name,name=excluded.name,boundary=excluded.boundary;\n'
        (output / f'{offset // 12:03}.sql').write_text(sql, encoding='utf-8')
    (output / 'coverage.json').write_text(json.dumps({'available': len(rows), 'missing': missing}, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'available': len(rows), 'missing': len(missing), 'binh_duong': [r['name'] for r in rows if r['province_code'] == '74']}, ensure_ascii=False))


if __name__ == '__main__':
    main()

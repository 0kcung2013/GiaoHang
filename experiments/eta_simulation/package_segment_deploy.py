"""ETA-only packages, preserving all other files from the v14/v12 payload."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'output/eta_simulation/segment_ai'
CHANGED = {'delivery_eta.mjs','delivery_eta_sim_data.mjs','delivery_eta_sim_model.mjs',
           'delivery_eta_sim_profile.mjs','delivery_eta_sim_features.mjs',
           'delivery_eta_sim_segment_speeds.mjs','delivery_eta_sim_speed_features.mjs',
           'delivery_eta_sim_turn_features.mjs'}


def main():
    packages = []
    previous = {p['name']: {f['name']: f['content'] for f in p['files']}
                for p in json.loads((OUT/'v1_baseline_packages.json').read_text(encoding='utf-8'))}
    for name in ['accept-driver-order','refresh-order-eta']:
        entry = f'supabase/functions/{name}/index.ts'
        files = {}

        def visit(file):
            if file in files:
                return
            local = ROOT/file
            if Path(file).name in CHANGED:
                source = local.read_text(encoding='utf-8')
            elif file in previous[name]:
                source = previous[name][file]
            else:
                raise ValueError(f'MISSING_APPROVED_BASELINE: {file}')
            files[file] = source
            for match in re.finditer(r'(?:from\s+|import\s*)["\']([^"\']+)["\']', source):
                target = match.group(1)
                if target.startswith('.'):
                    visit((ROOT/Path(file).parent/target).resolve().relative_to(ROOT).as_posix())

        visit(entry)
        package = {'project_id':'erlpzwfbpjogvaulcxni','name':name,'verify_jwt':True,
                   'entrypoint_path':entry,'files':[{'name':n,'content':s} for n,s in files.items()]}
        packages.append(package)
    (OUT/'deploy_packages.json').write_text(json.dumps(packages,ensure_ascii=False),encoding='utf-8')
    manifest = {'baseline_versions':{'accept-driver-order':14,'refresh-order-eta':12},
        'deployment_status':'prepared', 'model_version':'hcm_synthetic_segment_speed_v2',
        'profile_version':6,'eta_version':10,'schema_changes':False,'auth_changes':False,
        'functions':[{'name':p['name'],'files':[{'name':f['name'],
            'sha256':hashlib.sha256(f['content'].encode()).hexdigest(),
            'updated':Path(f['name']).name in CHANGED} for f in p['files']]} for p in packages]}
    (OUT/'deploy_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print(json.dumps([{'name':p['name'],'files':len(p['files']),
        'bytes':sum(len(f['content'].encode()) for f in p['files'])} for p in packages]))


if __name__ == '__main__':
    main()

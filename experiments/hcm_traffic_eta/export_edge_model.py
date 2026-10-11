"""Export the exact shipped Dart model/profile to the ETA Edge Function, without retraining."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[2]
model_dir = root / 'apps/delivery_app/lib/core/ml'

def value(filename, name):
    source = (model_dir / filename).read_text(encoding='utf-8')
    match = re.search(rf'{name}\s*=\s*(.*?);', source, re.S)
    if not match:
        raise ValueError(f'Missing {name}')
    return ''.join(re.findall(r"'([^']*)'", match.group(1)))

target = root / 'supabase/functions/_shared/delivery_eta_model_data.mjs'
target.write_text(
    '// Generated from the shipped Dart model by export_edge_model.py.\n'
    + 'export const modelVersion = ' + json.dumps(value('delivery_eta_ai_model_data.dart', 'deliveryEtaAiModelVersion')) + ';\n'
    + 'export const modelPayload = ' + json.dumps(value('delivery_eta_ai_model_data.dart', 'deliveryEtaAiModelPayload')) + ';\n'
    + 'export const profilePayload = ' + json.dumps(value('delivery_eta_ai_road_profile_data.dart', 'deliveryEtaAiRoadProfilePayload')) + ';\n',
    encoding='utf-8',
)
print(f'Exported {target.relative_to(root)}')

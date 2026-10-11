"""Export identical numeric speed trees to Edge and Dart, plus Python parity cases."""
import base64
import importlib.util
import json
import struct
from pathlib import Path

import joblib
import pandas as pd
from model import features

VERSION = "smarttraffic_hcm_speed_v1"


def main():
    root = Path(__file__).resolve().parents[2]
    spec = importlib.util.spec_from_file_location("tree_export", root / "experiments/hcm_traffic_eta/export_model_to_dart.py")
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    artifact = joblib.load(root / "output/smarttraffic_eta/full_model/time_only_lightgbm.joblib")
    model = artifact["model"]
    if model.feature_name_ != ["hour", "weekday", "weekend"]:
        raise ValueError("Unexpected feature contract")
    trees = model.booster_.dump_model()["tree_info"]
    payload = bytearray(b"ETA1") + struct.pack("<H", len(trees))
    for tree in trees:
        nodes = helper.flatten_tree(tree["tree_structure"])
        payload.extend(struct.pack("<H", len(nodes)))
        for node in nodes:
            payload.extend(struct.pack("<hdhhB", *node))
    encoded = base64.b64encode(payload).decode()
    (root / "supabase/functions/_shared/delivery_eta_model_data.mjs").write_text(
        f"// Generated SmartTraffic synthetic speeds, km/h.\nexport const modelVersion = '{VERSION}';\nexport const modelPayload = '{encoded}';\n", encoding="utf-8")
    chunks = "\n".join(f"  '{encoded[i:i+160]}'" for i in range(0, len(encoded), 160))
    (root / "apps/delivery_app/lib/core/ml/delivery_eta_ai_model_data.dart").write_text(
        f"// GENERATED: SmartTraffic synthetic motorbike speeds (km/h).\nconst deliveryEtaAiModelVersion = '{VERSION}';\nconst deliveryEtaAiModelPayload =\n{chunks};\n", encoding="utf-8")
    frame = pd.DataFrame({"time": pd.date_range("2026-10-12", periods=7*1440, freq="min")})
    values = model.predict(features(frame, artifact["roads"], False))
    fixtures = [{"at": t.isoformat()+"+07:00", "speed": float(v)} for t,v in zip(frame.time, values)]
    (root / "apps/delivery_app/test/fixtures/smarttraffic_speed_parity.json").write_text(json.dumps(fixtures, separators=(",", ":")), encoding="utf-8")
    print(f"Exported {len(trees)} trees, {len(payload)} bytes, {len(fixtures)} parity cases")


if __name__ == "__main__":
    main()

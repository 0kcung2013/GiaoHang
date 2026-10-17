"""Install Flutter assets and prepare a reviewable Edge patch before deployment."""
import json
import shutil
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[2]
    output = root / "output/eta_simulation"
    assets = root / "packages/giaohang_mobile/assets/ml"
    shutil.copyfile(output / "model.json", assets / "eta_simulation_model.json")
    shutil.copyfile(output / "context.json", assets / "eta_simulation_context.json")
    shared = output / "edge/_shared"
    shared.mkdir(parents=True, exist_ok=True)
    runtime = Path(__file__).parent / "runtime"
    names = {"features.mjs": "delivery_eta_sim_features.mjs", "model.mjs": "delivery_eta_sim_model.mjs", "profile.mjs": "delivery_eta_sim_profile.mjs", "allocation.mjs": "delivery_eta_sim_allocation.mjs", "segment_speeds.mjs": "delivery_eta_sim_segment_speeds.mjs", "junction_speeds.mjs": "delivery_eta_sim_junction_speeds.mjs", "speed_features.mjs": "delivery_eta_sim_speed_features.mjs"}
    for original, name in names.items():
        source = (runtime / original).read_text(encoding="utf-8")
        for before, after in names.items():
            source = source.replace(f"'./{before}'", f"'./{after}'")
        (shared / name).write_text(source, encoding="utf-8")
    metadata = json.loads((output / "model.json").read_text(encoding="utf-8"))
    context = json.loads((output / "context.json").read_text(encoding="utf-8"))
    (shared / "delivery_eta_sim_data.mjs").write_text(
        "// Synthetic ETA model and public OSM spatial context. No user GPS labels.\n"
        + "export const modelMetadata=" + json.dumps(metadata, ensure_ascii=False, separators=(",", ":")) + ";\n"
        + "export const roadContext=" + json.dumps(context, separators=(",", ":")) + ";\n", encoding="utf-8")
    (shared / "delivery_eta_synthetic.mjs").write_text("""import {modelMetadata,roadContext} from './delivery_eta_sim_data.mjs';
import {EtaCorrectionModel} from './delivery_eta_sim_model.mjs';
import {buildEtaProfile} from './delivery_eta_sim_profile.mjs';
export const modelVersion=modelMetadata.version;
const model=new EtaCorrectionModel(modelMetadata);
export function buildTrafficProfile(route,at) {
  try { return buildEtaProfile(route,at,model,roadContext); } catch { return null; }
}
export function routeTravelMinutes(route,at) {
  return buildTrafficProfile(route,at)?.travel_minutes??null;
}
""", encoding="utf-8")
    current = root / "supabase/functions/_shared"
    clock = (current / "delivery_eta_speed_profile.mjs").read_text(encoding="utf-8").replace("'./delivery_eta_traffic.mjs'", "'./delivery_eta_synthetic.mjs'")
    (shared / "delivery_eta_speed_profile.mjs").write_text(clock, encoding="utf-8")
    eta = (current / "delivery_eta.mjs").read_text(encoding="utf-8")
    eta = eta.replace("'./delivery_eta_traffic.mjs'", "'./delivery_eta_synthetic.mjs'")
    eta = eta.replace("annotations=nodes,distance`", "annotations=nodes,distance,duration`")
    if "annotation_durations:" not in eta:
        eta = eta.replace("annotation_nodes:r.legs?.[0]?.annotation?.nodes??[]", "annotation_nodes:r.legs?.[0]?.annotation?.nodes??[],annotation_distances:r.legs?.[0]?.annotation?.distance??[],annotation_durations:r.legs?.[0]?.annotation?.duration??[]")
    eta = eta.replace("const base=route.distance_meters/1000/ETA_POLICY.speed_kmh*60;", "const validRoutingSeconds=Number.isFinite(route.osrm_seconds)&&route.osrm_seconds>0&&route.distance_meters/route.osrm_seconds*3.6>=1&&route.distance_meters/route.osrm_seconds*3.6<=90;\n    const base=predict===routeTravelMinutes&&validRoutingSeconds?route.osrm_seconds/60:route.distance_meters/1000/ETA_POLICY.speed_kmh*60;")
    eta = eta.replace("{version:5,calculation_mode", "{version:6,calculation_mode")
    eta = eta.replace("dataset_source:'UTraffic HCMC historical segment_status velocity',is_synthetic:false", "dataset_source:'Geofabrik Vietnam OSM + synthetic route travel-time simulation',is_synthetic:true")
    eta = eta.replace("dataset_version:6,velocity_unit_status:'km/h working inference; publisher data card does not explicitly state unit'", "dataset_version:1,velocity_unit_status:'synthetic travel-time labels in seconds'")
    (shared / "delivery_eta.mjs").write_text(eta, encoding="utf-8")
    (output / "edge_patch_manifest.json").write_text(json.dumps({
        "project": "erlpzwfbpjogvaulcxni", "functions": ["accept-driver-order", "refresh-order-eta"],
        "existing_shared_files_to_update": ["delivery_eta.mjs", "delivery_eta_speed_profile.mjs"],
        "new_shared_files": [*names.values(), "delivery_eta_sim_data.mjs", "delivery_eta_synthetic.mjs"],
        "verify_jwt": True, "schema_changes": False, "auth_changes": False,
        "source_directory": str(shared), "deployment": "requires separate approval under AGENTS.md"
    }, indent=2), encoding="utf-8")
    print(json.dumps({"app_assets": ["eta_simulation_model.json", "eta_simulation_context.json"],
                      "model_bytes": (output / "model.json").stat().st_size,
                      "context_bytes": (output / "context.json").stat().st_size,
                      "prepared_edge_files": len(list(shared.glob('*.mjs')))}))


if __name__ == "__main__":
    main()

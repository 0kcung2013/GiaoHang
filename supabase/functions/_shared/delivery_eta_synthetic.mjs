import {modelMetadata,roadContext} from './delivery_eta_sim_data.mjs';
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

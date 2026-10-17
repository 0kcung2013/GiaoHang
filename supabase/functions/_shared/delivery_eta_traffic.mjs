import {modelMetadata,modelVersion} from './delivery_eta_model_data.mjs';
import {roadNetwork} from './delivery_eta_road_network_data.mjs';
import {SpeedModel} from './delivery_eta_utraffic_model.mjs';
import {RoadMatcher} from './delivery_eta_road_matcher.mjs';
import {buildRouteSpeedProfile as build} from './delivery_eta_utraffic_profile.mjs';
export {modelVersion};
const model=new SpeedModel(modelMetadata),matcher=new RoadMatcher(roadNetwork);
export const supportsPoint=point=>matcher.supports(point);
export function predictSpeed(at,road=null) {
  if (!road) return null;
  try { return model.speedAt(road,at); } catch { return null; }
}
// A point alone does not identify a directed segment. Route consumers use profile.
export const predictMultiplier=()=>null;
export function buildTrafficProfile(route,at,options={}) {
  if (route?.distance_meters===0 && Number.isFinite(Date.parse(at)))
    return {distance_meters:0,route_points:route.points,speed_profile:[],travel_minutes:0,
      used_ai:false,all_sections_ai:false,ai_coverage_ratio:0,forecast_at:new Date(at).toISOString()};
  try {
    return build({distance:route.distance_meters,geometry:{coordinates:route.points},
      legs:[{annotation:{nodes:route.annotation_nodes??[]}}]},at,model,matcher,options);
  } catch { return null; }
}
export function routeTravelMinutes(route,at) {
  const profile=buildTrafficProfile(route,at);
  return profile?.used_ai?profile.travel_minutes:null;
}
export function routeMultiplier(route,at) {
  // Legacy quote contract rejects a route leaving scope; assignment profiles
  // deliberately preserve per-section AI/fallback instead.
  if (!route?.points?.every(supportsPoint)) return null;
  const minutes=routeTravelMinutes(route,at);
  return minutes===null?null:minutes/(route.distance_meters/1000/50*60);
}

import {buildSegmentSpeeds,supportsSpeedSimulation,segmentSpeedVersion,coverageVersion} from './segment_speeds.mjs';
import {routeJunctions} from './junction_speeds.mjs';

function fallbackProfile(route,at,metadata) {
  const seconds=route.duration,speed=route.distance*3.6/seconds;
  return {distance_meters:route.distance,route_points:route.geometry.coordinates,forecast_at:new Date(Date.parse(at)).toISOString(),
    travel_minutes:seconds/60,baseline_seconds:seconds,osrm_seconds:seconds,used_ai:false,all_sections_ai:false,
    ai_coverage_ratio:0,ai_distance_meters:0,is_synthetic:false,profile_version:6,model_version:metadata.version,
    coverage_version:coverageVersion,fallback_reason:'outside_training_area',
    dataset_label:metadata.dataset_label,dataset_scope:metadata.dataset_scope,
    speed_profile:[{start_meters:0,end_meters:route.distance,speed_kmh:speed,used_ai:false,traffic_available:false,source:'routing_baseline'}]};
}

export function normalizeRoute(raw) {
  const distanceMeters=raw.distance??raw.distance_meters;
  const given=raw.duration??raw.osrm_seconds;
  const valid=Number.isFinite(given)&&given>0&&distanceMeters/given*3.6>=1&&distanceMeters/given*3.6<=90;
  return {distance:distanceMeters,duration:valid?given:distanceMeters*.144,valid_baseline:valid,
    geometry:raw.geometry??{coordinates:raw.points},junction_points:routeJunctions(raw),legs:raw.legs??[{annotation:{nodes:raw.annotation_nodes??[],distance:raw.annotation_distances??[],duration:raw.annotation_durations??[]}}]};
}
export function buildEtaProfile(raw,at,model,context) {
  const route=normalizeRoute(raw),start=Date.parse(at);
  if(!Number.isFinite(start))throw new Error('INVALID_ETA_TIME');
  // Validate geometry even when the route is outside the model's demo domain.
  if(!Number.isFinite(route.distance)||route.distance<0||!Array.isArray(route.geometry?.coordinates)||route.geometry.coordinates.length<2||!route.geometry.coordinates.every(p=>Array.isArray(p)&&p.length===2&&p.every(Number.isFinite)&&Math.abs(p[0])<=180&&Math.abs(p[1])<=90))throw new Error('INVALID_ETA_ROUTE');
  if(route.distance===0)return {distance_meters:0,route_points:route.geometry.coordinates,speed_profile:[],travel_minutes:0,used_ai:false,all_sections_ai:false,forecast_at:new Date(start).toISOString()};
  if(!supportsSpeedSimulation(route))return fallbackProfile(route,at,model.metadata);
  const sections=buildSegmentSpeeds(route,context,at,model);
  const minutes=sections.reduce((sum,s)=>sum+(s.end_meters-s.start_meters)*.06/s.speed_kmh,0);
  return {distance_meters:route.distance,route_points:route.geometry.coordinates,forecast_at:new Date(start).toISOString(),
    speed_profile:sections,travel_minutes:minutes,baseline_seconds:route.duration,osrm_seconds:route.duration,
    used_ai:true,all_sections_ai:true,ai_distance_meters:route.distance,ai_coverage_ratio:1,color_metric:'speed_kmh',
    coverage_version:coverageVersion,
    model_version:model.metadata.version,is_synthetic:true,dataset_label:model.metadata.dataset_label,
    dataset_scope:model.metadata.dataset_scope,
    profile_version:6,speed_model_version:segmentSpeedVersion,profile_source:segmentSpeedVersion,uses_realtime_traffic:false};
}

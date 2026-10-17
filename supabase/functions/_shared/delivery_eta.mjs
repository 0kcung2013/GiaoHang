import { routeTravelMinutes, modelVersion } from './delivery_eta_synthetic.mjs';
import { validPoint } from '../accept-driver-order/deadline.mjs';
import { buildRouteSpeedProfile, demoForecastOrigin } from './delivery_eta_speed_profile.mjs';
import { routeJunctions } from './delivery_eta_sim_junction_speeds.mjs';

export const ETA_MODE = 'assignment_once_v1';
export const ETA_POLICY = Object.freeze({ speed_kmh:25, preparation_minutes:5,
  pickup_minutes:5, handoff_minutes:5, gps_max_age_ms:180000 });
export const activeEtaStatuses = ['assigned','picking_up','delivering'];
export function etaPhase(order) {
  if (!order.driver_id || !activeEtaStatuses.includes(order.status)) return null;
  return 'fixed';
}
export function fixedEtaForOrder(order) {
  const eta = order.delivery_eta;
  return etaPhase(order) && eta?.driver_id === order.driver_id
    && eta.calculation_mode === ETA_MODE
    && Number.isFinite(Date.parse(eta.computed_at))
    && Number.isFinite(Date.parse(eta.initial_predicted_at)) ? eta : null;
}
// Only this exception may change the accepted forecast. Always derive from
// the original timestamp, so retries can never subtract another five minutes.
export function applyEarlyDeparture(eta, departedAt) {
  if (!departedAt) return eta;
  const assigned = Date.parse(eta.assigned_at), departed = Date.parse(departedAt);
  const saved = departed >= assigned && departed < assigned + ETA_POLICY.preparation_minutes*60000
    ? ETA_POLICY.preparation_minutes : 0;
  return {...eta,departed_at:departedAt,preparation_removed_minutes:saved,
    preparation_minutes:ETA_POLICY.preparation_minutes-saved,
    remaining_minutes:eta.initial_total_minutes-saved,
    predicted_at:new Date(Date.parse(eta.initial_predicted_at)-saved*60000).toISOString()};
}
export function freshGps(driver, now) {
  const age = now-new Date(driver.location_updated_at).getTime();
  return validPoint(driver.current_lat,driver.current_lng) && Number.isFinite(age)
    && age >= -30000 && age <= ETA_POLICY.gps_max_age_ms;
}
export async function roadRoute(from, to, fetcher = fetch) {
  if (![from,to].every(p=>validPoint(p[1],p[0]))) throw new Error('INVALID_ETA_COORDINATES');
  const coords = [from,to].map(p=>p.join(',')).join(';');
  const response = await fetcher(`https://router.project-osrm.org/route/v1/driving/${coords}?overview=full&geometries=geojson&steps=true&annotations=nodes,distance,duration`,
    {signal:AbortSignal.timeout(5000)});
  if (!response.ok) throw new Error('ETA_ROAD_UNAVAILABLE');
  const body = await response.json(), r = body.routes?.[0];
  if (body.code !== 'Ok' || !Number.isFinite(r?.distance) || r.distance < 0
    || !Array.isArray(r.geometry?.coordinates) || r.geometry.coordinates.length < 2
    || !r.geometry.coordinates.every(p=>Array.isArray(p)&&validPoint(p[1],p[0]))) throw new Error('ETA_ROAD_UNAVAILABLE');
  return {distance_meters:r.distance,osrm_seconds:r.duration,points:r.geometry.coordinates,junction_points:routeJunctions(r),annotation_nodes:r.legs?.[0]?.annotation?.nodes??[],annotation_distances:r.legs?.[0]?.annotation?.distance??[],annotation_durations:r.legs?.[0]?.annotation?.duration??[]};
}

export async function calculateEta({order,driver,assignedAt,departedAt,now=Date.now(),
  getRoute=roadRoute,predict=routeTravelMinutes}) {
  const phase = etaPhase(order);
  if (!phase) return null;
  const existing = fixedEtaForOrder(order);
  if (existing) return existing;
  const accepted = Date.parse(assignedAt);
  if (!Number.isFinite(accepted)) throw new Error('ETA_ASSIGNMENT_TIME_MISSING');
  if (!freshGps(driver,now)) throw new Error('ETA_LOCATION_STALE');
  const at = new Date(now).toISOString();
  const prep = ETA_POLICY.preparation_minutes, pickup = ETA_POLICY.pickup_minutes,
    handoff = ETA_POLICY.handoff_minutes;
  const origin=[driver.current_lng,driver.current_lat], pick=[order.pickup_lng,order.pickup_lat],
    drop=[order.delivery_lng,order.delivery_lat];
  const leg = (route, time) => {
    const validRoutingSeconds=Number.isFinite(route.osrm_seconds)&&route.osrm_seconds>0&&route.distance_meters/route.osrm_seconds*3.6>=1&&route.distance_meters/route.osrm_seconds*3.6<=90;
    const base=predict===routeTravelMinutes&&validRoutingSeconds?route.osrm_seconds/60:route.distance_meters/1000/ETA_POLICY.speed_kmh*60;
    const profile=predict===routeTravelMinutes
      ?buildRouteSpeedProfile(route,new Date(time).toISOString()):null;
    let minutes;
    try { minutes=profile?profile.travel_minutes:predict(route,new Date(time).toISOString()); } catch { minutes=null; }
    const usedAi=Number.isFinite(minutes)&&minutes>0 && (profile?.used_ai??true);
    const validProfile=profile && Number.isFinite(minutes) && minutes>=0;
    const travel=validProfile?minutes:(usedAi?minutes:base);
    return {...profile,distance_meters:route.distance_meters,baseline_minutes:base,
      travel_minutes:travel,multiplier:base>0?travel/base:1,
      predicted_speed_kmh:(validProfile||usedAi)&&travel>0?route.distance_meters/1000/(travel/60):null,
      used_ai:usedAi,osrm_seconds:route.osrm_seconds};
  };
  const forecastOrigin=demoForecastOrigin(order.traffic_demo_key,assignedAt);
  // Both legs use the same frozen traffic snapshot, regardless of their ETA.
  const approach=leg(await getRoute(origin,pick),forecastOrigin);
  const delivery=leg(await getRoute(pick,drop),forecastOrigin);
  const total=prep+pickup+handoff+approach.travel_minutes+delivery.travel_minutes;
  const predictedAt=new Date(accepted+total*60000).toISOString();
  const estimate = {version:10,calculation_mode:ETA_MODE,driver_id:order.driver_id,
    assigned_at:assignedAt,departed_at:null,
    phase,computed_at:at,location_updated_at:driver.location_updated_at,
    initial_predicted_at:predictedAt,predicted_at:predictedAt,
    initial_total_minutes:total,remaining_minutes:total,preparation_removed_minutes:0,
    preparation_minutes:prep,pickup_minutes:pickup,handoff_minutes:handoff,
    approach,delivery,model_version:modelVersion,reference_speed_kmh:ETA_POLICY.speed_kmh,
    traffic_demo_key:order.traffic_demo_key??null,ai_clock_at:new Date(forecastOrigin).toISOString(),
    uses_realtime_traffic:false,dataset_source:'OpenStreetMap road attributes + LightGBM trained on synthetic segment speeds',is_synthetic:approach.is_synthetic===true||delivery.is_synthetic===true,
    dataset_version:3,velocity_unit_status:'synthetic segment speed labels in km/h; minimum moving speed 15 km/h'};
  return applyEarlyDeparture(estimate,departedAt);
}

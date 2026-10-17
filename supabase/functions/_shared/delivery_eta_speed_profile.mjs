import {buildTrafficProfile} from './delivery_eta_synthetic.mjs';
export function demoForecastOrigin(key,assignedAt) {
  if (key==='peak') return Date.parse('2020-12-16T18:00:00+07:00');
  if (key==='off_peak') return Date.parse('2020-12-16T12:00:00+07:00');
  return Date.parse(assignedAt);
}
export const buildRouteSpeedProfile=(route,at,options={})=>buildTrafficProfile(route,at,options);

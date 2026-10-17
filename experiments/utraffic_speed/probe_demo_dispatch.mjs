// Read-only replay of the actual OSRM table and the production offer ranker.
import {readFileSync, writeFileSync} from 'node:fs';
import {rankDriversByRoadDistance} from '../../supabase/functions/_shared/road_distance.mjs';

const geo = readFileSync('apps/delivery_app/lib/core/utils/geo_utils.dart', 'utf8');
const [, driverLat, driverLng] = geo.match(/'taixe@gmail.com': LatLng\(([^,]+), ([^)]+)\)/);
const source = readFileSync('apps/delivery_app/lib/features/customer/screens/create_order/models/traffic_demo_scenario.dart', 'utf8');
const [, pickupLat, pickupLng] = source.match(/pickup: LatLng\(([^,]+), ([^)]+)\)/);
const driver = {user_id:'primary-demo-driver',lat:Number(driverLat),lng:Number(driverLng)};
const pickup = {lat:Number(pickupLat),lng:Number(pickupLng)};
if (process.argv.includes('--candidates')) {
  const candidates = [
    {user_id:'north-1',lat:10.8300,lng:106.7008},
    {user_id:'north-2',lat:10.8300,lng:106.6960},
    {user_id:'north-3',lat:10.8285,lng:106.7020},
    {user_id:'north-4',lat:10.8295,lng:106.7040},
  ];
  let table;
  const ranked = await rankDriversByRoadDistance(candidates,pickup,{
    fetcher:async(url,options)=>{
      const response=await fetch(url,options);
      table=await response.clone().json();
      return response;
    },
  });
  const result={candidates,table,ranked};
  writeFileSync('output/utraffic_speed/routes/dispatch_seed_candidates.json',JSON.stringify(result,null,2));
  console.log(JSON.stringify({roads:candidates.map((c,i)=>({...c,meters:table.distances[i][0],snap_meters:table.sources[i].distance})),eligible:ranked.map(c=>c.user_id)}));
  process.exit(0);
}
const replay = {driver, pickup};
const ranked = await rankDriversByRoadDistance([driver], pickup, {
  fetcher: async (url, options) => {
    replay.source_url = url;
    const response = await fetch(url, options);
    replay.table = await response.clone().json();
    return response;
  },
});
replay.eligible = ranked.length === 1;
replay.checked_at = new Date().toISOString();
writeFileSync('apps/delivery_app/test/fixtures/traffic_demo_dispatch.json', JSON.stringify(replay, null, 2));
console.log(JSON.stringify({driver, pickup, road_distance_meters:replay.table.distances[0][0],
  source_snap_meters:replay.table.sources[0].distance, eligible:replay.eligible}));

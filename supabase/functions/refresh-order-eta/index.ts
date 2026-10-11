import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1';
import { calculateEta, etaPhase, fixedEtaForOrder } from '../_shared/delivery_eta.mjs';

const headers = {'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods':'POST, OPTIONS','Content-Type':'application/json'};
const json = (body: unknown, status=200) => new Response(JSON.stringify(body),{status,headers});

Deno.serve(async req => {
  if (req.method==='OPTIONS') return new Response(null,{headers});
  if (req.method!=='POST') return json({error:'METHOD_NOT_ALLOWED'},405);
  try {
    const authorization=req.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) return json({error:'AUTH_REQUIRED'},401);
    const url=Deno.env.get('SUPABASE_URL')!;
    const userClient=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{
      global:{headers:{Authorization:authorization}},auth:{persistSession:false}});
    const {data:{user},error:authError}=await userClient.auth.getUser();
    if (authError || !user) return json({error:'AUTH_REQUIRED'},401);
    const body=await req.json();
    if (typeof body.order_id!=='string' || !/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(body.order_id))
      return json({error:'INVALID_ORDER_ID'},400);
    const admin=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
    const {data:order,error}=await admin.from('orders').select(
      'id,customer_id,driver_id,status,pickup_lat,pickup_lng,delivery_lat,delivery_lng,pickup_arrived_at,actual_picked_up_at,delivery_eta,traffic_demo_key',
    ).eq('id',body.order_id).maybeSingle();
    if (error) return json({error:'ETA_LOOKUP_FAILED'},500);
    if (!order || (order.customer_id!==user.id && order.driver_id!==user.id))
      return json({error:'ORDER_ACCESS_DENIED'},403);
    const result = (eta: unknown, issue: string|null=null) => json({eta,issue,
      server_now:new Date().toISOString(),status:order.status,driver_id:order.driver_id});
    if (!etaPhase(order)) return result(null);
    // A fixed prediction does not depend on later GPS, route or traffic changes.
    const cached=fixedEtaForOrder(order);
    if (cached) return result(cached);
    const {data:driver,error:driverError}=await admin.from('drivers')
      .select('current_lat,current_lng,location_updated_at').eq('user_id',order.driver_id).maybeSingle();
    if (driverError || !driver) return result(null,'ETA_LOCATION_STALE');
    const {data:logs,error:logsError}=await admin.from('order_status_logs')
      .select('title,created_at').eq('order_id',order.id).eq('logged_by',order.driver_id)
      .eq('title','Đã có tài xế nhận đơn').order('created_at',{ascending:false});
    if (logsError) return json({error:'ETA_LOOKUP_FAILED'},500);
    const sameDriver=order.delivery_eta?.driver_id===order.driver_id;
    const snapshot=sameDriver?order.delivery_eta:null;
    const assignedAt=snapshot?.assigned_at??logs?.find(x=>x.title==='Đã có tài xế nhận đơn')?.created_at;
    const now=Date.now();
    try {
      const estimate=await calculateEta({order,driver,assignedAt,departedAt:snapshot?.departed_at,
        now});
      const {data:committed,error:commitError}=await admin.rpc('commit_order_delivery_eta',{
        p_order_id:order.id,p_driver_id:order.driver_id,p_status:order.status,
        p_pickup_arrived_at:order.pickup_arrived_at,p_actual_picked_up_at:order.actual_picked_up_at,
        p_delivery_arrived_at:null,
        p_snapshot:estimate,
      });
      if (commitError) return result(null,'ETA_CONTEXT_CHANGED');
      return result(committed);
    } catch (e) {
      const issue=e instanceof Error?e.message:'ETA_UNAVAILABLE';
      console.warn('[OrderETA]',issue);
      return result(cached,issue);
    }
  } catch {
    return json({error:'ETA_UNAVAILABLE'},500);
  }
});

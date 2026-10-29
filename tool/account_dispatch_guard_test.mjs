// Isolated proposal regression. No network or production writes.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
process.on('uncaughtException',e=>{console.error(e.code??'TEST_FAILURE',e.message,e.where??'');process.exit(1);});
const {PGlite}=await import(pathToFileURL(resolve(process.argv[2])).href);
const db=new PGlite();let checks=0;
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const check=(v,m)=>{assert.ok(v,m);checks++;};
const scalar=async(sql,params=[])=>(await db.query(sql,params)).rows[0].value;
await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;
CREATE SCHEMA auth;CREATE SCHEMA private;
GRANT USAGE ON SCHEMA private TO service_role;
CREATE TYPE public.order_status AS ENUM('pending','confirmed','assigned','picking_up','delivering','return_approved','returning');
CREATE TABLE auth.users(id uuid PRIMARY KEY,banned_until timestamptz);
CREATE TABLE public.users(id uuid PRIMARY KEY,role text);
CREATE TABLE public.account_control_events(event_seq bigint GENERATED ALWAYS AS IDENTITY,user_id uuid,action text,disabled_until timestamptz,created_at timestamptz);
CREATE TABLE public.drivers(user_id uuid PRIMARY KEY,is_available boolean,approval_status text,acceptance_locked_until timestamptz,current_lat float8,current_lng float8,location_updated_at timestamptz,updated_at timestamptz);
CREATE TABLE public.orders(id uuid PRIMARY KEY,customer_id uuid,driver_id uuid,status public.order_status,offered_driver_id uuid,
 assignment_timed_out_at timestamptz,assignment_expires_at timestamptz,payment_status text,note text,offer_expires_at timestamptz,
 rejected_by jsonb,driver_advance_amount bigint,pickup_lat float8,pickup_lng float8,tracking_code text,pickup_address text,status_note text,estimated_delivery_at timestamptz);
CREATE TABLE public.driver_wallet_transactions(driver_id uuid,status text,available_delta bigint);
CREATE TABLE public.order_status_logs(order_id uuid,status public.order_status,title text,description text,logged_by uuid,created_at timestamptz DEFAULT now());
CREATE TABLE public.notifications(user_id uuid,title text,body text,type text,is_read boolean,order_id uuid,created_at timestamptz DEFAULT now());
-- PostGIS/road quotes are fixtures: only the new account gates are under test.
CREATE DOMAIN public.geography AS text;
CREATE FUNCTION public.st_makepoint(float8,float8) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT $1::text||','||$2::text$$;
CREATE FUNCTION public.st_setsrid(text,integer) RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT $1$$;
CREATE FUNCTION public.st_dwithin(public.geography,public.geography,integer) RETURNS boolean LANGUAGE sql IMMUTABLE AS $$SELECT true$$;
CREATE FUNCTION private.valid_pickup_road_quote(jsonb,public.drivers,public.orders,integer,integer) RETURNS boolean LANGUAGE sql AS $$SELECT true$$;
CREATE FUNCTION private.driver_transfer_window(uuid,timestamptz) RETURNS TABLE(order_id uuid,status public.order_status,transferred_at timestamptz)
LANGUAGE sql AS $$SELECT NULL::uuid,NULL::public.order_status,NULL::timestamptz WHERE false$$;
CREATE FUNCTION public.accept_order(p_id uuid) RETURNS void LANGUAGE sql AS $$UPDATE public.orders SET driver_id=(current_setting('request.jwt.claims')::jsonb->>'sub')::uuid,status='assigned' WHERE id=p_id$$;
CREATE FUNCTION public.claim_free_pick_order(uuid) RETURNS void LANGUAGE sql AS $$SELECT public.accept_order($1)$$;
GRANT SELECT,UPDATE ON public.orders TO service_role;
`);
await db.exec(await readFile(process.argv[3] || 'docs/proposals/account_dispatch_guard.sql','utf8'));
for(const n of [1,2]){
 await db.query("INSERT INTO public.users VALUES($1,'driver')",[id(n)]);
 await db.query('INSERT INTO auth.users VALUES($1,NULL)',[id(n)]);
 await db.query("INSERT INTO public.drivers VALUES($1,true,'approved',NULL,10.7,106.7,now(),now())",[id(n)]);
}
await db.query("INSERT INTO public.orders(id,status,assignment_expires_at,payment_status,driver_advance_amount,pickup_lat,pickup_lng,tracking_code,pickup_address) VALUES($1,'pending',now()+interval '1 hour','paid',0,10.7,106.7,'TEST','Test pickup')",[id(10)]);
const gate=()=>scalar('SELECT private.driver_account_access_gate($1) value',[id(1)]);
const at=ago=>scalar(`SELECT private.account_disabled_at($1,now()-make_interval(mins=>$2)) value`,[id(1),ago]);
const candidates=async()=>(await db.query('SELECT user_id FROM private.road_driver_candidates($1)',[id(10)])).rows;
check(await gate(),'enabled driver passes native account gate');
check((await candidates()).length===2,'normal candidate selection unchanged');
await db.query("UPDATE auth.users SET banned_until=now()+interval '1 hour' WHERE id=$1",[id(1)]);
check(!(await gate()),'native ban blocks the gate');
check((await candidates()).every(r=>r.user_id!==id(1)),'banned driver excluded from candidates');
const quote=[{user_id:id(1),distance_meters:100,duration_seconds:30}];
check(await scalar('SELECT public.commit_road_driver_offer($1,$2::jsonb) value',[id(10),JSON.stringify(quote)])===null,'stale routing quote cannot offer to disabled account');
check(await scalar('SELECT offered_driver_id value FROM public.orders WHERE id=$1',[id(10)])===null,'rejected offer leaves order unchanged');
await db.exec('SET ROLE service_role');
await assert.rejects(db.query('SELECT * FROM public.accept_driver_order_with_deadline($1,$2,0)',[id(10),id(1)]),e=>e.code==='42501');checks++;
await db.exec('RESET ROLE');
await db.query('UPDATE auth.users SET banned_until=NULL WHERE id=$1',[id(1)]);
check(await gate(),'native release restores eligibility without changing acceptance locks');
check(await scalar('SELECT public.commit_road_driver_offer($1,$2::jsonb) value',[id(10),JSON.stringify(quote)])===id(1),'enabled driver offer still commits');
check(await scalar('SELECT count(*)::int value FROM public.notifications')===1,'normal offer still notifies once');
await db.exec('SET ROLE service_role');
check((await db.query('SELECT * FROM public.accept_driver_order_with_deadline($1,$2,0)',[id(10),id(1)])).rows[0].order_id===id(10),'enabled driver acceptance still delegates to existing business flow');
await db.exec('RESET ROLE');
await db.query("INSERT INTO public.account_control_events(user_id,action,created_at,disabled_until) VALUES($1,'disable',now()-interval '1 hour',now()-interval '30 minutes')",[id(1)]);
check(await at(45),'historical ban recognized after expiry');
check(!(await at(15)),'post-expiry time is enabled');
check(!(await at(75)),'pre-ban time is enabled');
const refuse=async(order,ago,expired=true)=>db.query("SELECT private.record_driver_offer_refusal($1,$2,'pending',now()-make_interval(mins=>$3),$4)",[id(order),id(1),ago,expired]);
const count=()=>scalar("SELECT count(*)::int value FROM public.order_status_logs WHERE title='Tài xế từ chối lời mời'");
await refuse(20,45);check(await count()===0,'expired invitation during ban is not a refusal even when cron runs after expiry');
await refuse(21,15);check(await count()===1,'ordinary expired invitation still counts');
await refuse(21,15);check(await count()===1,'existing same-order deduplication preserved');
await refuse(22,75,false);check(await count()===2,'valid manual refusal before ban still counts');
await db.query("INSERT INTO public.account_control_events(user_id,action,created_at,disabled_until) VALUES($1,'disable',now()-interval '20 minutes',NULL),($1,'release',now()-interval '10 minutes',NULL)",[id(1)]);
check(await at(15),'permanent ban recognized before later Admin release');
check(!(await at(5)),'Admin release ends historical interval');
await refuse(23,15);check(await count()===2,'late cron after Admin release does not penalize the disabled interval');
await refuse(24,-1);check(await count()===2,'existing future-event guard preserved');
check(await scalar('SELECT acceptance_locked_until value FROM public.drivers WHERE user_id=$1',[id(1)])===null,'guards never set an acceptance lock');
for(const role of ['anon','authenticated']){
 check(!(await scalar(`SELECT has_function_privilege($1,'private.driver_account_access_gate(uuid)','EXECUTE') value`,[role])),'private native-state lock not exposed to client role');
 check(!(await scalar(`SELECT has_function_privilege($1,'private.account_disabled_at(uuid,timestamptz)','EXECUTE') value`,[role])),'private history helper not exposed to client role');
}
await db.query("UPDATE public.users SET role='customer' WHERE id=$1",[id(2)]);
check(!(await scalar('SELECT private.driver_account_access_gate($1) value',[id(2)])),'wrong-role account cannot pass driver gate');
console.log(`${checks} account/dispatch guard checks passed in isolated PostgreSQL/PGlite.`);
await db.close();

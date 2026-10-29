// Isolated PostgreSQL regression; never connects to runtime Supabase.
// node tool/account_controls_test.mjs <path-to-pglite>/dist/index.js
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
process.on('uncaughtException',e=>{console.error(e.code??'TEST_FAILURE',e.message,e.where??'');process.exit(1);});
const {PGlite}=await import(pathToFileURL(resolve(process.argv[2])).href);
const db=new PGlite();
const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
let checks=0;
const check=(v,m)=>{assert.ok(v,m);checks++;};
const fails=async(p,code)=>{await assert.rejects(p,e=>e.code===code);checks++;};
await db.exec(`CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE authenticator;
CREATE SCHEMA auth;CREATE SCHEMA private;CREATE SCHEMA storage;
GRANT USAGE ON SCHEMA private,auth,storage TO authenticated;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT NULLIF(current_setting('request.jwt.claims',true),'')::jsonb $$;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT (auth.jwt()->>'sub')::uuid $$;
CREATE TABLE auth.users(id uuid PRIMARY KEY,banned_until timestamptz);
CREATE TABLE auth.sessions(id uuid PRIMARY KEY,user_id uuid REFERENCES auth.users);
CREATE TABLE public.users(id uuid PRIMARY KEY,role text,full_name text,email text,phone text,
 created_at timestamptz,active_session_id uuid,active_session_updated_at timestamptz);
CREATE TABLE public.orders(id uuid,customer_id uuid,driver_id uuid,status text);
CREATE TABLE public.risk_reports(id uuid PRIMARY KEY,order_id uuid,reported_by uuid);
CREATE TABLE public.support_tickets(id uuid PRIMARY KEY,order_id uuid,requester_id uuid);
CREATE TABLE storage.objects(id uuid);
`);
for(const name of ['order_items','order_status_logs','order_messages','order_message_reads','risk_report_events',
 'risk_report_evidence','risk_report_interventions','order_returns','case_messages','reviews','notifications','drivers',
 'driver_profile_change_requests','order_delivery_proofs','customer_wallet_transactions','driver_wallet_transactions',
 'order_payment_sessions','saved_addresses','recent_addresses'])await db.exec(`CREATE TABLE public.${name}(id uuid)`);
for(const [n,role] of [[1,'support'],[2,'admin'],[3,'customer'],[4,'driver'],[5,'customer'],[6,'support']]){
 await db.query('INSERT INTO auth.users VALUES($1,NULL)',[id(n)]);
 await db.query(`INSERT INTO public.users VALUES($1,$2,$3,$4,'0900000000','2026-10-21T00:00:00Z',$5,now())`,[id(n),role,'Người '+n,'user'+n+'@example.invalid',id(100+n)]);
 await db.query('INSERT INTO auth.sessions VALUES($1,$2)',[id(100+n),id(n)]);
}
await db.query("INSERT INTO public.orders VALUES($1,$2,$3,'delivering')",[id(20),id(3),id(4)]);
await db.query('INSERT INTO public.risk_reports VALUES($1,$2,$3)',[id(21),id(20),id(3)]);
await db.query('INSERT INTO public.support_tickets VALUES($1,$2,$3)',[id(22),id(20),id(3)]);
await db.exec(await readFile('docs/proposals/account_controls.sql','utf8'));
await db.exec(`ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
 CREATE POLICY own_order ON public.orders TO authenticated USING(customer_id=auth.uid() OR driver_id=auth.uid());
 GRANT SELECT ON public.orders TO authenticated;
 ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
 CREATE POLICY owned_file ON storage.objects TO authenticated USING(true);
 GRANT SELECT ON storage.objects TO authenticated;
 INSERT INTO storage.objects VALUES(gen_random_uuid());`);
const actor=async n=>db.query(`SELECT set_config('request.jwt.claims',$1,false)`,[JSON.stringify(n?{sub:id(n),role:'authenticated',session_id:id(100+n)}:{role:'anon'})]);
const change=async(user,action,request,minutes=null,expected=null,reason='Lý do vi phạm đã được xác minh',risk=null,ticket=null)=>
 (await db.query('SELECT public.set_account_control($1,$2,$3,$4,$5,$6,$7,$8) data',[id(user),action,reason,id(request),minutes,expected,risk,ticket])).rows[0].data;
const list=async(search='',role=null,disabled=false,offset=0,limit=30)=>(await db.query('SELECT public.list_staff_accounts($1,$2,$3,$4,$5) data',[search,role,disabled,offset,limit])).rows[0].data;
await actor(1);await db.exec('SET ROLE authenticated');
check((await list()).rows.length===3,'Support only sees customer/driver');
check((await list('user3@')).rows.length===1,'literal email search');
await fails(db.query('SELECT * FROM public.account_control_events'),'42501');
await fails(change(2,'disable',900,30),'42501');
await fails(change(1,'disable',901,30),'22023');
await fails(change(3,'disable',902,10),'22023');
await fails(change(3,'disable',903,30,null,'ngắn'),'22023');
await fails(change(5,'disable',904,30,null,undefined,id(21)),'22023');
const first=await change(3,'disable',910,30,null,undefined,id(21),id(22));
check(first.action==='disable'&&!first.already_applied,'Support applies a timed ban');
check((await list('',null,true)).rows.length===1,'disabled account filter');
const retry=await change(3,'disable',910,30,null,undefined,id(21),id(22));
check(retry.already_applied&&retry.event_id===first.event_id,'lost response retry returns original receipt');
await fails(change(3,'disable',910,60,null,undefined,id(21),id(22)),'22023');
await fails(change(3,'disable',911,30,first.event_id),'23514');
await fails(change(3,'release',912,null,first.event_id),'42501');
await fails(change(3,'adjust',913,60,first.event_id),'42501');
await actor(3);
await fails(db.query('SELECT public.require_enabled_account()'),'42501');
check((await db.query('SELECT * FROM public.orders')).rows.length===0,'RLS rejects pre-ban JWT');
check((await db.query('SELECT * FROM storage.objects')).rows.length===0,'legacy media access blocked');
await fails(list(),'42501');
await fails(change(5,'disable',914,30),'42501');
await db.exec('RESET ROLE');
check((await db.query('SELECT count(*)::int n FROM auth.sessions WHERE user_id=$1',[id(3)])).rows[0].n===0,'all login sessions revoked');
check((await db.query('SELECT active_session_id FROM public.users WHERE id=$1',[id(3)])).rows[0].active_session_id===null,'existing logout signal cleared');
await actor(2);await db.exec('SET ROLE authenticated');
check((await list()).rows.length===6,'Admin directory includes staff read-only');
await fails(change(3,'adjust',920,60),'40001');
const adjusted=await change(3,'adjust',921,60,first.event_id);
check(adjusted.event_id!==first.event_id,'Admin adjustment creates a new audit event');
const released=await change(3,'release',922,null,adjusted.event_id);
check(released.action==='release','Admin releases ban');
const history=(await db.query('SELECT public.account_control_history($1) data',[id(3)])).rows[0].data;
check(history.rows.length===3&&history.rows[0].action==='release','history preserves all prior decisions');
const page=(await db.query('SELECT public.account_control_history($1,NULL,1) data',[id(3)])).rows[0].data;
check(page.has_more&&page.rows.length===1,'bounded audit history');
await actor(3);
await fails(db.query('SELECT public.require_enabled_account()'),'42501');
check((await db.query('SELECT * FROM public.orders')).rows.length===0,'released ban does not restore revoked token');
await db.exec('RESET ROLE');
await db.query('INSERT INTO auth.sessions VALUES($1,$2)',[id(103),id(3)]);
await db.exec('SET ROLE authenticated');
await db.query('SELECT public.require_enabled_account()');checks++;
check((await db.query('SELECT * FROM public.orders')).rows.length===1,'fresh login works after release');
await actor(1);
const permanent=await change(4,'disable',930);
check(permanent.disabled_until===null,'permanent ban has no business expiry');
await db.exec('RESET ROLE');
check((await db.query('SELECT banned_until>now() banned FROM auth.users WHERE id=$1',[id(4)])).rows[0].banned,'native Auth blocks permanent ban');
await fails(db.query("UPDATE public.account_control_events SET reason='Thay đổi lịch sử cũ'"),'42501');
await fails(db.query('DELETE FROM public.account_control_events'),'42501');
check((await db.query('SELECT count(*)::int n FROM public.orders')).rows[0].n===1,'orders are not cancelled or reassigned');
check((await db.query("SELECT count(*)::int n FROM pg_policies WHERE policyname IN('account_enabled_required','account_enabled_storage_required','account_enabled_write_required')")).rows[0].n===24,'all declared RLS guards installed');
for(const signature of ['public.set_account_control(uuid,text,text,uuid,integer,uuid,uuid,uuid)',
 'public.list_staff_accounts(text,text,boolean,integer,integer)','public.account_control_history(uuid,bigint,integer)','public.disabled_account_count()']){
 check(!(await db.query("SELECT has_function_privilege('anon',$1,'EXECUTE') allowed",[signature])).rows[0].allowed,'anon denied');
}
console.log(`${checks} account control/security checks passed in isolated PostgreSQL/PGlite.`);
await db.close();

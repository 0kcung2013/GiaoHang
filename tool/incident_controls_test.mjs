// Isolated PostgreSQL checks for the proposed incident workflow, not production.
// node tool/incident_controls_test.mjs <path-to-pglite>/dist/index.js
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
process.on('uncaughtException',e=>{console.error(e.code??'TEST_FAILURE',e.message,e.where??'');process.exit(1);});
const {PGlite}=await import(pathToFileURL(resolve(process.argv[2])).href);
const db=new PGlite();const id=n=>`00000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
let checks=0;const check=(v,m)=>{assert.ok(v,m);checks++;};
const fails=async(p,code)=>{await assert.rejects(p,e=>e.code===code);checks++;};
await db.exec(`CREATE SCHEMA auth;CREATE SCHEMA private;
CREATE TYPE public.user_role AS ENUM('customer','driver','support','admin');
CREATE TYPE public.order_status AS ENUM('pending','confirmed','assigned','picking_up','delivering','delivered','cancelled','risk_hold','return_approved','returning','returned');
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT NULLIF(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
CREATE TABLE public.users(id uuid PRIMARY KEY,role public.user_role);
CREATE TABLE public.orders(id uuid PRIMARY KEY,customer_id uuid,driver_id uuid,status public.order_status,
 actual_picked_up_at timestamptz,actual_delivered_at timestamptz,pickup_arrived_at timestamptz,
 risk_hold_report_id uuid,status_note text,cancelled_at timestamptz,updated_at timestamptz);
CREATE TABLE public.risk_reports(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),order_id uuid,reported_by uuid,
 assigned_to uuid,updated_by uuid,source text DEFAULT 'manual',scope text,component text,category text,
 severity text,status text,title text,description text,resolution text,reporter_role_snapshot text,
 first_response_at timestamptz,triage_due_at timestamptz,response_due_at timestamptz,
 created_at timestamptz DEFAULT now(),updated_at timestamptz DEFAULT now(),resolved_at timestamptz);
CREATE TABLE public.order_returns(id uuid PRIMARY KEY,order_id uuid,risk_report_id uuid,driver_id uuid,
 status text,returned_at timestamptz,proof_storage_path text);
CREATE TABLE public.risk_report_interventions(risk_report_id uuid PRIMARY KEY,order_id uuid,driver_id uuid,
 state text,instruction text,updated_at timestamptz);
CREATE TABLE public.support_tickets(id uuid PRIMARY KEY,order_id uuid,requester_id uuid,assigned_to uuid,
 risk_report_id uuid,status text,subject text,resolution text,created_at timestamptz,updated_at timestamptz);
CREATE TABLE public.risk_report_events(id uuid DEFAULT gen_random_uuid(),risk_report_id uuid,actor_id uuid,
 event_type text,from_status text,to_status text,details jsonb);
CREATE TABLE notifications(user_id uuid);
CREATE TABLE public.case_messages(ticket_id uuid,sender_id uuid,sender_role_snapshot text,visibility text,body text);
CREATE FUNCTION private.require_risk_staff() RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN IF NOT EXISTS(SELECT 1 FROM public.users WHERE id=auth.uid() AND role IN('support','admin')) THEN
 RAISE EXCEPTION 'STAFF_REQUIRED' USING ERRCODE='42501';END IF;RETURN auth.uid();END;$$;
CREATE FUNCTION private.enqueue_linked_case_notification(p_user_id uuid,p_title text,p_body text,p_type text,
 p_order_id uuid,p_ticket_id uuid DEFAULT NULL,p_risk_id uuid DEFAULT NULL) RETURNS void LANGUAGE plpgsql AS $$
 BEGIN INSERT INTO public.notifications VALUES(p_user_id);END;$$;
`);
for(const[n,role]of[[1,'support'],[2,'admin'],[3,'customer'],[4,'driver'],[5,'support']])await db.query('INSERT INTO users VALUES($1,$2)',[id(n),role]);
await db.query("INSERT INTO orders VALUES($1,$2,$3,'returning',now(),NULL,NULL,NULL,NULL,NULL,now())",[id(10),id(3),id(4)]);
for(const n of [20,21,22,23])await db.query(`INSERT INTO risk_reports(id,order_id,reported_by,assigned_to,
 category,severity,status,reporter_role_snapshot) VALUES($1,$2,$3,$4,'contact_issue','critical','investigating','driver')`,[id(n),id(10),id(4),id(1)]);
await db.exec(await readFile('docs/proposals/incident_controls_simplification.sql','utf8'));
await db.exec(`CREATE TRIGGER validate_report BEFORE INSERT OR UPDATE ON public.risk_reports
 FOR EACH ROW EXECUTE FUNCTION private.validate_risk_report_write();`);
const actor=async n=>db.query("SELECT set_config('request.jwt.claim.sub',$1,false)",[id(n)]);
await actor(1);
await db.query("UPDATE risk_reports SET status='resolved',resolution='Đã xác minh và xử lý' WHERE id=$1",[id(20)]);checks++;
check((await db.query('SELECT severity,status FROM risk_reports WHERE id=$1',[id(20)])).rows[0].severity==='critical','historic severity remains readable without controlling decisions');
await fails(db.query("UPDATE risk_reports SET status='resolved' WHERE id=$1",[id(21)]),'23514');
await actor(5);
await fails(db.query("UPDATE risk_reports SET status='resolved',resolution='Không được xử lý thay' WHERE id=$1",[id(21)]),'42501');
await actor(3);
await fails(db.query("UPDATE risk_reports SET status='resolved',resolution='Khách tự sửa trạng thái' WHERE id=$1",[id(21)]),'42501');
await actor(1);
await db.query("INSERT INTO risk_report_interventions VALUES($1,$2,$3,'return_required',NULL,now())",[id(22),id(10),id(4)]);
await fails(db.query("UPDATE risk_reports SET status='resolved',resolution='Vẫn còn hàng phải xử lý' WHERE id=$1",[id(22)]),'23514');
await db.query("SELECT public.transition_risk_report($1,'waiting_admin',NULL)",[id(21)]);
check((await db.query('SELECT status FROM risk_reports WHERE id=$1',[id(21)])).rows[0].status==='investigating','legacy escalation request stays with Support');
check((await db.query('SELECT count(*)::int n FROM notifications WHERE user_id=$1',[id(2)])).rows[0].n===0,'no Admin escalation notification');
const created=(await db.query(`INSERT INTO risk_reports(order_id,category,severity,status,source,title)
 VALUES($1,'contact_issue','critical','open','manual','Sự cố mới') RETURNING severity,reported_by`,[id(10)])).rows[0];
check(created.severity==='medium'&&created.reported_by===id(1),'new incidents keep neutral legacy value');
await db.query("INSERT INTO support_tickets VALUES($1,NULL,$2,$3,NULL,'in_progress','Yêu cầu chung',NULL,now(),now())",[id(30),id(3),id(1)]);
const converted=(await db.query(`SELECT(public.convert_support_ticket_to_risk($1,'system','critical',
 'Sự cố đăng nhập','Nội dung xác minh đủ thông tin','Đăng nhập')).*`,[id(30)])).rows[0];
check(converted.severity==='medium','conversion ignores the old severity argument');
check((await db.query('SELECT status FROM support_tickets WHERE id=$1',[id(30)])).rows[0].status==='in_progress','converted ticket does not wait for Admin');
await db.query("SELECT public.transition_support_ticket($1,'waiting_admin',NULL)",[id(30)]);
check((await db.query('SELECT status FROM support_tickets WHERE id=$1',[id(30)])).rows[0].status==='in_progress','legacy ticket escalation stays with Support');
// Removing tiers must retain every other custody/participant prerequisite.
await db.exec('DROP TRIGGER validate_report ON public.risk_reports');
await db.query("UPDATE risk_reports SET status='action_required' WHERE id=$1",[id(22)]);
await db.query("INSERT INTO order_returns VALUES($1,$2,$3,$4,'returning',NULL,NULL)",[id(40),id(10),id(22),id(4)]);
check((await db.query('SELECT private.can_driver_cancel_order_return($1,$2) allowed',[id(10),id(4)])).rows[0].allowed,'cancellation eligibility is independent of legacy tier');
check(!(await db.query('SELECT private.can_driver_cancel_order_return($1,$2) allowed',[id(10),id(3)])).rows[0].allowed,'wrong participant remains blocked');
await db.query("UPDATE risk_reports SET category='cargo_issue' WHERE id=$1",[id(22)]);
check(!(await db.query('SELECT private.can_driver_cancel_order_return($1,$2) allowed',[id(10),id(4)])).rows[0].allowed,'other incident categories remain blocked');
console.log(`${checks} incident simplification checks passed in isolated PostgreSQL/PGlite.`);
await db.close();

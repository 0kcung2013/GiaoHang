// Isolated PostgreSQL tests; does not connect to the runtime project.
// Usage: node tool/admin_read_access_test.mjs <path-to-pglite>/dist/index.js
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

process.on('uncaughtException', error => {
  console.error(error.code ?? 'TEST_FAILURE', error.message, error.where ?? '');
  process.exit(1);
});

const { PGlite } = await import(pathToFileURL(resolve(process.argv[2])).href);
const db = new PGlite();
const uid = n => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
await db.exec(`
CREATE ROLE anon; CREATE ROLE authenticated;
CREATE SCHEMA auth; CREATE SCHEMA private;
GRANT USAGE ON SCHEMA auth,private TO authenticated;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT (nullif(current_setting('request.jwt.claims',true),'')::jsonb->>'sub')::uuid
$$;
CREATE TABLE public.users(id uuid PRIMARY KEY,full_name text,email text,phone text,
 role text,created_at timestamptz,avatar_url text);
CREATE TABLE public.orders(id uuid,tracking_code text,status text,total_price numeric,
 pickup_address text,delivery_address text,note text,created_at timestamptz,
 customer_id uuid,driver_id uuid);
CREATE TABLE public.drivers(id uuid,user_id uuid,vehicle_type text,license_plate text,
 vehicle_brand_model text,vehicle_color text,is_available boolean,current_lat double precision,
 current_lng double precision,updated_at timestamptz,rating numeric,total_deliveries integer,
 approval_status text,verified_at timestamptz,rejection_reason text,submitted_at timestamptz,
 id_card_number text,id_card_front_url text,id_card_back_url text,driver_license_number text,
 driver_license_url text,vehicle_photo_url text);
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY own_profile ON public.users TO authenticated USING(id=auth.uid());
GRANT SELECT ON public.users TO authenticated;
`);
for (const [id, role, name, email] of [
  [1, 'admin', 'Admin', 'admin@example.invalid'],
  [2, 'support', 'Support', 'support@example.invalid'],
  [3, 'customer', 'Khách %_', 'an_%@example.invalid'],
  [4, 'driver', 'Nguyễn Minh An', 'an@example.invalid'],
  [5, 'customer', 'Khách khác', 'khac@example.invalid'],
]) {
  await db.query('INSERT INTO public.users VALUES($1,$2,$3,$4,$5,$6,NULL)',
    [uid(id), name, email, '0901234567', role, '2026-10-21T00:00:00Z']);
}
await db.query(`INSERT INTO public.orders(id,tracking_code,status,total_price,created_at,customer_id,driver_id)
 VALUES($1,'GH-1','delivered',50000,'2026-10-21T00:00:00Z',$2,$3)`, [uid(10), uid(3), uid(4)]);
await db.query(`INSERT INTO public.drivers(id,user_id,approval_status,is_available,updated_at,rating,total_deliveries)
 VALUES($1,$2,'approved',true,'2026-10-21T00:00:00Z',4.5,1)`, [uid(20), uid(4)]);
await db.exec(await readFile('docs/proposals/admin_read_access.sql', 'utf8'));

let checks = 0;
const check = (ok, message) => { assert.ok(ok, message); checks++; };
const actor = async n => db.query(`SELECT set_config('request.jwt.claims',$1,false)`,
  [JSON.stringify(n ? { sub: uid(n), role: 'authenticated' } : { role: 'anon' })]);
const accounts = async (search = '', role = null, offset = 0, limit = 51) =>
  (await db.query('SELECT * FROM public.list_admin_accounts($1,$2,$3,$4)', [search, role, offset, limit])).rows;
const signatures = [
  'public.admin_dashboard_stats()', 'public.admin_list_orders(text)',
  'public.admin_list_drivers(text)', 'public.list_admin_accounts(text,text,integer,integer)',
  'private.list_admin_accounts(text,text,integer,integer)',
];
for (const signature of signatures) {
  check(!(await db.query(`SELECT has_function_privilege('anon',$1,'EXECUTE') AS allowed`, [signature])).rows[0].allowed,
    `anon blocked: ${signature}`);
}
await db.exec('SET ROLE anon');
await actor(null);
await assert.rejects(db.query('SELECT public.admin_dashboard_stats()'), e => e.code === '42501'); checks++;
await db.exec('RESET ROLE');
await db.exec('SET ROLE authenticated');
for (const n of [null, 2, 3, 4, 999]) {
  await actor(n);
  for (const query of [
    'SELECT public.admin_dashboard_stats()', 'SELECT * FROM public.admin_list_orders(NULL)',
    "SELECT * FROM public.admin_list_drivers('approved')", 'SELECT * FROM public.list_admin_accounts()',
  ]) {
    await assert.rejects(db.query(query), e => e.code === '42501'); checks++;
  }
}
await actor(1);
check((await db.query('SELECT count(*)::int AS n FROM public.users')).rows[0].n === 1,
  'table RLS stays restricted to own profile');
check((await accounts()).length === 5, 'admin directory sees all accounts through RPC');
check((await accounts('', 'customer')).length === 2, 'role filter');
check((await accounts('an_%@example.invalid')).length === 1, 'email search treats wildcard characters literally');
check((await accounts('0901234567')).length === 5, 'phone search');
check((await accounts('minh an')).length === 1, 'name search is case insensitive');
check((await accounts('missing')).length === 0, 'empty result');
const pages = [];
for (let offset = 0; offset < 5; offset += 2) pages.push(...await accounts('', null, offset, 2));
check(pages.length === 5 && new Set(pages.map(r => r.id)).size === 5, 'stable pagination on tied timestamps');
check(Object.keys(pages[0]).sort().join(',') === 'created_at,email,full_name,id,phone,role', 'minimal public fields');
for (const args of [['x'.repeat(121)], ['', 'owner'], ['', null, -1], ['', null, 0, 0], ['', null, 0, 101], ['', null, null], ['', null, 0, null]]) {
  await assert.rejects(accounts(...args), e => e.code === '22023'); checks++;
}
const stats = (await db.query('SELECT public.admin_dashboard_stats() AS data')).rows[0].data;
check(stats.total_drivers === 1 && stats.total_customers === 2 && stats.total_orders === 1, 'admin dashboard retains totals');
check((await db.query("SELECT * FROM public.admin_list_drivers('approved')")).rows.length === 1, 'admin driver list retained');
check((await db.query('SELECT * FROM public.admin_list_orders(NULL)')).rows.length === 1, 'admin order list retained');
await db.exec('RESET ROLE');
check((await db.query('SELECT count(*)::int AS n FROM public.users')).rows[0].n === 5, 'no account writes');
console.log(`${checks} admin read API/security checks passed in isolated PostgreSQL/PGlite.`);
await db.close();

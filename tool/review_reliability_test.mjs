// PostgreSQL regression in an isolated, disposable PGlite database.
// Run from repo root; first argument is a locally installed PGlite module path.
// No credentials, network calls, production data, or application dependency.
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';

if (!process.argv[2]) throw new Error('Pass the path to @electric-sql/pglite/dist/index.js');
const { PGlite } = await import(pathToFileURL(resolve(process.argv[2])).href);
const db = new PGlite();
const id = n => `00000000-0000-0000-0000-${String(n).padStart(12, '0')}`;
const proposal = await readFile(process.argv[3] || 'docs/proposals/review_reliability.sql', 'utf8');
let checks = 0;
const equal = (a, b, message) => { assert.deepEqual(a, b, message); checks++; };
const fails = async (operation, code) => {
  await assert.rejects(operation, error => error.code === code);
  checks++;
};
const actor = userId => db.query("select set_config('request.jwt.claim.sub', $1, false)", [userId ?? '']);
const submit = async (direction, order, rating, comment = null, tags = []) => {
  const fn = direction === 'customer_to_driver' ? 'submit_customer_driver_review' : 'submit_driver_customer_review';
  return (await db.query(`select public.${fn}($1,$2,$3,$4) receipt`, [id(order), rating, comment, tags])).rows[0].receipt;
};
try {
  await db.exec(`
    CREATE ROLE anon; CREATE ROLE authenticated; CREATE SCHEMA auth;
    GRANT USAGE ON SCHEMA auth TO authenticated;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
      SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
    $$;
    CREATE TYPE public.order_status AS ENUM ('pending', 'delivered');
    CREATE TABLE public.users(id uuid PRIMARY KEY, role text, customer_rating numeric, customer_rating_count int DEFAULT 0);
    CREATE TABLE public.drivers(id uuid PRIMARY KEY, user_id uuid, rating numeric, rating_count int DEFAULT 0, updated_at timestamptz);
    CREATE TABLE public.orders(id uuid PRIMARY KEY, customer_id uuid, driver_id uuid, status order_status);
    CREATE TABLE public.reviews(id uuid PRIMARY KEY DEFAULT gen_random_uuid(), order_id uuid,
      reviewer_id uuid, driver_id uuid, rating int CHECK(rating BETWEEN 1 AND 5), comment text, tags text[] DEFAULT '{}',
      created_at timestamptz DEFAULT now(), CONSTRAINT reviews_order_unique UNIQUE(order_id));
  `);
  await db.query('insert into users(id,role) values($1,$2),($3,$4),($5,$6),($7,$8)',
    [id(1), 'customer', id(2), 'driver', id(3), 'customer', id(4), 'admin']);
  await db.query('insert into drivers(id,user_id) values($1,$2)', [id(20), id(2)]);
  for (let n = 100; n < 107; n++) {
    await db.query("insert into orders values($1,$2,$3,'delivered')", [id(n), id(1), id(2)]);
  }
  await db.exec(await readFile('supabase/migrations/202607220006_driver_customer_reviews.sql', 'utf8'));
  await db.exec(proposal);
  for (const fn of ['submit_customer_driver_review', 'submit_driver_customer_review']) {
    const signature = `public.${fn}(uuid,integer,text,text[])`;
    const row = (await db.query(`select has_function_privilege('anon',$1,'execute') anon,
      has_function_privilege('authenticated',$1,'execute') authenticated`, [signature])).rows[0];
    equal(row, { anon: false, authenticated: true }, `${fn} execution privileges`);
    equal((await db.query(`select prosecdef from pg_proc where oid=$1::regprocedure`, [signature])).rows[0].prosecdef, true);
  }
  await actor(null);
  await fails(submit('customer_to_driver', 100, 5), '42501');
  await actor(id(4));
  await fails(submit('customer_to_driver', 100, 5), '42501');
  await actor(id(3));
  await fails(submit('customer_to_driver', 100, 5), '42501');
  await actor(id(1));
  await fails(submit('driver_to_customer', 100, 5), '42501');
  for (const rating of [null, 0, 6]) await fails(submit('customer_to_driver', 100, rating), '22023');
  await fails(submit('customer_to_driver', 100, 5, 'x'.repeat(501)), '22023');
  await fails(submit('customer_to_driver', 100, 5, null, ['unknown']), '22023');
  await fails(submit('customer_to_driver', 100, 5, null, [null]), '22023');
  await fails(submit('customer_to_driver', 100, 5, null, Array(33).fill('on_time')), '22023');
  await fails(submit('customer_to_driver', 999, 5), '42501');
  await db.query("update orders set status='pending' where id=$1", [id(104)]);
  await fails(submit('customer_to_driver', 104, 5), '22023');
  await db.query('update orders set driver_id=null where id=$1', [id(105)]);
  await fails(submit('customer_to_driver', 105, 5), '22023');
  for (const [index, score] of [1, 1, 2, 1].entries()) await submit('customer_to_driver', 100 + index, score);
  let aggregate = (await db.query('select rating,rating_count from drivers')).rows[0];
  equal([Number(aggregate.rating), aggregate.rating_count], [1.3, 4], 'Exact driver average, avoiding rounded-average drift');
  const repeated = await submit('customer_to_driver', 100, 5, 'Must not replace first review');
  equal([repeated.already_reviewed, repeated.rating, repeated.driver_rating_count], [true, 1, 4]);
  equal((await db.query('select count(*)::int n from reviews')).rows[0].n, 4);
  // Historical aggregates are reconciled when the proposal is applied again.
  await db.exec('update drivers set rating=1.2,rating_count=99');
  await db.exec(proposal);
  aggregate = (await db.query('select rating,rating_count from drivers')).rows[0];
  equal([Number(aggregate.rating), aggregate.rating_count], [1.3, 4]);
  await submit('customer_to_driver', 106, 5, '  Cảm ơn  ', ['friendly', 'on_time', 'friendly']);
  const normalized = (await db.query('select comment,tags from reviews where order_id=$1', [id(106)])).rows[0];
  equal(normalized, { comment: 'Cảm ơn', tags: ['friendly', 'on_time'] });

  await actor(id(2));
  await fails(submit('customer_to_driver', 100, 5), '42501');
  await fails(submit('driver_to_customer', 100, 5, null, ['bad_attitude']), '22023');
  await fails(submit('driver_to_customer', 104, 5), '22023');
  for (const [index, score] of [1, 1, 2, 1].entries()) await submit('driver_to_customer', 100 + index, score);
  const repeatedCustomer = await submit('driver_to_customer', 100, 5);
  equal([repeatedCustomer.already_reviewed, repeatedCustomer.rating, repeatedCustomer.customer_rating_count], [true, 1, 4]);
  const customer = (await db.query('select customer_rating,customer_rating_count from users where id=$1', [id(1)])).rows[0];
  equal([Number(customer.customer_rating), customer.customer_rating_count], [1.3, 4]);
  await db.query('update users set customer_rating=1.2,customer_rating_count=99 where id=$1', [id(1)]);
  await db.exec(proposal);
  const repaired = (await db.query('select customer_rating,customer_rating_count from users where id=$1', [id(1)])).rows[0];
  equal([Number(repaired.customer_rating), repaired.customer_rating_count], [1.3, 4]);
  equal((await db.query("select count(*)::int n from reviews where order_id=$1", [id(100)])).rows[0].n, 2, 'Two independent review directions');
  console.log(`Passed ${checks} review SQL checks in isolated PostgreSQL.`);
} finally {
  await db.close();
}

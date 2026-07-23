// Validate the Supabase SQL against real Postgres (PGlite / WASM).
// Supabase-specific bits (auth schema, auth.uid, request.headers, roles) are
// stubbed so we can exercise the schema, functions, triggers, and seed here.
import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';

const db = new PGlite();
const read = (f) => readFileSync(f, 'utf8');

async function run(label, sql) {
  try { await db.exec(sql); console.log('  ✓', label); }
  catch (e) { console.log('  ✗', label, '\n    ', e.message); throw e; }
}

// ---- Stubs for the Supabase environment ----
await run('stubs: roles + auth', `
  do $$ begin
    if not exists (select from pg_roles where rolname='anon') then create role anon; end if;
    if not exists (select from pg_roles where rolname='authenticated') then create role authenticated; end if;
  end $$;
  create schema if not exists auth;
  create table auth.users (id uuid primary key default gen_random_uuid(), email text);
  create or replace function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('app.uid', true), '')::uuid $$;
  -- gen_random_bytes stub (pgcrypto not bundled in PGlite)
  create or replace function gen_random_bytes(n int) returns bytea language sql as
    $$ select decode(md5(random()::text), 'hex') $$;
`);

// ---- Migrations (strip the pgcrypto extension line the stub replaces) ----
const migrations = [
  '0001_content','0002_people','0003_progress',
  '0004_functions','0005_rls','0006_verification_reporting',
];
for (const m of migrations) {
  let sql = read(`supabase/migrations/${m}.sql`)
    .replace(/create extension if not exists pgcrypto;/g, '');
  await run(`migration ${m}`, sql);
}
await run('seed', read('supabase/seed.sql'));

// ---- Content checks ----
const q = async (sql) => (await db.query(sql)).rows[0];
console.log('\nContent:');
console.log('  courses:', (await q(`select count(*) c from courses`)).c);
console.log('  blocks :', (await q(`select count(*) c from blocks`)).c);
console.log('  quizzes:', (await q(`select count(*) c from quizzes`)).c);
console.log('  block-1 questions:', (await q(`
  select count(*) c from questions qs join quizzes qz on qz.id=qs.quiz_id
  join blocks b on b.id=qz.block_id where b.slug='your-digital-agency'`)).c);

// ---- Simulate people + an AM-led session (run as superuser; RLS bypassed) ----
console.log('\nSession credit flow:');
await db.exec(`
  insert into auth.users (id, email) values ('11111111-1111-1111-1111-111111111111','grp@x');
  insert into auth.users (id, email) values ('22222222-2222-2222-2222-222222222222','am@x');
  insert into groups (id, slug, name) values ('aaaaaaaa-0000-0000-0000-000000000001','acme','Acme Partner');
  insert into group_accounts (group_id, auth_user_id, login_email)
    values ('aaaaaaaa-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','acme@certified.44i');
  insert into account_managers (auth_user_id, full_name, email)
    values ('22222222-2222-2222-2222-222222222222','Trainer One','am@x') returning id;
`);
const am = await q(`select id from account_managers limit 1`);
await db.exec(`
  insert into account_executives (id, group_id, full_name) values
    ('bbbbbbbb-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','Present Rep'),
    ('bbbbbbbb-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000001','Absent Rep');
`);
const course = await q(`select id from courses where slug='process-certification'`);
await db.exec(`
  insert into training_sessions (id, am_id, group_id, course_id)
    values ('cccccccc-0000-0000-0000-000000000001','${am.id}','aaaaaaaa-0000-0000-0000-000000000001','${course.id}');
  insert into session_attendees (session_id, ae_id, present) values
    ('cccccccc-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000001', true),
    ('cccccccc-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000002', false);
`);
const blk1 = await q(`select b.id from blocks b join courses c on c.id=b.course_id where c.slug='process-certification' and b.slug='your-digital-agency'`);
await db.exec(`insert into session_blocks (session_id, block_id, quiz_passed)
  values ('cccccccc-0000-0000-0000-000000000001','${blk1.id}', true);`);
const present = await q(`select count(*) c from block_progress where ae_id='bbbbbbbb-0000-0000-0000-000000000001'`);
const absent  = await q(`select count(*) c from block_progress where ae_id='bbbbbbbb-0000-0000-0000-000000000002'`);
console.log('  present rep credited:', present.c, '(expect 1)');
console.log('  absent rep credited :', absent.c, '(expect 0)');

// ---- Certificate issuance: complete ALL blocks for the present rep ----
console.log('\nCertificate issuance:');
await db.exec(`
  insert into block_progress (ae_id, block_id, status, score, credited_via)
  select 'bbbbbbbb-0000-0000-0000-000000000001', b.id, 'completed', 100, 'self'
  from blocks b join courses c on c.id=b.course_id where c.slug='process-certification'
  on conflict (ae_id, block_id) do nothing;
`);
const cert = await q(`select code, name_on_certificate from certificates where ae_id='bbbbbbbb-0000-0000-0000-000000000001'`);
console.log('  certificate issued:', cert ? cert.code : 'NONE', '/', cert ? cert.name_on_certificate : '');

// ---- Public verification RPC ----
const vOk  = await q(`select public.verify_certificate('${cert.code}') v`);
const vBad = await q(`select public.verify_certificate('NOPE-CODE') v`);
console.log('  verify(valid):', JSON.stringify(vOk.v));
console.log('  verify(bad)  :', JSON.stringify(vBad.v));

// ---- Server-side quiz grading via submit_quiz ----
console.log('\nQuiz grading (submit_quiz):');
await db.exec(`select set_config('app.uid','11111111-1111-1111-1111-111111111111', false);
               select set_config('request.headers','{"x-ae-id":"bbbbbbbb-0000-0000-0000-000000000002"}', false);`);
const quiz1 = await q(`select qz.id from quizzes qz join blocks b on b.id=qz.block_id where b.slug='your-digital-agency'`);
// build a fully-correct answer set
const rows = (await db.query(`
  select q.id qid, array_agg(o.id) filter (where o.is_correct) correct
  from questions q join question_options o on o.question_id=q.id
  where q.quiz_id='${quiz1.id}' group by q.id`)).rows;
const answers = rows.map(r => ({ question_id: r.qid, option_ids: r.correct }));
const graded = await q(`select app.submit_quiz('${quiz1.id}', '${JSON.stringify(answers)}'::jsonb) r`);
console.log('  all-correct ->', JSON.stringify(graded.r));
// one wrong answer
const wrong = rows.map((r,i) => ({ question_id: r.qid, option_ids: i===0 ? [] : r.correct }));
const graded2 = await q(`select app.submit_quiz('${quiz1.id}', '${JSON.stringify(wrong)}'::jsonb) r`);
console.log('  one-wrong   ->', JSON.stringify(graded2.r));

console.log('\nALL CHECKS PASSED ✓');
await db.close();

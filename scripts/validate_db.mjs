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
    if not exists (select from pg_roles where rolname='service_role') then create role service_role; end if;
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
  '0007_playbook_link','0008_course_badges',
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

// ---- The link to Fourge Playbook: the roster in, the certificates out ----
console.log('\nPlaybook link:');
const same = (label, got, want) => {
  // jsonb hands its keys back sorted, so both sides are compared with their keys in one order.
  const canon = (v) => JSON.stringify(v, (_, x) => (x && typeof x === 'object' && !Array.isArray(x) ? Object.fromEntries(Object.entries(x).sort(([k1], [k2]) => (k1 < k2 ? -1 : 1))) : x));
  const ok = canon(got) === canon(want);
  console.log(ok ? '  ✓' : '  ✗', label, ok ? '' : `\n     got  ${JSON.stringify(got)}\n     want ${JSON.stringify(want)}`);
  if (!ok) throw new Error(`Playbook link: ${label}`);
};
const roster = {
  groups: [
    { external_ref: 'G1', name: 'acme partner' },          // set up by hand above: linked by name
    { external_ref: 'G2', name: 'Bluff City Media' },      // new
    { external_ref: 'G3', name: 'Bluff City Media!' },     // new, and its slug must not collide
    { external_ref: '', name: 'No Id' },                   // skipped
  ],
  aes: [
    { external_ref: 'A1', group_ref: 'G1', full_name: 'present rep', email: 'P@X.com' },  // linked by name
    { external_ref: 'A2', group_ref: 'G2', full_name: 'New Person', email: null },        // new
    { external_ref: 'A3', group_ref: 'NOPE', full_name: 'Lost Soul', email: null },       // no such group: skipped
  ],
};
const sync = async (r) => (await q(`select public.playbook_roster_sync('${JSON.stringify(r.groups)}'::jsonb, '${JSON.stringify(r.aes)}'::jsonb) r`)).r;
same('first pass files the roster', await sync(roster),
  { groups_new: 2, groups_linked: 1, aes_new: 1, aes_linked: 1, aes_updated: 0, skipped: 2 });
same('a second pass changes nothing', await sync(roster),
  { groups_new: 0, groups_linked: 0, aes_new: 0, aes_linked: 0, aes_updated: 0, skipped: 2 });
same('slugs made from the names, none shared',
  (await db.query(`select slug from groups where external_ref in ('G2','G3') order by external_ref`)).rows.map((r) => r.slug),
  ['bluff-city-media', 'bluff-city-media-2']);
same('the hand-made rows carry their ids now, and the email',
  await q(`select g.external_ref g, ae.external_ref a, ae.email from account_executives ae join groups g on g.id=ae.group_id where ae.id='bbbbbbbb-0000-0000-0000-000000000001'`),
  { g: 'G1', a: 'A1', email: 'p@x.com' });
same('an AE who moves group and changes name is followed',
  await sync({ groups: [], aes: [{ external_ref: 'A2', group_ref: 'G1', full_name: 'New Person-Smith', email: 'n@x.com' }] }),
  { groups_new: 0, groups_linked: 0, aes_new: 0, aes_linked: 0, aes_updated: 1, skipped: 0 });
same('a name another AE of the group holds is not taken',
  [await sync({ groups: [], aes: [{ external_ref: 'A2', group_ref: 'G1', full_name: 'Absent Rep', email: null }] }),
   (await q(`select full_name from account_executives where external_ref='A2'`)).full_name],
  [{ groups_new: 0, groups_linked: 0, aes_new: 0, aes_linked: 0, aes_updated: 0, skipped: 0 }, 'New Person-Smith']);
const certs = (await q(`select public.playbook_certifications() r`)).r;
same('the valid certificate goes out by the AE id, with the badges its course awards (Process: none)',
  certs.map((c) => [c.ae_ref, c.certificates.map((x) => [x.course, x.title, x.order, x.code, x.badges])]),
  [['A1', [['process-certification', 'Process Certification', 1, cert.code, []]]]]);
await db.exec(`update certificates set status='revoked' where code='${cert.code}'`);
same('a revoked certificate does not', (await q(`select public.playbook_certifications() r`)).r, []);
await db.exec(`update certificates set status='valid' where code='${cert.code}'`);
// ---- Which badge a course awards (0008; the pairing settled 2026-11-17) ----
console.log('\nCourse badges:');
await db.exec(`
  insert into courses (id, slug, title, sort_order) values
    ('dddddddd-0000-0000-0000-000000000002','101-products-certification','101 - Products Certification',2),
    ('dddddddd-0000-0000-0000-000000000003','201-products-certification','201 - Products Certification',3),
    ('dddddddd-0000-0000-0000-000000000004','packages-certification','Packages Certification',4);
`);
same('the two Products courses take their badges by name; Process and Packages award none',
  (await db.query(`select slug, badge_keys from courses order by sort_order`)).rows.map((r) => [r.slug, r.badge_keys]),
  [['process-certification', []], ['101-products-certification', ['online-visibility', 'content-marketing']], ['201-products-certification', ['targeted-digital']], ['packages-certification', []]]);
const give = (slug, n) => db.exec(`insert into certificates (ae_id, course_id, name_on_certificate, code)
  select 'bbbbbbbb-0000-0000-0000-000000000001', id, 'Present Rep', 'CODE-${n}' from courses where slug='${slug}'`);
const mine = async () => (await q(`select public.playbook_certifications() r`)).r.find((c) => c.ae_ref === 'A1').certificates.map((x) => [x.course, x.badges]);
await give('101-products-certification', 2);
same('101 Products earns Online Visibility and Content Marketing', await mine(),
  [['process-certification', []], ['101-products-certification', ['online-visibility', 'content-marketing']]]);
await give('201-products-certification', 3);
same('201 Products earns Targeted Digital; three of four courses is not the program', await mine(),
  [['process-certification', []], ['101-products-certification', ['online-visibility', 'content-marketing']], ['201-products-certification', ['targeted-digital']]]);
await give('packages-certification', 4);
const whole = (await q(`select public.playbook_certifications() r`)).r.find((c) => c.ae_ref === 'A1').certificates;
same('every course complete earns Digital Marketing Professional, last, with no code', whole.slice(-1).map((x) => [x.course, x.title, x.order, x.code, x.badges]),
  [['digital-marketing-professional', 'Digital Marketing Professional', 5, null, ['professional']]]);
same('and the four courses stay on the list before it', whole.length, 5);
await db.exec(`update certificates set status='revoked' where code='CODE-3'`);
same('a revoked course takes Professional away again', (await mine()).map((x) => x[0]), ['process-certification', '101-products-certification', 'packages-certification']);
await db.exec(`update certificates set status='valid' where code='CODE-3'`);
await db.exec(`update courses set is_active=false where slug='packages-certification'; delete from certificates where code='CODE-4';`);
same('a course switched off is not asked for', (await mine()).slice(-1)[0][0], 'digital-marketing-professional');
await db.exec(`update courses set is_active=true where slug='packages-certification'`);
same('a new course with a badge named keeps the one named', (await (async () => { await db.exec(`insert into courses (slug, title, sort_order, badge_keys) values ('x-101-products','101 Products Refresher',9,'{targeted-digital}')`); const r = await q(`select badge_keys from courses where slug='x-101-products'`); await db.exec(`delete from courses where slug='x-101-products'`); return r.badge_keys; })()), ['targeted-digital']);
// Leave the program as the rest of this script expects it: Process alone.
await db.exec(`delete from certificates where code like 'CODE-%'; delete from courses where slug <> 'process-certification';`);

same('only the Playbook server may call either',
  (await db.query(`select p.proname, has_function_privilege('anon', p.oid, 'execute') anon, has_function_privilege('authenticated', p.oid, 'execute') authd, has_function_privilege('service_role', p.oid, 'execute') svc
     from pg_proc p where p.proname in ('playbook_roster_sync','playbook_certifications') order by 1`)).rows,
  [{ proname: 'playbook_certifications', anon: false, authd: false, svc: true }, { proname: 'playbook_roster_sync', anon: false, authd: false, svc: true }]);

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

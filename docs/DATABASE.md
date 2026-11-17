# CERTIFIED.44i — Database setup (Supabase)

This is the backend foundation: schema, security, the credit/certificate logic,
and content for **Process Certification** (v1). Everything is data-driven, so
adding the 101/201 Product certifications later is data entry, not code.

## What's here

```
supabase/
  migrations/
    0001_content.sql              courses, blocks, quizzes, questions, options
    0002_people.sql               groups, account_executives, account_managers, group_accounts
    0003_progress.sql             block_progress, certificates, training_sessions, attendees, session_blocks
    0004_functions.sql            identity helpers, quiz grading, session credit, cert issuance
    0005_rls.sql                  row-level security policies
    0006_verification_reporting.sql  public cert verification + reporting views
    0007_playbook_link.sql        the roster in from Fourge Playbook, the certificates out to it
    0008_course_badges.sql        which badge a course awards
  seed.sql                        Process Certification content (9 blocks)
data/
  *.example.csv                   templates for your import
scripts/
  provision.mjs                   imports CSVs + creates Auth users
  validate_db.mjs                 runs the whole schema in local Postgres (WASM) as a smoke test
```

## How the login model works

- **No individual AE logins.** Each **group** is backed by one Supabase Auth
  user (email `‹slug›@groups.certified.44i.com`, password = the group's shared
  password from your unified system). AEs "log in as the group," then pick
  their name from the group roster.
- **Account Managers** (your 3 trainers) each get a real Auth user with
  cross-group powers — they can open any group, run a session, and check off
  who attended.
- Row-level security enforces all of this: a group can only touch its own AEs
  and their progress; AMs see everything; correct quiz answers are never sent
  to the browser (grading happens server-side in `submit_quiz`).

## Setup steps

### 1. Create a Supabase project
At [supabase.com](https://supabase.com). Note your **Project URL**, **anon key**
(safe for the website), and **service_role key** (server-side only — never ship
it in front-end code).

### 2. Apply the migrations + seed
**Option A — SQL Editor (simplest):** paste each file in order
(`0001` → `0006`, then `seed.sql`) and run.

**Option B — Supabase CLI:**
```bash
supabase link --project-ref <ref>
supabase db push          # applies supabase/migrations/*
psql "$DATABASE_URL" -f supabase/seed.sql
```

> `0001_content.sql` runs `create extension pgcrypto` — allowed on Supabase.

### 3. Import your people
Copy the templates and fill them with your real data (keep the headers):
```bash
cp data/groups.example.csv            data/groups.csv
cp data/account_executives.example.csv data/account_executives.csv
cp data/account_managers.example.csv   data/account_managers.csv
```
| File | Columns |
|------|---------|
| `groups.csv` | `slug,name,password,external_ref` |
| `account_executives.csv` | `full_name,group_slug,email,external_ref` |
| `account_managers.csv` | `full_name,email,password` |

`slug` is a short id (lowercase, dashes) used to build the group login email.
`external_ref` is optional — put the id from your unified password system there.

Then run the provisioner (creates the Auth users and inserts the rows):
```bash
npm install
export SUPABASE_URL="https://<ref>.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="<service_role key>"
npm run provision
```

### 4. Verify
- `select * from public.courses;` → Process Certification
- `select title, duration_minutes from public.blocks order by sort_order;` → 9 blocks
- `select public.verify_certificate('BADCODE');` → `{"found": false}`
- Reporting: `select * from public.v_group_summary;`

## The link to Fourge Playbook (migration 0007)

Fourge Playbook builds the proposals an Account Executive presents. It shows a
badge on every proposal by an AE who holds a valid certificate here. For that,
both systems must know an AE by the same id: the order system's.

- **The roster comes in from the Playbook, every hour.** The Playbook mirrors
  the order system (the master for groups and AEs) and calls
  `playbook_roster_sync(groups, aes)`. Each group and AE is filed here with
  `external_ref` = its id in the order system. A group or an AE set up by hand
  before the link is matched by name (an AE: the same name under the same
  group) and given its id. A name or an email that changes in the order system
  changes here; an AE who moves group moves here. **Nothing is ever deleted**,
  so no progress and no certificate is ever lost to a roster change.
- **The certificates go out to the Playbook.** `playbook_certifications()`
  returns every `valid` certificate by the AE's order-system id, in course
  order. A revoked certificate drops off the AE's proposals within the hour.
- **Only the Playbook's server can call either** (`service_role`). No browser,
  no group login and no anonymous caller can.
- **A group filed by the sync has no login yet.** Its slug is made from its
  name; make its login the usual way (`scripts/provision.mjs` with that slug in
  `groups.csv`, which leaves the row and its AEs as they are, or the Auth
  dashboard). Until then its AEs are on the roster and cannot sign in.
- **Two AEs of one group under one name** cannot both be filed (the roster is
  one name a group). The second is skipped and counted, and the Playbook's sync
  reports the count.

### Which badge a course awards (migration 0008)

The Playbook draws the program's badge artwork on a certified AE's proposals.
The pairing, settled on 2026-11-17:

| Course completed | Badge |
|------------------|-------|
| 101 Products | Online Visibility and Content Marketing |
| 201 Products | Targeted Digital |
| Every course | Digital Marketing Professional |
| Process, Packages | none on their own |

- A course names its badges in `courses.badge_keys`, by the Playbook's artwork
  keys: `online-visibility`, `content-marketing`, `targeted-digital`.
- **The two Products courses get theirs on their own when they are created**,
  by their name ("101 … Products", "201 … Products"). Any course can be set by
  hand: `update courses set badge_keys = '{targeted-digital}' where slug = '…';`
- **Professional is not a course.** An AE has it while they hold a valid
  certificate for every active course and those courses between them award all
  three other badges. Until all three can be earned (a course not loaded yet),
  nobody has it: finishing the only course on file is not finishing the program.
- A key the Playbook has no artwork for draws nothing there.

Nothing in this repo holds a key for the link. The Playbook holds this
project's service-role key as a secret of its own.

## Local smoke test (no Supabase needed)
`npm run db:validate` loads every migration + the seed into an in-memory
Postgres (WASM) and exercises the session-credit, certificate, verification,
Playbook-link and quiz-grading logic. Use it after editing any SQL.

## Notes
- **Quiz questions:** the source export didn't include the real question sets,
  so only block 1 is seeded with working sample questions (to demonstrate
  grading). Add the real questions per block via SQL or an admin screen.
- **Videos:** `blocks.video_url` is empty pending the real media URLs.
- **Passing grade** is `courses.passing_grade` (100 for Process) — change it in
  one place to adjust the whole course.

// ============================================================================
// provision.mjs — Import groups, account executives, and account managers into
// Supabase, creating the Auth users that back group logins and AM logins.
//
// Run in a networked environment AFTER the migrations + seed have been applied.
//
//   npm i @supabase/supabase-js
//   export SUPABASE_URL="https://<ref>.supabase.co"
//   export SUPABASE_SERVICE_ROLE_KEY="<service_role key>"   # server-side only!
//   # optional: export GROUP_EMAIL_DOMAIN="groups.certified.44i"
//   node scripts/provision.mjs \
//       --groups data/groups.csv \
//       --aes data/account_executives.csv \
//       --ams data/account_managers.csv
//
// Idempotent: re-running upserts rows and reuses existing Auth users.
// ============================================================================
import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'node:fs';

const URL = process.env.SUPABASE_URL;
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const DOMAIN = process.env.GROUP_EMAIL_DOMAIN || 'groups.certified.44i';
if (!URL || !KEY) { console.error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY'); process.exit(1); }

const arg = (name, def) => {
  const i = process.argv.indexOf(`--${name}`);
  return i > -1 ? process.argv[i + 1] : def;
};
const files = {
  groups: arg('groups', 'data/groups.csv'),
  aes: arg('aes', 'data/account_executives.csv'),
  ams: arg('ams', 'data/account_managers.csv'),
};

const sb = createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } });

// --- tiny CSV parser (handles quoted fields + commas/newlines in quotes) ----
function parseCsv(text) {
  const rows = [];
  let row = [], field = '', q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') q = false;
      else field += c;
    } else if (c === '"') q = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n') { row.push(field); rows.push(row); row = []; field = ''; }
    else if (c === '\r') { /* skip */ }
    else field += c;
  }
  if (field.length || row.length) { row.push(field); rows.push(row); }
  const header = rows.shift().map((h) => h.trim());
  return rows
    .filter((r) => r.some((c) => c.trim() !== ''))
    .map((r) => Object.fromEntries(header.map((h, i) => [h, (r[i] ?? '').trim()])));
}
const load = (f) => parseCsv(readFileSync(f, 'utf8'));

// --- find-or-create an Auth user, return its id ------------------------------
async function ensureUser(email, password) {
  const { data, error } = await sb.auth.admin.createUser({
    email, password, email_confirm: true,
  });
  if (!error) return data.user.id;
  // Already exists → look it up by paging through users
  let page = 1;
  for (;;) {
    const { data: list, error: le } = await sb.auth.admin.listUsers({ page, perPage: 200 });
    if (le) throw le;
    const hit = list.users.find((u) => (u.email || '').toLowerCase() === email.toLowerCase());
    if (hit) {
      // keep the password in sync with the CSV
      await sb.auth.admin.updateUserById(hit.id, { password });
      return hit.id;
    }
    if (list.users.length < 200) throw error; // exhausted, surface original error
    page++;
  }
}

async function main() {
  console.log('Provisioning against', URL, '\n');

  // 1) Groups + group Auth users -------------------------------------------
  const groupIdBySlug = {};
  for (const g of load(files.groups)) {
    if (!g.slug) continue;
    const { data: grp, error } = await sb.from('groups')
      .upsert({ slug: g.slug, name: g.name, external_ref: g.external_ref || null },
              { onConflict: 'slug' })
      .select('id').single();
    if (error) throw error;
    groupIdBySlug[g.slug] = grp.id;

    const email = `${g.slug}@${DOMAIN}`;
    const uid = await ensureUser(email, g.password);
    const { error: gae } = await sb.from('group_accounts')
      .upsert({ group_id: grp.id, auth_user_id: uid, login_email: email },
              { onConflict: 'group_id' });
    if (gae) throw gae;
    console.log('  group  ✓', g.slug, '→', email);
  }

  // 2) Account Managers -----------------------------------------------------
  for (const m of load(files.ams)) {
    if (!m.email) continue;
    const uid = await ensureUser(m.email, m.password);
    const { error } = await sb.from('account_managers')
      .upsert({ auth_user_id: uid, full_name: m.full_name, email: m.email },
              { onConflict: 'auth_user_id' });
    if (error) throw error;
    console.log('  AM     ✓', m.full_name, '<' + m.email + '>');
  }

  // 3) Account Executives ---------------------------------------------------
  let aeCount = 0;
  for (const a of load(files.aes)) {
    const gid = groupIdBySlug[a.group_slug];
    if (!gid) { console.warn('  AE skipped (unknown group):', a.full_name, a.group_slug); continue; }
    const { error } = await sb.from('account_executives')
      .upsert({ group_id: gid, full_name: a.full_name, email: a.email || null,
                external_ref: a.external_ref || null },
              { onConflict: 'group_id,full_name' });
    if (error) throw error;
    aeCount++;
  }
  console.log('  AEs    ✓', aeCount, 'imported');

  console.log('\nDone. Groups sign in with email <slug>@' + DOMAIN + ' and their CSV password.');
}
main().catch((e) => { console.error('\nProvisioning failed:', e.message || e); process.exit(1); });

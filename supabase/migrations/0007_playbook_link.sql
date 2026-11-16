-- ============================================================================
-- 0007_playbook_link.sql — The link to Fourge Playbook
--
-- Fourge Playbook builds the proposals an Account Executive presents. It shows
-- a badge on every proposal by an AE who holds a valid certificate here. For
-- that, both systems must know an AE by the same id.
--
--   * The roster comes FROM the Playbook (which mirrors the order system, the
--     master for groups and AEs). playbook_roster_sync() takes that roster and
--     files each group and AE here under external_ref = the order system's id.
--     A group or an AE set up by hand before the link is matched by name and
--     given its id; nothing is ever deleted, so no certificate is ever lost.
--   * The certificates go TO the Playbook. playbook_certifications() returns
--     every valid certificate by the AE's order-system id.
--
-- Both are for the Playbook's server alone (service_role). No browser, no
-- group login and no anonymous caller can run them.
--
-- A group filed here by the sync has no login until one is made for it
-- (scripts/provision.mjs, or the Auth dashboard): the slug it gets is what its
-- login email is built from.
-- ============================================================================

-- One row per order-system id, on both tables.
create unique index if not exists uq_groups_external_ref
  on public.groups (external_ref) where external_ref is not null;
create unique index if not exists uq_ae_external_ref
  on public.account_executives (external_ref) where external_ref is not null;

-- ---------------------------------------------------------------------------
-- The roster, from the Playbook.
--   p_groups: [{ "external_ref": "<group id>", "name": "…" }, …]
--   p_aes:    [{ "external_ref": "<ae id>", "group_ref": "<group id>",
--                "full_name": "…", "email": "…" | null }, …]
-- Returns what it did, as counts.
-- ---------------------------------------------------------------------------
create or replace function public.playbook_roster_sync(p_groups jsonb, p_aes jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  g jsonb; a jsonb;
  v_gid uuid; v_aid uuid;
  v_ref text; v_name text; v_email text; v_base text; v_slug text; n int; v_clash boolean;
  groups_new int := 0; groups_linked int := 0;
  aes_new int := 0; aes_linked int := 0; aes_updated int := 0; skipped int := 0;
begin
  for g in select * from jsonb_array_elements(coalesce(p_groups, '[]'::jsonb)) loop
    v_ref := nullif(trim(g->>'external_ref'), '');
    v_name := nullif(trim(g->>'name'), '');
    if v_ref is null or v_name is null then skipped := skipped + 1; continue; end if;

    select id into v_gid from groups where external_ref = v_ref;
    if v_gid is not null then
      update groups set name = v_name where id = v_gid and name is distinct from v_name;
      continue;
    end if;
    -- A group set up by hand before the link: the same name, no id yet.
    select id into v_gid from groups
      where external_ref is null and lower(trim(name)) = lower(v_name) limit 1;
    if v_gid is not null then
      update groups set external_ref = v_ref where id = v_gid;
      groups_linked := groups_linked + 1;
      continue;
    end if;
    -- New here. The slug is made from the name and is what the login email is built from.
    v_base := trim(both '-' from regexp_replace(lower(v_name), '[^a-z0-9]+', '-', 'g'));
    if v_base = '' then v_base := 'group'; end if;
    v_slug := v_base; n := 1;
    while exists (select 1 from groups where slug = v_slug) loop
      n := n + 1; v_slug := v_base || '-' || n;
    end loop;
    insert into groups (slug, name, external_ref) values (v_slug, v_name, v_ref);
    groups_new := groups_new + 1;
  end loop;

  for a in select * from jsonb_array_elements(coalesce(p_aes, '[]'::jsonb)) loop
    v_ref := nullif(trim(a->>'external_ref'), '');
    v_name := nullif(trim(a->>'full_name'), '');
    v_email := nullif(lower(trim(a->>'email')), '');
    if v_ref is null or v_name is null then skipped := skipped + 1; continue; end if;
    select id into v_gid from groups where external_ref = nullif(trim(a->>'group_ref'), '');
    if v_gid is null then skipped := skipped + 1; continue; end if;

    select id into v_aid from account_executives where external_ref = v_ref;
    if v_aid is not null then
      -- Known: follow a new group, name or email. A name another AE of that group already holds cannot be taken
      -- (the roster is one name a group), so the row then stays where and as it is.
      v_clash := exists (select 1 from account_executives o
                          where o.group_id = v_gid and o.full_name = v_name and o.id <> v_aid);
      update account_executives ae
         set group_id  = case when v_clash then ae.group_id else v_gid end,
             full_name = case when v_clash then ae.full_name else v_name end,
             email     = coalesce(v_email, ae.email),
             is_active = true
       where ae.id = v_aid
         and ((not v_clash and (ae.group_id <> v_gid or ae.full_name <> v_name))
              or ae.email is distinct from coalesce(v_email, ae.email) or not ae.is_active);
      if found then aes_updated := aes_updated + 1; end if;
      continue;
    end if;
    -- An AE set up by hand before the link: the same name under the same group, no id yet.
    select id into v_aid from account_executives
      where group_id = v_gid and external_ref is null and lower(trim(full_name)) = lower(v_name) limit 1;
    if v_aid is not null then
      -- It takes the roster's spelling of the name too (the order system is the master), unless another AE holds it.
      update account_executives ae
         set external_ref = v_ref, email = coalesce(v_email, ae.email), is_active = true,
             full_name = case when exists (select 1 from account_executives o
                                where o.group_id = v_gid and o.full_name = v_name and o.id <> v_aid)
                              then ae.full_name else v_name end
       where ae.id = v_aid;
      aes_linked := aes_linked + 1;
      continue;
    end if;
    -- Two people of one group under one name cannot both be filed (the roster is one name a group).
    if exists (select 1 from account_executives where group_id = v_gid and full_name = v_name) then
      skipped := skipped + 1; continue;
    end if;
    insert into account_executives (group_id, full_name, email, external_ref)
      values (v_gid, v_name, v_email, v_ref);
    aes_new := aes_new + 1;
  end loop;

  return jsonb_build_object(
    'groups_new', groups_new, 'groups_linked', groups_linked,
    'aes_new', aes_new, 'aes_linked', aes_linked, 'aes_updated', aes_updated,
    'skipped', skipped);
end;
$$;

-- ---------------------------------------------------------------------------
-- The certificates, for the Playbook: every valid one, by the AE's id in the
-- order system, in the order the courses are taken. One JSON value, so no row
-- limit cuts the list short:
--   [{ "ae_ref": "…", "certificates": [
--        { "course": "process-certification", "title": "Process Certification",
--          "order": 1, "code": "…", "issued_at": "…" }, … ] }, … ]
-- An AE with no order-system id is not in it: nothing could match them.
-- ---------------------------------------------------------------------------
create or replace function public.playbook_certifications()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('ae_ref', t.ae_ref, 'certificates', t.certs) order by t.ae_ref), '[]'::jsonb)
  from (
    select ae.external_ref as ae_ref,
           jsonb_agg(jsonb_build_object(
             'course', co.slug, 'title', co.title, 'order', co.sort_order,
             'code', c.code, 'issued_at', c.issued_at) order by co.sort_order, co.title) as certs
    from certificates c
    join account_executives ae on ae.id = c.ae_id
    join courses co on co.id = c.course_id
    where c.status = 'valid' and ae.external_ref is not null
    group by ae.external_ref
  ) t;
$$;

revoke all on function public.playbook_roster_sync(jsonb, jsonb) from public, anon, authenticated;
revoke all on function public.playbook_certifications() from public, anon, authenticated;
grant execute on function public.playbook_roster_sync(jsonb, jsonb) to service_role;
grant execute on function public.playbook_certifications() to service_role;

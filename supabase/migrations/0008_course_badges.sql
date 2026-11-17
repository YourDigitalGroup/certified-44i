-- ============================================================================
-- 0008_course_badges.sql — Which badge a course awards
--
-- Fourge Playbook draws the program's badge artwork on a certified AE's
-- proposals. Which course earns which badge was settled on 2026-11-17:
--
--   101 Products            Online Visibility and Content Marketing
--   201 Products            Targeted Digital
--   every course, complete  Digital Marketing Professional
--   Process, Packages       none on their own
--
-- A course names the badges it awards in badge_keys. The keys are the names
-- of the Playbook's artwork: online-visibility, content-marketing,
-- targeted-digital, professional. A key the Playbook has no artwork for draws
-- nothing there, so a typo is harmless and a new badge needs its artwork added
-- on that side.
--
-- The two Products courses get theirs on their own when they are created,
-- by their name, so adding a course stays data entry. Any course can be set
-- by hand:  update courses set badge_keys = '{targeted-digital}' where slug = '…';
-- ============================================================================

alter table public.courses
  add column if not exists badge_keys text[] not null default '{}';

comment on column public.courses.badge_keys is
  'The badges this course awards, by the Playbook''s artwork keys (online-visibility, content-marketing, targeted-digital). Empty: none on its own.';

-- A new course with no badge named takes the one its name stands for.
create or replace function app.course_badge_defaults()
returns trigger language plpgsql as $$
begin
  if coalesce(array_length(new.badge_keys, 1), 0) = 0 then
    if (new.slug || ' ' || new.title) ~* '101\W*products' then
      new.badge_keys := array['online-visibility', 'content-marketing'];
    elsif (new.slug || ' ' || new.title) ~* '201\W*products' then
      new.badge_keys := array['targeted-digital'];
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_course_badge_defaults on public.courses;
create trigger trg_course_badge_defaults before insert on public.courses
  for each row execute function app.course_badge_defaults();

-- A Products course already on file gets the same.
update public.courses set badge_keys = array['online-visibility', 'content-marketing']
  where coalesce(array_length(badge_keys, 1), 0) = 0 and (slug || ' ' || title) ~* '101\W*products';
update public.courses set badge_keys = array['targeted-digital']
  where coalesce(array_length(badge_keys, 1), 0) = 0 and (slug || ' ' || title) ~* '201\W*products';

-- ---------------------------------------------------------------------------
-- The certificates, for the Playbook, now with the badges each one awards:
--   [{ "ae_ref": "…", "certificates": [
--        { "course": "…", "title": "…", "order": 2, "code": "…",
--          "issued_at": "…", "badges": ["online-visibility", "content-marketing"] }, … ] }, … ]
--
-- The Professional badge is not a course. An AE has it when they hold a valid
-- certificate for EVERY active course and those courses between them award all
-- three of the other badges. It goes out as one more item at the end of the
-- AE's list, course "digital-marketing-professional", dated the day the last
-- certificate was issued, with no code. While the three other badges cannot
-- all be earned (a course not yet loaded), nobody has it: finishing the only
-- course on file is not finishing the program.
-- ---------------------------------------------------------------------------
create or replace function public.playbook_certifications()
returns jsonb language sql stable security definer set search_path = public as $$
  with held as (
    select ae.external_ref as ae_ref, co.id as course_id, co.slug, co.title, co.sort_order,
           co.is_active, co.badge_keys, c.code, c.issued_at
    from certificates c
    join account_executives ae on ae.id = c.ae_id
    join courses co on co.id = c.course_id
    where c.status = 'valid' and ae.external_ref is not null
  ),
  per_ae as (
    select h.ae_ref,
           jsonb_agg(jsonb_build_object(
             'course', h.slug, 'title', h.title, 'order', h.sort_order,
             'code', h.code, 'issued_at', h.issued_at, 'badges', to_jsonb(h.badge_keys))
             order by h.sort_order, h.title) as certs,
           count(distinct h.course_id) filter (where h.is_active) as active_held,
           max(h.issued_at) as last_issued,
           max(h.sort_order) as last_order,
           (select array_agg(distinct k) from held h2, unnest(h2.badge_keys) k where h2.ae_ref = h.ae_ref) as keys
    from held h
    group by h.ae_ref
  ),
  program as (select count(*) as courses from courses where is_active)
  select coalesce(jsonb_agg(jsonb_build_object(
           'ae_ref', p.ae_ref,
           'certificates', case
             when program.courses > 0 and p.active_held = program.courses
                  and p.keys @> array['online-visibility', 'content-marketing', 'targeted-digital']
             then p.certs || jsonb_build_array(jsonb_build_object(
                    'course', 'digital-marketing-professional', 'title', 'Digital Marketing Professional',
                    'order', p.last_order + 1, 'code', null, 'issued_at', p.last_issued,
                    'badges', jsonb_build_array('professional')))
             else p.certs end) order by p.ae_ref), '[]'::jsonb)
  from per_ae p, program;
$$;

revoke all on function public.playbook_certifications() from public, anon, authenticated;
grant execute on function public.playbook_certifications() to service_role;

-- ============================================================================
-- 0006_verification_reporting.sql — Public cert verification + reporting views
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Public certificate verification (callable without login).
-- Returns only non-sensitive fields, and only for VALID certificates.
-- ---------------------------------------------------------------------------
create or replace function public.verify_certificate(p_code text)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when c.id is null then
      jsonb_build_object('found', false)
    else
      jsonb_build_object(
        'found', true,
        'name', c.name_on_certificate,
        'credential', co.title,
        'issued_at', c.issued_at,
        'status', c.status,
        'code', c.code)
    end
  from (select 1) _
  left join public.certificates c
    on upper(c.code) = upper(trim(p_code)) and c.status = 'valid'
  left join public.courses co on co.id = c.course_id;
$$;

revoke all on function public.verify_certificate(text) from public;
grant execute on function public.verify_certificate(text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Reporting views (security_invoker => underlying RLS applies, so a group
-- sees only its own rows and AMs see everything).
-- ---------------------------------------------------------------------------

-- One row per AE per course: how many blocks done, complete?, cert code.
create or replace view public.v_ae_course_progress
  with (security_invoker = true) as
select
  ae.id                                   as ae_id,
  ae.full_name,
  g.id                                    as group_id,
  g.name                                  as group_name,
  co.id                                   as course_id,
  co.title                                as course_title,
  (select count(*) from public.blocks b
     where b.course_id = co.id and b.is_active)              as blocks_total,
  (select count(*) from public.block_progress p
     join public.blocks b on b.id = p.block_id
     where p.ae_id = ae.id and b.course_id = co.id
       and b.is_active and p.status = 'completed')           as blocks_completed,
  cert.code                               as certificate_code,
  cert.issued_at                          as certified_at
from public.account_executives ae
join public.groups g   on g.id = ae.group_id
cross join public.courses co
left join public.certificates cert
  on cert.ae_id = ae.id and cert.course_id = co.id
where co.is_active;

-- Group roll-up: AE counts and how many are fully certified per course.
create or replace view public.v_group_summary
  with (security_invoker = true) as
select
  group_id, group_name, course_id, course_title,
  count(*)                                             as ae_count,
  count(*) filter (where blocks_completed >= blocks_total
                     and blocks_total > 0)             as certified_count,
  round(avg(case when blocks_total = 0 then 0
                 else blocks_completed * 100.0 / blocks_total end))
                                                       as avg_percent_complete
from public.v_ae_course_progress
group by group_id, group_name, course_id, course_title;

grant select on public.v_ae_course_progress, public.v_group_summary to authenticated;

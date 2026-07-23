-- ============================================================================
-- 0004_functions.sql — Identity helpers, quiz grading, credit propagation,
--                      and automatic certificate issuance
-- ============================================================================

create schema if not exists app;

-- ---------------------------------------------------------------------------
-- Identity helpers (SECURITY DEFINER so RLS policies can call them safely)
-- ---------------------------------------------------------------------------

-- The group_id represented by the currently logged-in auth user (group login).
create or replace function app.current_group_id()
returns uuid language sql stable security definer set search_path = public as $$
  select group_id from public.group_accounts where auth_user_id = auth.uid();
$$;

-- The account_manager id for the currently logged-in auth user (or null).
create or replace function app.current_am_id()
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.account_managers where auth_user_id = auth.uid() and is_active;
$$;

create or replace function app.is_am()
returns boolean language sql stable security definer set search_path = public as $$
  select app.current_am_id() is not null;
$$;

-- ---------------------------------------------------------------------------
-- Certificate code generator, e.g. 44I-PROCESS-9F3A2K
-- ---------------------------------------------------------------------------
create or replace function app.gen_cert_code(course_slug text)
returns text language sql volatile as $$
  select '44I-' || upper(left(split_part(course_slug, '-', 1), 8))
         || '-' || upper(encode(gen_random_bytes(4), 'hex'));
$$;

-- ---------------------------------------------------------------------------
-- Issue a certificate for an AE once every active block of a course is done.
-- Idempotent: does nothing if not complete or already issued.
-- ---------------------------------------------------------------------------
create or replace function app.maybe_issue_certificate(p_ae_id uuid, p_course_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_total   int;
  v_done    int;
  v_name    text;
  v_slug    text;
begin
  select count(*) into v_total
    from public.blocks b
    where b.course_id = p_course_id and b.is_active;

  select count(*) into v_done
    from public.block_progress p
    join public.blocks b on b.id = p.block_id
    where p.ae_id = p_ae_id and b.course_id = p_course_id
      and b.is_active and p.status = 'completed';

  if v_total = 0 or v_done < v_total then
    return;
  end if;

  select full_name into v_name from public.account_executives where id = p_ae_id;
  select slug into v_slug from public.courses where id = p_course_id;

  insert into public.certificates (ae_id, course_id, name_on_certificate, code)
  values (p_ae_id, p_course_id, coalesce(v_name, 'Account Executive'),
          app.gen_cert_code(v_slug))
  on conflict (ae_id, course_id) do nothing;
end;
$$;

-- Fire certificate check whenever a block is completed -----------------------
create or replace function app.trg_progress_after()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_course uuid;
begin
  if new.status = 'completed' then
    select course_id into v_course from public.blocks where id = new.block_id;
    perform app.maybe_issue_certificate(new.ae_id, v_course);
  end if;
  return new;
end;
$$;

create trigger trg_progress_cert
  after insert or update of status on public.block_progress
  for each row execute function app.trg_progress_after();

-- ---------------------------------------------------------------------------
-- Server-side quiz grading (self-serve). Correct answers never leave the DB.
-- p_answers: jsonb array of {question_id, option_ids:[...]}. Requires 100%.
-- Writes block_progress on a perfect score and returns the result.
-- ---------------------------------------------------------------------------
create or replace function app.submit_quiz(p_quiz_id uuid, p_answers jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_group   uuid := app.current_group_id();
  v_ae_id   uuid;
  v_block   uuid;
  v_total   int := 0;
  v_correct int := 0;
  r         record;
  v_chosen  uuid[];
  v_answer_key uuid[];
  v_ok      boolean;
begin
  -- Resolve the acting AE: the client passes their AE id via request header
  -- 'x-ae-id' (set after the learner picks their name from the group roster).
  v_ae_id := nullif(current_setting('request.headers', true)::json->>'x-ae-id','')::uuid;

  if v_ae_id is null then
    raise exception 'No acting AE selected';
  end if;
  -- The AE must belong to the logged-in group (unless an AM is acting).
  if not app.is_am() then
    if not exists (select 1 from public.account_executives
                   where id = v_ae_id and group_id = v_group) then
      raise exception 'AE does not belong to the current group';
    end if;
  end if;

  select block_id into v_block from public.quizzes where id = p_quiz_id;
  if v_block is null then raise exception 'Unknown quiz'; end if;

  for r in select id from public.questions where quiz_id = p_quiz_id loop
    v_total := v_total + 1;

    select array_agg(id order by id) into v_answer_key
      from public.question_options where question_id = r.id and is_correct;

    select array_agg(opt::uuid order by opt::uuid) into v_chosen
      from jsonb_array_elements(p_answers) a
      cross join lateral jsonb_array_elements_text(a->'option_ids') as opt
      where (a->>'question_id')::uuid = r.id;

    v_ok := coalesce(v_chosen, '{}') = coalesce(v_answer_key, '{}');
    if v_ok then v_correct := v_correct + 1; end if;
  end loop;

  if v_total > 0 and v_correct = v_total then
    insert into public.block_progress (ae_id, block_id, status, score, credited_via)
    values (v_ae_id, v_block, 'completed', 100, 'self')
    on conflict (ae_id, block_id)
      do update set status = 'completed', score = 100, credited_via = 'self';
    return jsonb_build_object('passed', true, 'score', 100,
                              'total', v_total, 'correct', v_correct);
  end if;

  return jsonb_build_object('passed', false,
    'score', case when v_total = 0 then 0 else round(v_correct * 100.0 / v_total) end,
    'total', v_total, 'correct', v_correct);
end;
$$;

-- ---------------------------------------------------------------------------
-- AM marks a session block as passed -> credit every PRESENT attendee.
-- ---------------------------------------------------------------------------
create or replace function app.trg_session_block_credit()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_course uuid;
begin
  if new.quiz_passed and (tg_op = 'INSERT' or coalesce(old.quiz_passed,false) = false) then
    if new.passed_at is null then new.passed_at := now(); end if;

    insert into public.block_progress (ae_id, block_id, status, score, credited_via, session_id)
    select sa.ae_id, new.block_id, 'completed', 100, 'session', new.session_id
      from public.session_attendees sa
     where sa.session_id = new.session_id and sa.present
    on conflict (ae_id, block_id) do update
      set status = 'completed', score = 100,
          credited_via = 'session', session_id = excluded.session_id;
  end if;
  return new;
end;
$$;

create trigger trg_session_block_credit
  before insert or update of quiz_passed on public.session_blocks
  for each row execute function app.trg_session_block_credit();

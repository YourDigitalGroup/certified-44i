-- ============================================================================
-- seed.sql — CERTIFIED.44i content seed
-- v1: Process Certification only (others are added later as data).
-- Safe to re-run: uses stable slugs + ON CONFLICT.
-- NOTE: Real quiz questions were not present in the source export. Block 1 is
-- seeded with working sample questions to demonstrate grading; the remaining
-- blocks have empty quizzes awaiting the real question sets.
-- ============================================================================

insert into public.courses (slug, title, description, sort_order, passing_grade)
values ('process-certification', 'Process Certification',
  'Master the 44i way of working — from understanding your digital agency to audits, needs analyses, insertion orders and reporting. Complete each block''s video and pass its quiz at 100% to advance.',
  1, 100)
on conflict (slug) do update set title = excluded.title,
  description = excluded.description, sort_order = excluded.sort_order,
  passing_grade = excluded.passing_grade;

insert into public.blocks (course_id, slug, title, video_provider, duration_minutes, sort_order)
select id, 'your-digital-agency', 'Your Digital Agency', 'mp4', 12, 1 from public.courses where slug = 'process-certification'
on conflict (course_id, slug) do update set title = excluded.title,
  duration_minutes = excluded.duration_minutes, sort_order = excluded.sort_order;
insert into public.blocks (course_id, slug, title, video_provider, duration_minutes, sort_order)
select id, 'resource-section', 'Resource Section', 'mp4', 12, 2 from public.courses where slug = 'process-certification'
on conflict (course_id, slug) do update set title = excluded.title,
  duration_minutes = excluded.duration_minutes, sort_order = excluded.sort_order;
insert into public.blocks (course_id, slug, title, video_provider, duration_minutes, sort_order)
select id, 'trello-basics', 'Trello Basics', 'mp4', 14, 3 from public.courses where slug = 'process-certification'
on conflict (course_id, slug) do update set title = excluded.title,
  duration_minutes = excluded.duration_minutes, sort_order = excluded.sort_order;
insert into public.blocks (course_id, slug, title, video_provider, duration_minutes, sort_order)
select id, 'digital-audit', 'Digital Audit', 'mp4', 14, 4 from public.courses where slug = 'process-certification'
on conflict (course_id, slug) do update set title = excluded.title,
  duration_minutes = excluded.duration_minutes, sort_order = excluded.sort_order;
insert into public.blocks (course_id, slug, title, video_provider, duration_minutes, sort_order)
select id, 'client-needs-analysis', 'Client Needs Analysis', 'mp4', 15, 5 from public.courses where slug = 'process-certification'
on conflict (course_id, slug) do update set title = excluded.title,
  duration_minutes = excluded.duration_minutes, sort_order = excluded.sort_order;
insert into public.blocks (course_id, slug, title, video_provider, duration_minutes, sort_order)
select id, 'request-for-recommendation', 'Request for Recommendation', 'mp4', 8, 6 from public.courses where slug = 'process-certification'
on conflict (course_id, slug) do update set title = excluded.title,
  duration_minutes = excluded.duration_minutes, sort_order = excluded.sort_order;
insert into public.blocks (course_id, slug, title, video_provider, duration_minutes, sort_order)
select id, 'insertion-orders', 'Insertion Orders', 'mp4', 4, 7 from public.courses where slug = 'process-certification'
on conflict (course_id, slug) do update set title = excluded.title,
  duration_minutes = excluded.duration_minutes, sort_order = excluded.sort_order;
insert into public.blocks (course_id, slug, title, video_provider, duration_minutes, sort_order)
select id, 'intake-form-training', 'Intake Form Training', 'mp4', 12, 8 from public.courses where slug = 'process-certification'
on conflict (course_id, slug) do update set title = excluded.title,
  duration_minutes = excluded.duration_minutes, sort_order = excluded.sort_order;
insert into public.blocks (course_id, slug, title, video_provider, duration_minutes, sort_order)
select id, 'reporting', 'Reporting', 'mp4', 0, 9 from public.courses where slug = 'process-certification'
on conflict (course_id, slug) do update set title = excluded.title,
  duration_minutes = excluded.duration_minutes, sort_order = excluded.sort_order;

-- One quiz per block
insert into public.quizzes (block_id, title)
select b.id, 'Your Digital Agency Quiz' from public.blocks b join public.courses c on c.id=b.course_id
where c.slug='process-certification' and b.slug='your-digital-agency'
on conflict (block_id) do nothing;
insert into public.quizzes (block_id, title)
select b.id, 'Resource Section Quiz' from public.blocks b join public.courses c on c.id=b.course_id
where c.slug='process-certification' and b.slug='resource-section'
on conflict (block_id) do nothing;
insert into public.quizzes (block_id, title)
select b.id, 'Trello Basics Quiz' from public.blocks b join public.courses c on c.id=b.course_id
where c.slug='process-certification' and b.slug='trello-basics'
on conflict (block_id) do nothing;
insert into public.quizzes (block_id, title)
select b.id, 'Digital Audit Quiz' from public.blocks b join public.courses c on c.id=b.course_id
where c.slug='process-certification' and b.slug='digital-audit'
on conflict (block_id) do nothing;
insert into public.quizzes (block_id, title)
select b.id, 'Client Needs Analysis Quiz' from public.blocks b join public.courses c on c.id=b.course_id
where c.slug='process-certification' and b.slug='client-needs-analysis'
on conflict (block_id) do nothing;
insert into public.quizzes (block_id, title)
select b.id, 'Request for Recommendation Quiz' from public.blocks b join public.courses c on c.id=b.course_id
where c.slug='process-certification' and b.slug='request-for-recommendation'
on conflict (block_id) do nothing;
insert into public.quizzes (block_id, title)
select b.id, 'Insertion Orders Quiz' from public.blocks b join public.courses c on c.id=b.course_id
where c.slug='process-certification' and b.slug='insertion-orders'
on conflict (block_id) do nothing;
insert into public.quizzes (block_id, title)
select b.id, 'Intake Form Training Quiz' from public.blocks b join public.courses c on c.id=b.course_id
where c.slug='process-certification' and b.slug='intake-form-training'
on conflict (block_id) do nothing;
insert into public.quizzes (block_id, title)
select b.id, 'Reporting Quiz' from public.blocks b join public.courses c on c.id=b.course_id
where c.slug='process-certification' and b.slug='reporting'
on conflict (block_id) do nothing;

-- ---- Sample questions for block 1 ("Your Digital Agency") — replace/extend ----
do $$
declare v_quiz uuid; v_q uuid;
begin
  select qz.id into v_quiz from public.quizzes qz
    join public.blocks b on b.id = qz.block_id
    join public.courses c on c.id = b.course_id
    where c.slug='process-certification' and b.slug='your-digital-agency';
  if v_quiz is null then return; end if;
  delete from public.questions where quiz_id = v_quiz;  -- reset sample set

  insert into public.questions (quiz_id, prompt, q_type, sort_order)
    values (v_quiz, 'What score must you achieve on each section quiz to advance in Process Certification?', 'single', 1)
    returning id into v_q;
  insert into public.question_options (question_id, label, is_correct, sort_order) values
    (v_q, '70%', false, 1), (v_q, '80%', false, 2), (v_q, '90%', false, 3), (v_q, '100%', true, 4);

  insert into public.questions (quiz_id, prompt, q_type, sort_order)
    values (v_quiz, 'In what order must the section training videos be watched?', 'single', 2)
    returning id into v_q;
  insert into public.question_options (question_id, label, is_correct, sort_order) values
    (v_q, 'Any order', false, 1), (v_q, 'In sequence, start to finish', true, 2), (v_q, 'Newest first', false, 3);

  insert into public.questions (quiz_id, prompt, q_type, sort_order)
    values (v_quiz, 'You may rewatch a section video as many times as you need.', 'true_false', 3)
    returning id into v_q;
  insert into public.question_options (question_id, label, is_correct, sort_order) values
    (v_q, 'True', true, 1), (v_q, 'False', false, 2);
end $$;


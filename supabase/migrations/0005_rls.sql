-- ============================================================================
-- 0005_rls.sql — Row-Level Security
--
-- Principals:
--   * Group login  — app.current_group_id() returns its group; may read/write
--                    only its own AEs and their progress; reads content.
--   * Account Manager — app.is_am() is true; cross-group read/write; runs
--                    sessions; manages content.
-- Correct quiz answers are never exposed to group logins (only to AMs); the
-- submit_quiz() RPC grades server-side.
-- ============================================================================

-- Enable RLS on everything ---------------------------------------------------
alter table public.courses            enable row level security;
alter table public.blocks             enable row level security;
alter table public.quizzes            enable row level security;
alter table public.questions          enable row level security;
alter table public.question_options   enable row level security;
alter table public.groups             enable row level security;
alter table public.group_accounts     enable row level security;
alter table public.account_executives enable row level security;
alter table public.account_managers   enable row level security;
alter table public.block_progress     enable row level security;
alter table public.certificates       enable row level security;
alter table public.training_sessions  enable row level security;
alter table public.session_attendees  enable row level security;
alter table public.session_blocks     enable row level security;

-- ---------------------------------------------------------------------------
-- CONTENT: readable by any authenticated principal; writable by AMs only.
-- question_options.is_correct must stay hidden from group logins, so options
-- are readable only by AMs. Group logins get questions/blocks but grade via RPC.
-- ---------------------------------------------------------------------------
create policy content_read_courses  on public.courses  for select to authenticated using (is_active or app.is_am());
create policy content_read_blocks   on public.blocks   for select to authenticated using (is_active or app.is_am());
create policy content_read_quizzes  on public.quizzes  for select to authenticated using (true);
create policy content_read_questions on public.questions for select to authenticated using (true);
-- Options: only AMs may read (keeps correct answers off the client)
create policy options_read_am on public.question_options for select to authenticated using (app.is_am());

-- Content writes: AMs only
create policy content_write_courses on public.courses  for all to authenticated using (app.is_am()) with check (app.is_am());
create policy content_write_blocks  on public.blocks   for all to authenticated using (app.is_am()) with check (app.is_am());
create policy content_write_quizzes on public.quizzes  for all to authenticated using (app.is_am()) with check (app.is_am());
create policy content_write_questions on public.questions for all to authenticated using (app.is_am()) with check (app.is_am());
create policy content_write_options on public.question_options for all to authenticated using (app.is_am()) with check (app.is_am());

-- ---------------------------------------------------------------------------
-- GROUPS: a group sees itself; AMs see all. AM-managed writes.
-- ---------------------------------------------------------------------------
create policy groups_read on public.groups for select to authenticated
  using (app.is_am() or id = app.current_group_id());
create policy groups_write on public.groups for all to authenticated
  using (app.is_am()) with check (app.is_am());

-- group_accounts: AMs only (provisioning is done with the service role)
create policy group_accounts_am on public.group_accounts for select to authenticated
  using (app.is_am());

-- account_managers: an AM sees the roster of AMs
create policy am_read on public.account_managers for select to authenticated
  using (app.is_am());

-- ---------------------------------------------------------------------------
-- ACCOUNT EXECUTIVES: a group reads/writes its own roster; AMs all.
-- ---------------------------------------------------------------------------
create policy ae_read on public.account_executives for select to authenticated
  using (app.is_am() or group_id = app.current_group_id());
create policy ae_write on public.account_executives for all to authenticated
  using (app.is_am() or group_id = app.current_group_id())
  with check (app.is_am() or group_id = app.current_group_id());

-- ---------------------------------------------------------------------------
-- BLOCK PROGRESS: scoped to the AE's group; AMs all.
-- (Self-serve writes normally go through submit_quiz(), but a group may also
-- read/manage its own AEs' progress.)
-- ---------------------------------------------------------------------------
create policy progress_read on public.block_progress for select to authenticated
  using (
    app.is_am()
    or exists (select 1 from public.account_executives ae
               where ae.id = block_progress.ae_id and ae.group_id = app.current_group_id())
  );
create policy progress_write on public.block_progress for all to authenticated
  using (
    app.is_am()
    or exists (select 1 from public.account_executives ae
               where ae.id = block_progress.ae_id and ae.group_id = app.current_group_id())
  )
  with check (
    app.is_am()
    or exists (select 1 from public.account_executives ae
               where ae.id = block_progress.ae_id and ae.group_id = app.current_group_id())
  );

-- ---------------------------------------------------------------------------
-- CERTIFICATES: group reads its own AEs'; AMs all. Public verification uses a
-- dedicated SECURITY DEFINER RPC (0006), not direct table reads.
-- ---------------------------------------------------------------------------
create policy cert_read on public.certificates for select to authenticated
  using (
    app.is_am()
    or exists (select 1 from public.account_executives ae
               where ae.id = certificates.ae_id and ae.group_id = app.current_group_id())
  );
create policy cert_write on public.certificates for all to authenticated
  using (app.is_am()) with check (app.is_am());

-- ---------------------------------------------------------------------------
-- TRAINING SESSIONS + attendance + blocks: AMs only.
-- ---------------------------------------------------------------------------
create policy sessions_am on public.training_sessions for all to authenticated
  using (app.is_am()) with check (app.is_am());
create policy session_attendees_am on public.session_attendees for all to authenticated
  using (app.is_am()) with check (app.is_am());
create policy session_blocks_am on public.session_blocks for all to authenticated
  using (app.is_am()) with check (app.is_am());

-- ============================================================================
-- 0003_progress.sql — Progress, certificates, and AM-led training sessions
-- ============================================================================

-- Per-AE, per-block progress -------------------------------------------------
create table public.block_progress (
  id           uuid primary key default gen_random_uuid(),
  ae_id        uuid not null references public.account_executives(id) on delete cascade,
  block_id     uuid not null references public.blocks(id) on delete cascade,
  status       text not null default 'completed'
                 check (status in ('available','completed')),
  score        int  check (score between 0 and 100),
  credited_via text not null default 'self' check (credited_via in ('self','session')),
  session_id   uuid,                          -- FK added after sessions table
  completed_at timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (ae_id, block_id)
);
create index idx_progress_ae on public.block_progress(ae_id);
create index idx_progress_block on public.block_progress(block_id);
create trigger trg_progress_updated before update on public.block_progress
  for each row execute function public.set_updated_at();

-- Issued certificates --------------------------------------------------------
create table public.certificates (
  id                  uuid primary key default gen_random_uuid(),
  ae_id               uuid not null references public.account_executives(id) on delete cascade,
  course_id           uuid not null references public.courses(id) on delete cascade,
  name_on_certificate text not null,
  code                text not null unique,
  status              text not null default 'valid' check (status in ('valid','revoked')),
  issued_at           timestamptz not null default now(),
  unique (ae_id, course_id)
);
create index idx_cert_course on public.certificates(course_id);

-- AM-led training sessions ---------------------------------------------------
create table public.training_sessions (
  id         uuid primary key default gen_random_uuid(),
  am_id      uuid not null references public.account_managers(id) on delete restrict,
  group_id   uuid not null references public.groups(id) on delete cascade,
  course_id  uuid not null references public.courses(id) on delete cascade,
  status     text not null default 'open' check (status in ('open','closed')),
  notes      text default '',
  started_at timestamptz not null default now(),
  ended_at   timestamptz
);
create index idx_sessions_group on public.training_sessions(group_id);
create index idx_sessions_am on public.training_sessions(am_id);

-- Who attended a session (the AM checks these off) ---------------------------
create table public.session_attendees (
  session_id uuid not null references public.training_sessions(id) on delete cascade,
  ae_id      uuid not null references public.account_executives(id) on delete cascade,
  present    boolean not null default true,
  primary key (session_id, ae_id)
);

-- Which blocks were covered + whether the quiz was passed --------------------
create table public.session_blocks (
  session_id  uuid not null references public.training_sessions(id) on delete cascade,
  block_id    uuid not null references public.blocks(id) on delete cascade,
  quiz_passed boolean not null default false,
  passed_at   timestamptz,
  primary key (session_id, block_id)
);

-- Now that sessions exist, link progress back to the session that credited it
alter table public.block_progress
  add constraint fk_progress_session
  foreign key (session_id) references public.training_sessions(id) on delete set null;

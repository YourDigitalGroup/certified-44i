-- ============================================================================
-- 0001_content.sql — Course content (data-driven, editable)
-- CERTIFIED.44i
--
-- A "course" is a certification level. A "block" is one section = one video +
-- one quiz. Adding a new certification later is data entry, not a code change.
-- ============================================================================

create extension if not exists pgcrypto;   -- gen_random_uuid(), gen_random_bytes()

-- Shared updated_at trigger ---------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Courses (= certification levels) -------------------------------------------
create table public.courses (
  id            uuid primary key default gen_random_uuid(),
  slug          text not null unique,
  title         text not null,
  description   text default '',
  sort_order    int  not null default 0,
  passing_grade int  not null default 100 check (passing_grade between 1 and 100),
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create trigger trg_courses_updated before update on public.courses
  for each row execute function public.set_updated_at();

-- Blocks (= sections: one video + one quiz) ----------------------------------
create table public.blocks (
  id               uuid primary key default gen_random_uuid(),
  course_id        uuid not null references public.courses(id) on delete cascade,
  slug             text not null,
  title            text not null,
  description      text default '',
  video_url        text,
  video_provider   text not null default 'mp4',   -- mp4 | youtube | vimeo | ...
  duration_minutes int  default 0,
  sort_order       int  not null default 0,
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (course_id, slug)
);
create index idx_blocks_course on public.blocks(course_id, sort_order);
create trigger trg_blocks_updated before update on public.blocks
  for each row execute function public.set_updated_at();

-- Quizzes (one per block) ----------------------------------------------------
create table public.quizzes (
  id          uuid primary key default gen_random_uuid(),
  block_id    uuid not null unique references public.blocks(id) on delete cascade,
  title       text not null default 'Quiz',
  created_at  timestamptz not null default now()
);

-- Questions ------------------------------------------------------------------
create table public.questions (
  id          uuid primary key default gen_random_uuid(),
  quiz_id     uuid not null references public.quizzes(id) on delete cascade,
  prompt      text not null,
  q_type      text not null default 'single'
                check (q_type in ('single','multiple','true_false')),
  explanation text default '',
  hint        text default '',
  sort_order  int not null default 0
);
create index idx_questions_quiz on public.questions(quiz_id, sort_order);

-- Answer options -------------------------------------------------------------
create table public.question_options (
  id          uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete cascade,
  label       text not null,
  is_correct  boolean not null default false,
  sort_order  int not null default 0
);
create index idx_options_question on public.question_options(question_id, sort_order);

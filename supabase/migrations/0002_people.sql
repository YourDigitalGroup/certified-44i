-- ============================================================================
-- 0002_people.sql — Groups, Account Executives, Account Managers
--
-- Auth model (no individual AE logins):
--   * Each GROUP is backed by one Supabase Auth user (email = group slug,
--     password = the group's shared password). AEs "log in as the group",
--     then pick their name from the group roster. group_accounts links the
--     auth user to the group.
--   * Each AM (3 internal trainers) is a Supabase Auth user with cross-group
--     powers. account_managers links the auth user to the AM record.
--   * AEs are NOT auth users — they are roster rows under a group.
-- ============================================================================

-- Groups (= white-label partners / teams) ------------------------------------
create table public.groups (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null unique,          -- used to build the login email
  name         text not null,
  external_ref text,                          -- id in your unified password system
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create trigger trg_groups_updated before update on public.groups
  for each row execute function public.set_updated_at();

-- Links a Supabase Auth user to the group it represents (group login) ---------
create table public.group_accounts (
  group_id      uuid primary key references public.groups(id) on delete cascade,
  auth_user_id  uuid not null unique references auth.users(id) on delete cascade,
  login_email   text not null unique,
  created_at    timestamptz not null default now()
);

-- Account Executives (learners; hundreds; live under a group) ----------------
create table public.account_executives (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid not null references public.groups(id) on delete cascade,
  full_name    text not null,
  email        text,
  external_ref text,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (group_id, full_name)
);
create index idx_ae_group on public.account_executives(group_id);
create trigger trg_ae_updated before update on public.account_executives
  for each row execute function public.set_updated_at();

-- Account Managers (3 internal trainers; cross-group) ------------------------
create table public.account_managers (
  id           uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  full_name    text not null,
  email        text not null unique,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now()
);

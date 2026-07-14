-- Table: public.users
-- Feature: User
-- Purpose: Store the minimal application profile for an authenticated identity.
-- Responsibilities: Enforce profile shape, account state, ownership, and lifecycle linkage.
-- Notes: Email and credentials remain authoritative in auth.users.

create table public.users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null,
  account_status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint users_display_name_length_check
    check (char_length(display_name) between 2 and 80),
  constraint users_display_name_trimmed_check
    check (display_name = btrim(display_name)),
  constraint users_account_status_check
    check (account_status = 'active')
);

alter table public.users enable row level security;

revoke all on table public.users from anon, authenticated;
grant select on table public.users to authenticated, service_role;
grant insert, update, delete on table public.users to service_role;

create policy users_self_read
on public.users
for select
to authenticated
using (user_id = (select auth.uid()));

-- Function: public.health_check
-- Feature: System
-- Purpose: Verify that the database is reachable through a stable, side-effect-free contract.
-- Responsibilities: Return service status and the current database timestamp.
-- Notes: Uses invoker security and reads no domain or private data.

create or replace function public.health_check()
returns table (
  status text,
  checked_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
  select 'ok'::text, now();
$$;

revoke all on function public.health_check() from public;
grant execute on function public.health_check() to anon, authenticated, service_role;


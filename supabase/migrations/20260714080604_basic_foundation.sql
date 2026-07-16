-- Source: supabase/sql_src/schema/private/00_schema.sql
create schema if not exists private;
revoke all on schema private from anon, authenticated;

-- Source: supabase/sql_src/schema/admin/00_schema.sql
create schema if not exists admin;
revoke all on schema admin from anon, authenticated;

-- Source: supabase/sql_src/schema/analytics/00_schema.sql
create schema if not exists analytics;
revoke all on schema analytics from anon, authenticated;

-- Source: supabase/sql_src/functions/system/health_check.sql
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

#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

cd "$repo_root"

bash scripts/regenerate-supabase-migrations.sh
supabase db reset --local --yes

./node_modules/.bin/prettier --check .
deno fmt --config supabase/functions/deno.json --check supabase/functions
deno check --config supabase/functions/deno.json \
  supabase/functions/v1/system/health/index.ts \
  supabase/functions/v1/user/profile/index.ts \
  supabase/functions/v1/user/account-security/index.ts \
  supabase/functions/v1/user/delete-account/index.ts \
  supabase/functions/v1/city-page/query/index.ts \
  supabase/functions/v1/airport-page/query/index.ts \
  supabase/functions/v1/ingestion/base-data/index.ts
deno test --config supabase/functions/deno.json --allow-read supabase/functions
psql postgresql://postgres:postgres@127.0.0.1:55322/postgres \
  -v ON_ERROR_STOP=1 \
  -f supabase/snippets/e2e_base_data_ingestion.sql

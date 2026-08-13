#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

cd "$repo_root"

bash scripts/regenerate-supabase-migrations.sh
supabase db reset --local --yes

./node_modules/.bin/prettier --check .
deno fmt --config supabase/functions/deno.json --check supabase/functions
pnpm edge:check
deno test --config supabase/functions/deno.json --allow-read supabase/functions
psql postgresql://postgres:postgres@127.0.0.1:55322/postgres \
  -v ON_ERROR_STOP=1 \
  -f supabase/snippets/e2e_base_data_ingestion.sql

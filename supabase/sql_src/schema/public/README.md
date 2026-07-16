# Public schema

Supabase creates `public` by default. Add each future public table as one SQL file in this folder,
for example `airports.sql`. Every exposed table must enable RLS in the same logical migration.

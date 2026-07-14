import { createClient, type SupabaseClient } from '@supabase/supabase-js';

function readRequiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error('ERR_SERVER_CONFIGURATION');
  return value;
}

export function getPublicClient(): SupabaseClient {
  return createClient(
    readRequiredEnv('SUPABASE_URL'),
    readRequiredEnv('SUPABASE_ANON_KEY'),
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

export function getUserClient(jwt: string): SupabaseClient {
  return createClient(
    readRequiredEnv('SUPABASE_URL'),
    readRequiredEnv('SUPABASE_ANON_KEY'),
    {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { authorization: `Bearer ${jwt}` } },
    },
  );
}

export function getServiceRoleClient(): SupabaseClient {
  return createClient(
    readRequiredEnv('SUPABASE_URL'),
    readRequiredEnv('SUPABASE_SERVICE_ROLE_KEY'),
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

import { requireUser } from '@shared/auth.ts';
import { enforceSensitiveCommandRateLimit } from '@shared/rate_limit.ts';
import { getPublicClient, getServiceRoleClient } from '@shared/supabase.ts';
import { handleAccountSecurityRequest } from './handler.ts';
import { executeAccountSecurity } from './service.ts';

Deno.serve((request) =>
  handleAccountSecurityRequest(request, {
    authenticate: requireUser,
    log: (event) => console.info('ACCOUNT_SECURITY_COMMAND', event),
    execute: (command, context) =>
      executeAccountSecurity(
        command,
        { email: context.email, jwt: context.jwt },
        {
          enforceRateLimit: async (action) => {
            await enforceSensitiveCommandRateLimit({
              request: context.request,
              userId: context.userId,
              action,
              consume: async (subjectHash, rateLimitAction) => {
                const result = await getServiceRoleClient().rpc(
                  'consume_auth_command_attempt',
                  { p_subject_hash: subjectHash, p_action: rateLimitAction },
                );
                if (result.error || !isRateLimitResult(result.data)) {
                  throw new Error('ERR_INTERNAL');
                }
                return {
                  allowed: result.data.allowed,
                  remaining: result.data.remaining,
                  resetAt: result.data.reset_at,
                };
              },
            });
          },
          reauthenticate: async (email, password) => {
            const result = await getPublicClient().auth.signInWithPassword({ email, password });
            if (result.error || !result.data.session) {
              throw new Error('ERR_INVALID_CURRENT_PASSWORD');
            }
          },
          updatePassword: async (jwt, password, currentPassword) => {
            await updateAuthUser(jwt, {
              password,
              ...(currentPassword == null ? {} : { current_password: currentPassword }),
            }, 'ERR_AUTH_PASSWORD_UPDATE_FAILED');
          },
          updateEmail: async (jwt, email, currentPassword) => {
            await updateAuthUser(
              jwt,
              { email, current_password: currentPassword },
              'ERR_AUTH_EMAIL_UPDATE_FAILED',
            );
          },
          revokeOtherSessions: async (jwt) => {
            const result = await getServiceRoleClient().auth.admin.signOut(jwt, 'others');
            if (result.error) throw new Error('ERR_AUTH_SESSION_REVOCATION_FAILED');
          },
        },
      ),
  })
);

async function updateAuthUser(
  jwt: string,
  attributes: Record<string, string>,
  failureCode: string,
): Promise<void> {
  const url = Deno.env.get('SUPABASE_URL')?.trim();
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')?.trim();
  if (!url || !anonKey) throw new Error('ERR_SERVER_CONFIGURATION');

  const response = await fetch(`${url}/auth/v1/user`, {
    method: 'PUT',
    headers: {
      apikey: anonKey,
      authorization: `Bearer ${jwt}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(attributes),
  });
  if (!response.ok) throw new Error(failureCode);
}

function isRateLimitResult(
  value: unknown,
): value is { allowed: boolean; remaining: number; reset_at: string } {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const result = value as Record<string, unknown>;
  return typeof result.allowed === 'boolean' &&
    typeof result.remaining === 'number' &&
    typeof result.reset_at === 'string';
}

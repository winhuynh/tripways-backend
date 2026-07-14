import { requireUser } from '@shared/auth.ts';
import { enforceSensitiveCommandRateLimit } from '@shared/rate_limit.ts';
import { getPublicClient, getServiceRoleClient } from '@shared/supabase.ts';
import { handleDeleteAccountRequest } from './handler.ts';
import { executeDeleteAccount } from './service.ts';

Deno.serve((request) =>
  handleDeleteAccountRequest(request, {
    authenticate: requireUser,
    log: (event) => console.info('DELETE_ACCOUNT_COMMAND', event),
    execute: (command, context) =>
      executeDeleteAccount(
        command,
        { userId: context.userId, email: context.email },
        {
          enforceRateLimit: async () => {
            await enforceSensitiveCommandRateLimit({
              request: context.request,
              userId: context.userId,
              action: 'delete_account',
              consume: async (subjectHash, action) => {
                const result = await getServiceRoleClient().rpc(
                  'consume_auth_command_attempt',
                  { p_subject_hash: subjectHash, p_action: action },
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
          deleteAuthUser: async (userId) => {
            const result = await getServiceRoleClient().auth.admin.deleteUser(userId);
            if (!result.error) return 'deleted';
            if (result.error.code === 'user_not_found') return 'not_found';
            throw new Error('ERR_ACCOUNT_DELETE_FAILED');
          },
        },
      ),
  })
);

function isRateLimitResult(
  value: unknown,
): value is { allowed: boolean; remaining: number; reset_at: string } {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const result = value as Record<string, unknown>;
  return typeof result.allowed === 'boolean' &&
    typeof result.remaining === 'number' &&
    typeof result.reset_at === 'string';
}

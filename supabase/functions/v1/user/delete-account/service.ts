import type { DeleteAccountRequest } from './request.ts';

export type DeleteAccountDependencies = {
  enforceRateLimit(): Promise<void>;
  reauthenticate(email: string, password: string): Promise<void>;
  deleteAuthUser(userId: string): Promise<'deleted' | 'not_found'>;
};

export async function executeDeleteAccount(
  request: DeleteAccountRequest,
  context: { userId: string; email: string },
  dependencies: DeleteAccountDependencies,
): Promise<{ messageCode: 'ACCOUNT_DELETED' }> {
  await dependencies.enforceRateLimit();
  await dependencies.reauthenticate(context.email, request.currentPassword);
  await dependencies.deleteAuthUser(context.userId);
  return { messageCode: 'ACCOUNT_DELETED' };
}

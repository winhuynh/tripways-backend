import type { AccountSecurityRequest } from './request.ts';

export type AccountSecurityContext = {
  email: string;
  jwt: string;
};

export type AccountSecurityDependencies = {
  enforceRateLimit(action: AccountSecurityRequest['action']): Promise<void>;
  reauthenticate(email: string, password: string): Promise<void>;
  updatePassword(jwt: string, password: string, currentPassword?: string): Promise<void>;
  updateEmail(jwt: string, email: string, currentPassword: string): Promise<void>;
  revokeOtherSessions(jwt: string): Promise<void>;
};

export async function executeAccountSecurity(
  request: AccountSecurityRequest,
  context: AccountSecurityContext,
  dependencies: AccountSecurityDependencies,
): Promise<{ messageCode: string }> {
  await dependencies.enforceRateLimit(request.action);

  if (request.action === 'password_changed') {
    await dependencies.reauthenticate(context.email, request.currentPassword);
    await dependencies.updatePassword(
      context.jwt,
      request.newPassword,
      request.currentPassword,
    );
    await dependencies.revokeOtherSessions(context.jwt);
    return { messageCode: 'PASSWORD_CHANGED' };
  }

  if (request.action === 'password_recovered') {
    await dependencies.updatePassword(context.jwt, request.newPassword);
    await dependencies.revokeOtherSessions(context.jwt);
    return { messageCode: 'PASSWORD_RECOVERED' };
  }

  await dependencies.reauthenticate(context.email, request.currentPassword);
  await dependencies.updateEmail(context.jwt, request.newEmail, request.currentPassword);
  await dependencies.revokeOtherSessions(context.jwt);
  return { messageCode: 'EMAIL_CHANGE_REQUESTED' };
}

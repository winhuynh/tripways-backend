import type { AuthenticatedRequest } from '@shared/auth.ts';
import { assertMethod, errorResponse, readJson, successResponse } from '@shared/edge.ts';
import { type AccountSecurityRequest, parseAccountSecurityRequest } from './request.ts';

export type AccountSecurityHandlerContext = {
  userId: string;
  email: string;
  jwt: string;
  request: Request;
};

export type AccountSecurityHandlerDependencies = {
  authenticate(request: Request): Promise<AuthenticatedRequest>;
  execute(
    command: AccountSecurityRequest,
    context: AccountSecurityHandlerContext,
  ): Promise<{ messageCode: string }>;
  log(event: AccountSecurityLogEvent): void;
};

export type AccountSecurityLogEvent = {
  client_request_id: string | null;
  action: string | null;
  status: 'succeeded' | 'failed';
  processed_at: string;
  user_id: string | null;
  error_code: string | null;
};

export async function handleAccountSecurityRequest(
  request: Request,
  dependencies: AccountSecurityHandlerDependencies,
): Promise<Response> {
  const methodError = assertMethod(request, ['POST']);
  if (methodError) return methodError;

  let action: string | null = null;
  let userId: string | null = null;
  const clientRequestId = request.headers.get('x-client-request-id')?.slice(0, 100) ?? null;
  try {
    const authenticated = await dependencies.authenticate(request);
    userId = authenticated.user.id;
    const email = authenticated.user.email?.trim();
    if (!email) throw new Error('ERR_AUTH_EMAIL_REQUIRED');

    const command = parseAccountSecurityRequest(await readJson(request));
    action = command.action;
    const result = await dependencies.execute(command, {
      userId: authenticated.user.id,
      email,
      jwt: authenticated.jwt,
      request,
    });

    dependencies.log({
      client_request_id: clientRequestId,
      action,
      status: 'succeeded',
      processed_at: new Date().toISOString(),
      user_id: userId,
      error_code: null,
    });
    return successResponse({ message_code: result.messageCode });
  } catch (error) {
    const errorCode = error instanceof Error && error.message.startsWith('ERR_')
      ? error.message
      : 'ERR_INTERNAL';
    dependencies.log({
      client_request_id: clientRequestId,
      action,
      status: 'failed',
      processed_at: new Date().toISOString(),
      user_id: userId,
      error_code: errorCode,
    });
    return errorResponse(error);
  }
}

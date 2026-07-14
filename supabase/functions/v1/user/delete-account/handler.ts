import type { AuthenticatedRequest } from '@shared/auth.ts';
import { assertMethod, errorResponse, readJson, successResponse } from '@shared/edge.ts';
import { type DeleteAccountRequest, parseDeleteAccountRequest } from './request.ts';

export type DeleteAccountLogEvent = {
  client_request_id: string | null;
  action: 'delete_account';
  status: 'succeeded' | 'failed';
  processed_at: string;
  user_id: string | null;
  error_code: string | null;
};

export type DeleteAccountHandlerDependencies = {
  authenticate(request: Request): Promise<AuthenticatedRequest>;
  execute(
    command: DeleteAccountRequest,
    context: { userId: string; email: string; request: Request },
  ): Promise<{ messageCode: string }>;
  log(event: DeleteAccountLogEvent): void;
};

export async function handleDeleteAccountRequest(
  request: Request,
  dependencies: DeleteAccountHandlerDependencies,
): Promise<Response> {
  const methodError = assertMethod(request, ['POST']);
  if (methodError) return methodError;

  let userId: string | null = null;
  const clientRequestId = request.headers.get('x-client-request-id')?.slice(0, 100) ?? null;
  try {
    const authenticated = await dependencies.authenticate(request);
    userId = authenticated.user.id;
    const email = authenticated.user.email?.trim();
    if (!email) throw new Error('ERR_AUTH_EMAIL_REQUIRED');
    const command = parseDeleteAccountRequest(await readJson(request));
    const result = await dependencies.execute(command, { userId, email, request });

    dependencies.log({
      client_request_id: clientRequestId,
      action: 'delete_account',
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
      action: 'delete_account',
      status: 'failed',
      processed_at: new Date().toISOString(),
      user_id: userId,
      error_code: errorCode,
    });
    return errorResponse(error);
  }
}

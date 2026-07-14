import type { AuthenticatedRequest } from '@shared/auth.ts';
import { assertMethod, errorResponse, jsonResponse, readJson } from '@shared/edge.ts';
import { parseProfilePatch, type ProfilePatch } from './request.ts';

export type ProfileRpcEnvelope = {
  status: 'success' | 'error';
  data: unknown;
  error: { code: string } | null;
  message_code: string;
};

export type ProfileDependencies = {
  authenticate(request: Request): Promise<AuthenticatedRequest>;
  readProfile(jwt: string): Promise<ProfileRpcEnvelope>;
  updateProfile(userId: string, input: ProfilePatch): Promise<ProfileRpcEnvelope>;
};

export async function handleProfileRequest(
  request: Request,
  dependencies: ProfileDependencies,
): Promise<Response> {
  const methodError = assertMethod(request, ['GET', 'PATCH']);
  if (methodError) return methodError;

  try {
    const authenticated = await dependencies.authenticate(request);
    const result = request.method === 'GET'
      ? await dependencies.readProfile(authenticated.jwt)
      : await dependencies.updateProfile(
        authenticated.user.id,
        parseProfilePatch(await readJson(request)),
      );

    if (result.status === 'error') {
      return errorResponse(new Error(result.error?.code ?? 'ERR_INTERNAL'));
    }
    return jsonResponse(result);
  } catch (error) {
    return errorResponse(error);
  }
}

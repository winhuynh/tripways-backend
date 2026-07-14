import { getPublicClient } from './supabase.ts';

export type AuthenticatedUser = {
  id: string;
  email?: string | null;
  app_metadata?: Record<string, unknown>;
};

export type AuthVerifier = {
  getUser(token: string): Promise<{
    data: { user: AuthenticatedUser | null };
    error: unknown;
  }>;
};

export type AuthenticatedRequest = {
  user: AuthenticatedUser;
  jwt: string;
};

export async function requireUser(
  request: Request,
  verifier: AuthVerifier = getPublicClient().auth,
): Promise<AuthenticatedRequest> {
  const authorization = request.headers.get('authorization');
  if (!authorization?.toLowerCase().startsWith('bearer ')) {
    throw new Error('ERR_UNAUTHORIZED');
  }

  const jwt = authorization.slice(7).trim();
  if (!jwt) throw new Error('ERR_UNAUTHORIZED');

  const result = await verifier.getUser(jwt);
  if (result.error || !result.data.user) {
    throw new Error('ERR_UNAUTHORIZED');
  }

  return { user: result.data.user, jwt };
}

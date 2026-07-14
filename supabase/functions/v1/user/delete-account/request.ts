export type DeleteAccountRequest = { currentPassword: string };

export function parseDeleteAccountRequest(value: unknown): DeleteAccountRequest {
  if (!isRecord(value)) throw new Error('ERR_DELETE_ACCOUNT_REQUEST_INVALID');
  const keys = Object.keys(value);
  if (keys.length !== 1 || keys[0] !== 'current_password') {
    if (!('current_password' in value)) {
      throw new Error('ERR_CURRENT_PASSWORD_REQUIRED');
    }
    throw new Error('ERR_DELETE_ACCOUNT_REQUEST_INVALID');
  }
  if (typeof value.current_password !== 'string' || value.current_password.length === 0) {
    throw new Error('ERR_CURRENT_PASSWORD_REQUIRED');
  }
  return { currentPassword: value.current_password };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export type AccountSecurityRequest =
  | {
    action: 'password_changed';
    currentPassword: string;
    newPassword: string;
  }
  | {
    action: 'password_recovered';
    newPassword: string;
  }
  | {
    action: 'email_changed';
    currentPassword: string;
    newEmail: string;
  };

export function parseAccountSecurityRequest(value: unknown): AccountSecurityRequest {
  if (!isRecord(value) || typeof value.action !== 'string') {
    throw new Error('ERR_ACCOUNT_SECURITY_REQUEST_INVALID');
  }

  if (value.action === 'password_changed') {
    assertExactKeys(value, ['action', 'current_password', 'new_password']);
    const currentPassword = readSecret(value.current_password, 'ERR_CURRENT_PASSWORD_REQUIRED');
    const newPassword = readSecret(value.new_password, 'ERR_PASSWORD_INVALID');
    assertNewPassword(newPassword);
    return { action: value.action, currentPassword, newPassword };
  }

  if (value.action === 'password_recovered') {
    assertExactKeys(value, ['action', 'new_password']);
    const newPassword = readSecret(value.new_password, 'ERR_PASSWORD_INVALID');
    assertNewPassword(newPassword);
    return { action: value.action, newPassword };
  }

  if (value.action === 'email_changed') {
    assertExactKeys(value, ['action', 'current_password', 'new_email']);
    const currentPassword = readSecret(value.current_password, 'ERR_CURRENT_PASSWORD_REQUIRED');
    const newEmail = readEmail(value.new_email);
    return { action: value.action, currentPassword, newEmail };
  }

  throw new Error('ERR_ACCOUNT_SECURITY_REQUEST_INVALID');
}

function assertNewPassword(value: string): void {
  const length = Array.from(value).length;
  if (
    length < 8 || length > 72 ||
    !/[a-z]/.test(value) ||
    !/[A-Z]/.test(value) ||
    !/[0-9]/.test(value)
  ) {
    throw new Error('ERR_PASSWORD_INVALID');
  }
}

function readSecret(value: unknown, code: string): string {
  if (typeof value !== 'string' || value.length === 0) throw new Error(code);
  return value;
}

function readEmail(value: unknown): string {
  if (typeof value !== 'string') throw new Error('ERR_EMAIL_INVALID');
  const email = value.trim();
  if (
    email.length === 0 ||
    Array.from(email).length > 254 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) {
    throw new Error('ERR_EMAIL_INVALID');
  }
  return email;
}

function assertExactKeys(value: Record<string, unknown>, expected: string[]): void {
  const actual = Object.keys(value).sort();
  const required = [...expected].sort();
  if (actual.length !== required.length || actual.some((key, index) => key !== required[index])) {
    throw new Error('ERR_ACCOUNT_SECURITY_REQUEST_INVALID');
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

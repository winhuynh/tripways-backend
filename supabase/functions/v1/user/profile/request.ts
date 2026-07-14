export type ProfilePatch = { displayName: string };

export function parseProfilePatch(value: unknown): ProfilePatch {
  if (!isRecord(value) || Object.keys(value).length !== 1) {
    throw new Error('ERR_PROFILE_REQUEST_INVALID');
  }
  if (typeof value.display_name !== 'string') {
    throw new Error('ERR_DISPLAY_NAME_INVALID');
  }

  const displayName = value.display_name.trim();
  const length = Array.from(displayName).length;
  if (length < 2 || length > 80) {
    throw new Error('ERR_DISPLAY_NAME_INVALID');
  }

  return { displayName };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

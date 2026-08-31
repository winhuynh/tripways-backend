export type RateLimitDecision = {
  allowed: boolean;
  remaining: number;
  resetAt: string;
};

export type RateLimitConsumer = (
  subjectHash: string,
  action: string,
) => Promise<RateLimitDecision>;

export async function buildRateLimitSubjectHashes(
  subjectId: string,
  request: Request,
): Promise<[string, string]> {
  const forwardedFor = request.headers.get('x-forwarded-for');
  const clientIp = forwardedFor?.split(',')[0]?.trim() || 'local-unknown';

  return [
    await sha256(`subject:${subjectId}`),
    await sha256(`ip:${clientIp}`),
  ];
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

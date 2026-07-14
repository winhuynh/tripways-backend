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
  userId: string,
  request: Request,
): Promise<[string, string]> {
  const forwardedFor = request.headers.get('x-forwarded-for');
  const clientIp = forwardedFor?.split(',')[0]?.trim() || 'local-unknown';

  return [
    await sha256(`user:${userId}`),
    await sha256(`ip:${clientIp}`),
  ];
}

export async function enforceSensitiveCommandRateLimit(input: {
  request: Request;
  userId: string;
  action: string;
  consume: RateLimitConsumer;
}): Promise<RateLimitDecision[]> {
  const subjects = await buildRateLimitSubjectHashes(input.userId, input.request);
  const decisions = await Promise.all(
    subjects.map((subject) => input.consume(subject, input.action)),
  );

  if (decisions.some((decision) => !decision.allowed)) {
    throw new Error('ERR_RATE_LIMITED');
  }
  return decisions;
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

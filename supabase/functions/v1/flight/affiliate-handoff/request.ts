export type AffiliateHandoffRequest =
  | { type: 'observation'; observationRef: string }
  | {
    type: 'fallback_search';
    originIata: string;
    destIata: string;
    departureDate?: string;
    locale?: string;
  };

export function parseAffiliateHandoffRequest(value: unknown): AffiliateHandoffRequest {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new Error('ERR_INVALID_REQUEST');
  }

  const input = value as Record<string, unknown>;
  const keys = Object.keys(input);

  if ('observationRef' in input) {
    if (
      keys.length !== 1 ||
      typeof input.observationRef !== 'string' ||
      !/^obs_[0-9a-f]{32}$/.test(input.observationRef)
    ) {
      throw new Error('ERR_INVALID_REQUEST');
    }
    return {
      type: 'observation',
      observationRef: input.observationRef,
    };
  }

  if ('originIata' in input && 'destIata' in input) {
    const allowedKeys = new Set(['originIata', 'destIata', 'departureDate', 'locale']);
    if (keys.some((k) => !allowedKeys.has(k))) {
      throw new Error('ERR_INVALID_REQUEST');
    }

    if (
      typeof input.originIata !== 'string' ||
      !/^[A-Z]{3}$/.test(input.originIata) ||
      typeof input.destIata !== 'string' ||
      !/^[A-Z]{3}$/.test(input.destIata)
    ) {
      throw new Error('ERR_INVALID_REQUEST');
    }

    const result: AffiliateHandoffRequest = {
      type: 'fallback_search',
      originIata: input.originIata,
      destIata: input.destIata,
    };

    if (input.departureDate !== undefined) {
      if (
        typeof input.departureDate !== 'string' ||
        !/^\d{4}-\d{2}-\d{2}$/.test(input.departureDate)
      ) {
        throw new Error('ERR_INVALID_REQUEST');
      }
      const match = input.departureDate.match(/^(\d{4})-(\d{2})-(\d{2})$/);
      if (!match) {
        throw new Error('ERR_INVALID_REQUEST');
      }
      const year = parseInt(match[1]!, 10);
      const month = parseInt(match[2]!, 10);
      const day = parseInt(match[3]!, 10);
      const date = new Date(Date.UTC(year, month - 1, day));
      if (
        date.getUTCFullYear() !== year ||
        date.getUTCMonth() !== month - 1 ||
        date.getUTCDate() !== day
      ) {
        throw new Error('ERR_INVALID_REQUEST');
      }
      result.departureDate = input.departureDate;
    }

    if (input.locale !== undefined) {
      if (
        typeof input.locale !== 'string' ||
        !/^[a-zA-Z]{2,3}(?:-[a-zA-Z0-9]{2,8})?$/.test(input.locale.trim())
      ) {
        throw new Error('ERR_INVALID_REQUEST');
      }
      result.locale = input.locale.trim();
    }

    return result;
  }

  throw new Error('ERR_INVALID_REQUEST');
}

export type HomepageOriginRpcInput = Readonly<{
  latitude?: number;
  longitude?: number;
}>;

const HEADER_PAIRS = [
  ['x-tripways-geo-latitude', 'x-tripways-geo-longitude'],
  ['x-vercel-ip-latitude', 'x-vercel-ip-longitude'],
] as const;

/** Reads platform-provided, IP-derived coordinates without retaining the raw IP. */
export function readVisitorCoordinates(headers: Headers): HomepageOriginRpcInput {
  for (const [latitudeHeader, longitudeHeader] of HEADER_PAIRS) {
    const latitude = parseCoordinate(headers.get(latitudeHeader), -90, 90);
    const longitude = parseCoordinate(headers.get(longitudeHeader), -180, 180);

    if (latitude !== null && longitude !== null) {
      return { latitude, longitude };
    }
  }

  return {};
}

function parseCoordinate(value: string | null, minimum: number, maximum: number): number | null {
  if (value === null || value.trim() === '') return null;

  const coordinate = Number(value);
  return Number.isFinite(coordinate) && coordinate >= minimum && coordinate <= maximum
    ? coordinate
    : null;
}

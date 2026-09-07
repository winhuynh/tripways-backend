import { parse } from "https://deno.land/std@0.224.0/dotenv/mod.ts";

let envApiKey = Deno.env.get("AERODATABOX_API_KEY");
if (!envApiKey) {
  try {
    const envFile = await Deno.readTextFile(".env.local");
    const parsed = parse(envFile);
    envApiKey = parsed.AERODATABOX_API_KEY;
  } catch {
    // Ignore missing .env.local
  }
}

const apiKey = envApiKey ?? "cmtrg9rgh0002l104xyxaeoij";
const databaseUrl =
  Deno.env.get("LOCAL_DATABASE_URL") ??
  "postgresql://postgres:postgres@127.0.0.1:55322/postgres";

const airportsToIngest = ["HAN", "SIN"];

console.log(
  `Starting real route ingestion for airports: ${airportsToIngest.join(", ")}`,
);

interface Operator {
  name?: string;
  iata?: string;
  icao?: string;
}

interface Destination {
  iata?: string;
  icao?: string;
  name?: string;
  municipalityName?: string;
  location?: { lat: number; lon: number };
}

interface RouteItem {
  destination?: Destination;
  averageDailyFlights?: number;
  operators?: Operator[];
}

const allRoutes: Record<string, unknown>[] = [];

for (const origin of airportsToIngest) {
  console.log(
    `Fetching direct routes for ${origin} from AeroDataBox (API.market)...`,
  );

  const response = await fetch(
    "https://prod.api.market/api/mcp/aedbx/aerodatabox",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json, text/event-stream",
        "User-Agent": "Tripways/1.0",
        "x-api-market-key": apiKey,
      },
      body: JSON.stringify({
        jsonrpc: "2.0",
        method: "tools/call",
        params: {
          name: "getroutedailystatistics_routesdailycurrent",
          arguments: { code: origin, codeType: "iata" },
        },
        id: 1,
      }),
    },
  );

  if (!response.ok) {
    console.error(
      `Failed to fetch ${origin}: HTTP ${response.status} ${response.statusText}`,
    );
    continue;
  }

  const rawText = await response.text();
  let routesData: RouteItem[] = [];

  for (const line of rawText.split("\n")) {
    if (line.startsWith("data:")) {
      try {
        const payload = JSON.parse(line.slice(5).trim());
        const content = payload?.result?.content;
        if (Array.isArray(content)) {
          for (const c of content) {
            if (typeof c?.text === "string") {
              const parsed = JSON.parse(c.text);
              if (Array.isArray(parsed?.routes)) {
                routesData = parsed.routes;
              }
            }
          }
        }
      } catch (e) {
        console.warn("Parse error for line:", e);
      }
    }
  }

  console.log(`Found ${routesData.length} direct destinations for ${origin}.`);

  const seenKeys = new Set<string>();

  for (const r of routesData) {
    const destIata = r.destination?.iata?.toUpperCase().trim();
    if (!destIata || destIata.length !== 3 || destIata === origin) continue;

    const operators =
      Array.isArray(r.operators) && r.operators.length > 0
        ? r.operators
        : [{ iata: "XX", name: "Scheduled Airline" }];

    for (const op of operators) {
      const airlineIata = (op.iata || "XX").toUpperCase().trim();
      if (airlineIata.length < 2) continue;

      const airlineName = (op.name || airlineIata).trim();
      const sourceRecordId = `aerodatabox-${origin}-${destIata}-${airlineIata}`;
      if (seenKeys.has(sourceRecordId)) continue;
      seenKeys.add(sourceRecordId);

      allRoutes.push({
        origin_iata: origin,
        destination_iata: destIata,
        airline_iata: airlineIata,
        airline_name: airlineName,
        flight_numbers: [],
        flight_duration_minutes: 120,
        distance_km: null,
        days_of_week: [1, 2, 3, 4, 5, 6, 7],
        aircraft_types: [],
        source_record_id: sourceRecordId,
      });
    }
  }
}

console.log(`Total valid route records compiled: ${allRoutes.length}`);

function encodeJson(data: unknown): string {
  const bytes = new TextEncoder().encode(JSON.stringify(data));
  const chunkSize = 8192;
  let binary = "";
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

const base64Payload = encodeJson(allRoutes);

const psqlScript = `
BEGIN;
SELECT admin.ingest_direct_flight_routes_batch(
  'aerodatabox',
  convert_from(decode('${base64Payload}', 'base64'), 'UTF8')::JSONB
);
COMMIT;
`;

const psqlCmd = new Deno.Command("psql", {
  args: [databaseUrl, "-v", "ON_ERROR_STOP=1"],
  stdin: "piped",
  stdout: "piped",
  stderr: "piped",
});

const child = psqlCmd.spawn();
const writer = child.stdin.getWriter();
await writer.write(new TextEncoder().encode(psqlScript));
await writer.close();

const { code, stdout, stderr } = await child.output();
const outStr = new TextDecoder().decode(stdout);
const errStr = new TextDecoder().decode(stderr);

if (code !== 0) {
  console.error("PSQL Ingestion Error:", errStr);
  Deno.exit(1);
}

console.log("PSQL Ingestion Output:", outStr.trim());
console.log("Route ingestion completed successfully!");

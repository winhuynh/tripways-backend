import type {
  CanonicalAirport,
  CanonicalCity,
  CanonicalCountry,
} from "../supabase/functions/v1/ingestion/base-data/provider-contract.ts";

const DATA_DIRECTORY = new URL(
  "../supabase/seed/ourairports/",
  import.meta.url,
);
const databaseUrl =
  Deno.env.get("LOCAL_DATABASE_URL") ??
  "postgresql://postgres:postgres@127.0.0.1:55322/postgres";
const [countries, cities, airports, manifest] = await Promise.all([
  readJson<CanonicalCountry[]>("countries.json"),
  readJson<CanonicalCity[]>("cities.json"),
  readJson<CanonicalAirport[]>("airports.json"),
  readJson<LocalManifest>("manifest.json"),
]);

const occupiedIatas = new Set(
  (
    await query(
      `
      SELECT airport.iata
      FROM public.airports AS airport
      JOIN admin.data_sources AS source
        ON source.id = airport.source_id
      WHERE airport.iata IS NOT NULL
        AND source.code <> 'ourairports'
      ORDER BY airport.iata
    `,
    )
  )
    .split("\n")
    .filter(Boolean),
);
const selectedAirports = airports.filter(
  (airport) => airport.iata !== null && !occupiedIatas.has(airport.iata),
);
const excludedOccupiedIatas = airports
  .map((airport) => airport.iata)
  .filter((iata): iata is string => iata !== null && occupiedIatas.has(iata))
  .sort();
const records = { countries, cities, airports: selectedAirports };
const checksum = await sha256(JSON.stringify(records));
const idempotencyKey = `ourairports-local-${manifest.sources.airports.checksum.slice(0, 20)}`;
const importMetadata = {
  sourceUrl: manifest.sources.airports.url,
  sourceEtag: manifest.sources.airports.etag,
  sourceChecksum: checksum,
  downloadedBytes: manifest.sources.airports.downloadedBytes,
  rawRecordCount: manifest.counts.airports,
  eligibleRecordCount: selectedAirports.length,
  filteredRecordCount: excludedOccupiedIatas.length,
  invalidRecordCount: 0,
  filterVersion: "ourairports-commercial.v1-local-full",
};
const sql = `
  SELECT public.rpc_publish_base_data_batch(
    'ourairports',
    '${idempotencyKey}',
    '${checksum}',
    'base-data.v1',
    ${sqlLiteral(manifest.sources.airports.lastModified)}::TIMESTAMPTZ,
    convert_from(decode('${encodeJson(records)}', 'base64'), 'UTF8')::JSONB,
    convert_from(decode('${encodeJson(importMetadata)}', 'base64'), 'UTF8')::JSONB
  )::TEXT;
`;
const publication = JSON.parse(await query(sql));
console.log(
  JSON.stringify(
    {
      publication,
      countries: countries.length,
      cities: cities.length,
      airportsInFile: airports.length,
      airportsPublished: selectedAirports.length,
      excludedOccupiedIatas,
      checksum,
    },
    null,
    2,
  ),
);

type LocalManifest = {
  sources: {
    airports: {
      url: string;
      checksum: string;
      downloadedBytes: number;
      etag: string | null;
      lastModified: string | null;
    };
  };
  counts: { airports: number };
};

async function readJson<T>(fileName: string): Promise<T> {
  return JSON.parse(
    await Deno.readTextFile(new URL(fileName, DATA_DIRECTORY)),
  ) as T;
}

async function query(sql: string): Promise<string> {
  const child = new Deno.Command("psql", {
    args: [databaseUrl, "-At", "-v", "ON_ERROR_STOP=1"],
    stdin: "piped",
    stdout: "piped",
    stderr: "piped",
  }).spawn();
  const writer = child.stdin.getWriter();
  await writer.write(new TextEncoder().encode(sql));
  await writer.close();
  const output = await child.output();
  if (!output.success) throw new Error(new TextDecoder().decode(output.stderr));
  return new TextDecoder().decode(output.stdout).trim();
}

function encodeJson(value: unknown): string {
  return new TextEncoder().encode(JSON.stringify(value)).toBase64();
}

function sqlLiteral(value: string | null): string {
  if (value === null) return "NULL";
  return `'${value.replaceAll("'", "''")}'`;
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

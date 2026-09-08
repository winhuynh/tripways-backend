import { parse } from "https://deno.land/std@0.224.0/dotenv/mod.ts";

let envDbUrl = Deno.env.get("LOCAL_DATABASE_URL");
if (!envDbUrl) {
  try {
    const envFile = await Deno.readTextFile(".env.local");
    const parsed = parse(envFile);
    envDbUrl = parsed.LOCAL_DATABASE_URL;
  } catch {
    // Ignore missing .env.local
  }
}

const databaseUrl =
  envDbUrl ?? "postgresql://postgres:postgres@127.0.0.1:55322/postgres";

console.log("=== Starting Travelpayouts Airlines Ingestion ===");

// 1. Fetch raw airline dataset from Travelpayouts
console.log("Fetching airlines dataset from Travelpayouts...");
const response = await fetch(
  "https://api.travelpayouts.com/data/en/airlines.json",
);
if (!response.ok) {
  console.error(
    `Failed to fetch airlines: HTTP ${response.status} ${response.statusText}`,
  );
  Deno.exit(1);
}

interface TravelpayoutsAirline {
  code?: string;
  name?: string;
  is_lowcost?: boolean;
}

const rawList: TravelpayoutsAirline[] = await response.json();
console.log(
  `Received ${rawList.length} raw airline records from Travelpayouts.`,
);

// Helper to run psql query
async function query(sql: string): Promise<string> {
  const psqlCmd = new Deno.Command("psql", {
    args: [databaseUrl, "-A", "-t", "-c", sql],
    stdout: "piped",
    stderr: "piped",
  });
  const { code, stdout, stderr } = await psqlCmd.output();
  if (code !== 0) {
    const err = new TextDecoder().decode(stderr);
    throw new Error(`PSQL query failed: ${err}`);
  }
  return new TextDecoder().decode(stdout).trim();
}

// 2. Fetch existing airlines from Postgres to seed used slugs and preserve fixtures
const existingRowsRaw = await query(
  "SELECT coalesce(iata, ''), slug FROM public.airlines;",
);
const existingIataToSlug = new Map<string, string>();
const usedSlugs = new Set<string>();

if (existingRowsRaw) {
  for (const line of existingRowsRaw.split("\n")) {
    const [iata, slug] = line.split("|");
    if (slug) {
      usedSlugs.add(slug.trim());
      if (iata) {
        existingIataToSlug.set(iata.trim().toUpperCase(), slug.trim());
      }
    }
  }
}
console.log(`Loaded ${usedSlugs.size} existing slugs from public.airlines.`);

// Helper to produce a clean kebab-case slug
function slugify(text: string): string {
  const cleaned = text
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "") // remove accents
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-") // non-alphanumeric to hyphen
    .replace(/^-+|-+$/g, ""); // trim hyphens
  return cleaned.length > 0 ? cleaned : "airline";
}

// 3. Normalize and deduplicate
interface CleanAirline {
  iata: string;
  name: string;
  slug: string;
  logo_path: string;
  business_model: "low_cost" | "full_service";
  status: "active";
  source_record_id: string;
}

const cleanAirlines: CleanAirline[] = [];
const iataRegex = /^[A-Z0-9]{2}$/;

for (const item of rawList) {
  const rawCode = item.code?.trim().toUpperCase();
  if (!rawCode || !iataRegex.test(rawCode)) {
    // Skip Cyrillic / invalid codes
    continue;
  }

  const rawName = (item.name?.trim() || rawCode).slice(0, 160);
  const existingSlug = existingIataToSlug.get(rawCode);

  let finalSlug: string;
  if (existingSlug) {
    finalSlug = existingSlug;
  } else {
    let candidate = slugify(rawName);
    if (usedSlugs.has(candidate)) {
      candidate = `${candidate}-${rawCode.toLowerCase()}`;
    }
    let counter = 2;
    while (usedSlugs.has(candidate)) {
      candidate = `${slugify(rawName)}-${rawCode.toLowerCase()}-${counter++}`;
    }
    finalSlug = candidate;
    usedSlugs.add(finalSlug);
  }

  const businessModel = item.is_lowcost === true ? "low_cost" : "full_service";
  const logoPath = `airlines/${rawCode.toLowerCase()}.png`;

  cleanAirlines.push({
    iata: rawCode,
    name: rawName,
    slug: finalSlug,
    logo_path: logoPath,
    business_model: businessModel,
    status: "active",
    source_record_id: `travelpayouts-airline-${rawCode.toLowerCase()}`,
  });
}

console.log(
  `Normalized ${cleanAirlines.length} clean airlines with valid IATA and unique slugs.`,
);

// 4. Encode payload to base64
function encodeJson(data: unknown): string {
  const bytes = new TextEncoder().encode(JSON.stringify(data));
  const chunkSize = 8192;
  let binary = "";
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

const base64Payload = encodeJson(cleanAirlines);

// 5. Ingest via PSQL transaction
const psqlScript = `
BEGIN;

CREATE TEMP TABLE tmp_raw_airlines (
  iata TEXT,
  name TEXT,
  slug TEXT,
  logo_path TEXT,
  business_model TEXT,
  status TEXT,
  source_record_id TEXT
) ON COMMIT DROP;

INSERT INTO tmp_raw_airlines (iata, name, slug, logo_path, business_model, status, source_record_id)
SELECT
  item->>'iata',
  item->>'name',
  item->>'slug',
  item->>'logo_path',
  item->>'business_model',
  item->>'status',
  item->>'source_record_id'
FROM jsonb_array_elements(convert_from(decode('${base64Payload}', 'base64'), 'UTF8')::jsonb) AS item;

-- Upsert into public.airlines
INSERT INTO public.airlines (
  iata, name, slug, logo_path, business_model, status, source_id, source_record_id
)
SELECT
  tmp.iata,
  tmp.name,
  tmp.slug,
  tmp.logo_path,
  tmp.business_model,
  tmp.status,
  s.id,
  tmp.source_record_id
FROM tmp_raw_airlines tmp
CROSS JOIN (
  SELECT id FROM admin.data_sources WHERE code = 'travelpayouts' LIMIT 1
) s
ON CONFLICT (iata) WHERE iata IS NOT NULL
DO UPDATE SET
  name = EXCLUDED.name,
  slug = CASE
    WHEN public.airlines.source_id = (SELECT id FROM admin.data_sources WHERE code = 'route_discovery_fixture') THEN public.airlines.slug
    ELSE EXCLUDED.slug
  END,
  logo_path = EXCLUDED.logo_path,
  business_model = EXCLUDED.business_model,
  status = EXCLUDED.status,
  updated_at = now();

-- Update direct flight routes to link to airline_id where currently null
UPDATE public.direct_flight_routes r
SET airline_id = al.id
FROM public.airlines al
WHERE r.airline_id IS NULL AND al.iata = r.airline_iata;

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

console.log("PSQL Output:", outStr.trim());

// Summary query
const countSummary = await query(`
  SELECT json_build_object(
    'total_airlines', (SELECT count(*) FROM public.airlines),
    'airlines_with_logo', (SELECT count(*) FROM public.airlines WHERE logo_path IS NOT NULL),
    'linked_routes', (SELECT count(*) FROM public.direct_flight_routes WHERE airline_id IS NOT NULL)
  )::text;
`);

console.log("Ingestion summary:", countSummary);
console.log("=== Travelpayouts Airlines Ingestion completed successfully! ===");

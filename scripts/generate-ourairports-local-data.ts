import { buildOurAirportsLocalDataset } from "../supabase/functions/v1/ingestion/base-data/providers/ourairports-local-dataset.ts";

const AIRPORTS_URL =
  "https://davidmegginson.github.io/ourairports-data/airports.csv";
const COUNTRIES_URL =
  "https://davidmegginson.github.io/ourairports-data/countries.csv";
const COUNTRY_CODES_URL =
  "https://raw.githubusercontent.com/datasets/country-codes/main/data/country-codes.csv";
const OUTPUT_DIRECTORY = new URL(
  "../supabase/seed/ourairports/",
  import.meta.url,
);

const [airportsSource, countriesSource, countryCodesSource] = await Promise.all(
  [
    fetchSource(AIRPORTS_URL, 25_000_000),
    fetchSource(COUNTRIES_URL, 1_000_000),
    fetchSource(COUNTRY_CODES_URL, 2_000_000),
  ],
);
const denylist = await readDenylist();
const countryCodeOverrides = await readCountryCodeOverrides();
const result = buildOurAirportsLocalDataset({
  airportsCsv: airportsSource.content,
  countriesCsv: countriesSource.content,
  countryCodesCsv: countryCodesSource.content,
  countryCodeOverrides,
  denylist,
});
if (!result.ok) {
  throw new Error(
    `ERR_UNRESOLVED_AIRPORT_COUNTRY:${result.unresolvedAirportCountryIso2.join(",")}`,
  );
}

await Deno.mkdir(OUTPUT_DIRECTORY, { recursive: true });
await Promise.all([
  writeJson("countries.json", result.dataset.countries),
  writeJson("cities.json", result.dataset.cities),
  writeJson("airports.json", result.dataset.airports),
]);
const generatedChecksum = await sha256(JSON.stringify(result.dataset));
const manifest = {
  schemaVersion: "ourairports-local.v1",
  generatedAt: new Date().toISOString(),
  filterVersion: "ourairports-commercial.v1",
  sources: {
    airports: sourceManifest(airportsSource),
    countries: sourceManifest(countriesSource),
    countryCodes: sourceManifest(countryCodesSource),
  },
  denylist: [...denylist].sort(),
  countryCodeOverrides,
  generatedChecksum,
  ...result.manifest,
};
await writeJson("manifest.json", manifest);
console.log(JSON.stringify(manifest, null, 2));

type DownloadedSource = {
  url: string;
  content: string;
  downloadedBytes: number;
  checksum: string;
  etag: string | null;
  lastModified: string | null;
};

async function fetchSource(
  urlValue: string,
  maxBytes: number,
): Promise<DownloadedSource> {
  const url = new URL(urlValue);
  if (url.protocol !== "https:") throw new Error("ERR_SOURCE_URL_INVALID");
  const response = await fetch(url, { redirect: "error" });
  if (!response.ok)
    throw new Error(`ERR_SOURCE_DOWNLOAD_FAILED:${response.status}`);
  const declaredBytes = Number(response.headers.get("content-length"));
  if (Number.isFinite(declaredBytes) && declaredBytes > maxBytes) {
    throw new Error("ERR_SOURCE_DOWNLOAD_TOO_LARGE");
  }
  const content = await response.text();
  const downloadedBytes = new TextEncoder().encode(content).byteLength;
  if (downloadedBytes > maxBytes)
    throw new Error("ERR_SOURCE_DOWNLOAD_TOO_LARGE");
  return {
    url: url.toString(),
    content,
    downloadedBytes,
    checksum: await sha256(content),
    etag: response.headers.get("etag"),
    lastModified: response.headers.get("last-modified"),
  };
}

async function readDenylist(): Promise<Set<string>> {
  try {
    const values: unknown = JSON.parse(
      await Deno.readTextFile(new URL("denylist.json", OUTPUT_DIRECTORY)),
    );
    if (
      !Array.isArray(values) ||
      values.some((value) => typeof value !== "string")
    ) {
      throw new Error("ERR_DENYLIST_INVALID");
    }
    return new Set(values.map((value) => value.trim().toUpperCase()));
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return new Set();
    throw error;
  }
}

async function readCountryCodeOverrides(): Promise<Record<string, string>> {
  const values: unknown = JSON.parse(
    await Deno.readTextFile(
      new URL("country-code-overrides.json", OUTPUT_DIRECTORY),
    ),
  );
  if (typeof values !== "object" || values === null || Array.isArray(values)) {
    throw new Error("ERR_COUNTRY_CODE_OVERRIDES_INVALID");
  }
  const overrides = values as Record<string, unknown>;
  if (Object.values(overrides).some((value) => typeof value !== "string")) {
    throw new Error("ERR_COUNTRY_CODE_OVERRIDES_INVALID");
  }
  return Object.fromEntries(
    Object.entries(overrides).map(([iso2, iso3]) => [iso2, String(iso3)]),
  );
}

async function writeJson(fileName: string, value: unknown): Promise<void> {
  await Deno.writeTextFile(
    new URL(fileName, OUTPUT_DIRECTORY),
    `${JSON.stringify(value, null, 2)}\n`,
  );
}

function sourceManifest(
  source: DownloadedSource,
): Omit<DownloadedSource, "content"> {
  const { content: _content, ...manifest } = source;
  return manifest;
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

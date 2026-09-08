#!/usr/bin/env -S deno run --allow-read --allow-write --allow-env --allow-run

import { parseArgs } from "https://deno.land/std@0.224.0/cli/parse_args.ts";
import {
  resolve,
  fromFileUrl,
} from "https://deno.land/std@0.224.0/path/mod.ts";

const currentDir = resolve(fromFileUrl(new URL(".", import.meta.url)));
const repoRoot = resolve(currentDir, "..");

const args = parseArgs(Deno.args, {
  boolean: ["apply", "help"],
  string: ["input", "migration-output", "seed-output", "db-url", "environment"],
  alias: { a: "apply", h: "help", i: "input", e: "environment" },
});

if (args.help) {
  console.log(`
Usage: deno run --allow-read --allow-write --allow-env --allow-run generate_content_migration.ts [options]

Options:
  -i, --input             Path to content JSON file or directory (default: content/{cities,airports,routes})
  --migration-output      Path to output migration SQL file (default: supabase/migrations/20260714081100_editorial_content.sql)
  --seed-output           Path to output seed SQL file (default: supabase/seed/editorial_content.sql)
  -e, --environment       Environment / source_type for publication (default: development_fixture)
  -a, --apply             Execute the generated SQL directly on local database (via psql)
  --db-url                PostgreSQL connection string (default: from LOCAL_DATABASE_URL or default local Supabase)
  -h, --help              Show this help message
`);
  Deno.exit(0);
}

const defaultCitiesDir = resolve(currentDir, "cities");
const defaultAirportsDir = resolve(currentDir, "airports");
const defaultRoutesDir = resolve(currentDir, "routes");

const migrationOutput = args["migration-output"]
  ? resolve(args["migration-output"])
  : resolve(
      repoRoot,
      "supabase/migrations/20260714081100_editorial_content.sql",
    );
const seedOutput = args["seed-output"]
  ? resolve(args["seed-output"])
  : resolve(repoRoot, "supabase/seed/editorial_content.sql");

interface CityItem {
  page_type?: string;
  slug: string;
  locale?: string;
  name?: string;
  iata?: string;
  content: Record<string, unknown>;
}

interface AirportItem {
  page_type?: string;
  iata: string;
  slug: string;
  locale?: string;
  name?: string;
  content: Record<string, unknown>;
}

interface RouteItem {
  page_type?: string;
  slug: string;
  locale?: string;
  content: Record<string, unknown>;
}

async function loadJsonFilesFromDir(dirPath: string): Promise<any[]> {
  const items: any[] = [];
  async function scan(current: string) {
    try {
      for await (const entry of Deno.readDir(current)) {
        const fullPath = resolve(current, entry.name);
        if (entry.isDirectory) {
          await scan(fullPath);
        } else if (entry.isFile && entry.name.endsWith(".json")) {
          const text = await Deno.readTextFile(fullPath);
          try {
            items.push(JSON.parse(text));
          } catch (err) {
            console.warn(`Warning: Failed to parse ${fullPath}:`, err);
          }
        }
      }
    } catch {
      // Directory might not exist or be accessible
    }
  }
  await scan(dirPath);
  return items;
}

const cities: CityItem[] = [];
const airports: AirportItem[] = [];
const routes: RouteItem[] = [];
let sourceDescription = "content/{cities,airports,routes}/**/*.json";

if (args.input) {
  const inputPath = resolve(args.input);
  const stat = await Deno.stat(inputPath);
  if (stat.isDirectory) {
    sourceDescription = `${inputPath}/**/*`;
    cities.push(...(await loadJsonFilesFromDir(resolve(inputPath, "cities"))));
    airports.push(
      ...(await loadJsonFilesFromDir(resolve(inputPath, "airports"))),
    );
    routes.push(...(await loadJsonFilesFromDir(resolve(inputPath, "routes"))));
  } else {
    sourceDescription = inputPath.split("/").pop() || inputPath;
    console.log(`Reading editorial content from file: ${inputPath}`);
    const rawJson = await Deno.readTextFile(inputPath);
    const parsed = JSON.parse(rawJson);
    if (
      Array.isArray(parsed.cities) ||
      Array.isArray(parsed.airports) ||
      Array.isArray(parsed.routes)
    ) {
      if (Array.isArray(parsed.cities)) cities.push(...parsed.cities);
      if (Array.isArray(parsed.airports)) airports.push(...parsed.airports);
      if (Array.isArray(parsed.routes)) routes.push(...parsed.routes);
    } else if (parsed.page_type === "city") {
      cities.push(parsed);
    } else if (parsed.page_type === "airport") {
      airports.push(parsed);
    } else if (parsed.page_type === "route") {
      routes.push(parsed);
    }
  }
} else {
  console.log(`Scanning modular directories:`);
  console.log(` - Cities:   ${defaultCitiesDir}`);
  console.log(` - Airports: ${defaultAirportsDir}`);
  console.log(` - Routes:   ${defaultRoutesDir}`);

  cities.push(...(await loadJsonFilesFromDir(defaultCitiesDir)));
  airports.push(...(await loadJsonFilesFromDir(defaultAirportsDir)));
  routes.push(...(await loadJsonFilesFromDir(defaultRoutesDir)));
}

// Sort deterministically
cities.sort((a, b) => a.slug.localeCompare(b.slug));
airports.sort((a, b) => (a.iata || a.slug).localeCompare(b.iata || b.slug));
routes.sort((a, b) => a.slug.localeCompare(b.slug));

console.log(
  `Found ${cities.length} cities, ${airports.length} airports, ${routes.length} routes.`,
);

const sqlStatements: string[] = [];

sqlStatements.push(
  `-- ============================================================================`,
);
sqlStatements.push(`-- Editorial Content Seed / Migration`);
sqlStatements.push(`-- Source: ${sourceDescription}`);
sqlStatements.push(
  `-- Total: ${cities.length} cities, ${airports.length} airports, ${routes.length} routes`,
);
sqlStatements.push(`-- Generated at: ${new Date().toISOString()}`);
sqlStatements.push(
  `-- ============================================================================\n`,
);
sqlStatements.push(`BEGIN;\n`);

// 1. Update Cities
for (const city of cities) {
  const slug = city.slug;
  const locale = city.locale || "en-GB";
  const safeTag = slug.replace(/[^a-zA-Z0-9_]/g, "_");
  const jsonStr = JSON.stringify(city.content);
  sqlStatements.push(`-- City Hub: ${slug} (${locale})`);
  sqlStatements.push(`UPDATE public.city_pages`);
  sqlStatements.push(`SET`);
  sqlStatements.push(
    `  content = $CITY_${safeTag}$${jsonStr}$CITY_${safeTag}$::jsonb,`,
  );
  sqlStatements.push(`  content_reviewed_at = now()`);
  sqlStatements.push(`WHERE pseo_page_id = (`);
  sqlStatements.push(
    `  SELECT id FROM public.pseo_pages WHERE entity_key = '${slug}' AND page_type = 'city' LIMIT 1`,
  );
  sqlStatements.push(`) AND locale = '${locale}';\n`);
}

// 2. Update Airports
for (const airport of airports) {
  const iata = (airport.iata || "").toLowerCase();
  const locale = airport.locale || "en-GB";
  const safeTag = (airport.slug || iata).replace(/[^a-zA-Z0-9_]/g, "_");
  const jsonStr = JSON.stringify(airport.content);
  sqlStatements.push(
    `-- Airport Hub: ${airport.iata} (${airport.slug}) [${locale}]`,
  );
  sqlStatements.push(`UPDATE public.airport_pages`);
  sqlStatements.push(`SET`);
  sqlStatements.push(
    `  content = $AIRPORT_${safeTag}$${jsonStr}$AIRPORT_${safeTag}$::jsonb,`,
  );
  sqlStatements.push(`  content_reviewed_at = now()`);
  sqlStatements.push(`WHERE pseo_page_id = (`);
  sqlStatements.push(
    `  SELECT id FROM public.pseo_pages WHERE entity_key = '${iata}' AND page_type = 'airport' LIMIT 1`,
  );
  sqlStatements.push(`) AND locale = '${locale}';\n`);
}

// 3. Update Routes
for (const route of routes) {
  const slug = route.slug;
  const locale = route.locale || "en-GB";
  const jsonStr = JSON.stringify(route.content);
  const safeTag = slug.replace(/[^a-zA-Z0-9_]/g, "_");
  sqlStatements.push(`-- Route Page: ${slug} (${locale})`);
  sqlStatements.push(`UPDATE public.route_pages`);
  sqlStatements.push(`SET`);
  sqlStatements.push(
    `  content = $ROUTE_${safeTag}$${jsonStr}$ROUTE_${safeTag}$::jsonb,`,
  );
  sqlStatements.push(`  content_reviewed_at = now()`);
  sqlStatements.push(`WHERE pseo_page_id = (`);
  sqlStatements.push(
    `  SELECT id FROM public.pseo_pages WHERE entity_key = '${slug}' AND page_type = 'city_route' LIMIT 1`,
  );
  sqlStatements.push(`) AND locale = '${locale}';\n`);
}

// 4. Refresh read models for current version
const environment = (args.environment || "development_fixture").replace(
  /[^a-zA-Z0-9_]/g,
  "",
);
sqlStatements.push(
  `-- Refresh publication read models to reflect updated editorial content`,
);
sqlStatements.push(
  `SELECT public.publish_read_model_version('${environment}');\n`,
);
sqlStatements.push(`COMMIT;\n`);

const finalSql = sqlStatements.join("\n");

// Write to seed location
await Deno.writeTextFile(seedOutput, finalSql);
console.log(`✓ Generated seed file: ${seedOutput}`);

// Write to migration location
await Deno.writeTextFile(migrationOutput, finalSql);
console.log(`✓ Generated migration file: ${migrationOutput}`);

// If --apply flag is given, apply directly to local database
if (args.apply) {
  const dbUrl =
    args["db-url"] ??
    Deno.env.get("LOCAL_DATABASE_URL") ??
    "postgresql://postgres:postgres@127.0.0.1:55322/postgres";

  console.log(`Applying SQL to database at: ${dbUrl}...`);
  const cmd = new Deno.Command("psql", {
    args: [dbUrl, "-v", "ON_ERROR_STOP=1"],
    stdin: "piped",
    stdout: "piped",
    stderr: "piped",
  });

  const child = cmd.spawn();
  const writer = child.stdin.getWriter();
  await writer.write(new TextEncoder().encode(finalSql));
  await writer.close();

  const { code, stdout, stderr } = await child.output();
  if (code !== 0) {
    console.error(`Execution failed with exit code ${code}`);
    console.error(new TextDecoder().decode(stderr));
    Deno.exit(code);
  }

  console.log(new TextDecoder().decode(stdout));
  console.log(
    "✓ Successfully applied editorial content and refreshed read models in local database!",
  );
}

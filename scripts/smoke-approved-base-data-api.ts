const endpoint = readRequiredEnv("INGESTION_BASE_DATA_URL");
const workerSecret = readRequiredEnv("INGESTION_WORKER_SECRET");
const sourceCode = readRequiredEnv("INGESTION_SOURCE_CODE");
const idempotencyKey = `approved-api-${new Date().toISOString().slice(0, 10)}`;

const response = await fetch(endpoint, {
  method: "POST",
  headers: {
    authorization: `Bearer ${workerSecret}`,
    "content-type": "application/json",
    "idempotency-key": idempotencyKey,
  },
  body: JSON.stringify({
    sourceCode,
    providerMode: "approved_api",
  }),
});

const payload: unknown = await response.json().catch(() => null);
if (response.status !== 200 && response.status !== 409) {
  console.error(
    JSON.stringify({
      action: "APPROVED_BASE_DATA_SMOKE",
      status: "failed",
      http_status: response.status,
    }),
  );
  Deno.exit(1);
}

console.info(
  JSON.stringify({
    action: "APPROVED_BASE_DATA_SMOKE",
    status: response.status === 409 ? "duplicate" : "succeeded",
    http_status: response.status,
    response_contract_valid: isEnvelope(payload),
  }),
);

function readRequiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function isEnvelope(value: unknown): boolean {
  return (
    typeof value === "object" &&
    value !== null &&
    !Array.isArray(value) &&
    "data" in value &&
    "error" in value
  );
}

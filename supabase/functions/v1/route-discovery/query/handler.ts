import { assertMethod, errorResponse, jsonResponse, readJson } from '@shared/edge.ts';
import { parseRouteSearchRequest, type RouteSearchInput } from './request.ts';

export type RouteSearchEnvelope = {
  data: unknown;
  meta: Record<string, unknown>;
  error: { code: string; message?: string } | null;
};

export type RouteQueryDependencies = {
  searchRoutes(input: RouteSearchInput): Promise<RouteSearchEnvelope>;
};

export async function handleRouteQuery(
  request: Request,
  dependencies: RouteQueryDependencies,
): Promise<Response> {
  const methodError = assertMethod(request, ['POST']);
  if (methodError) return methodError;

  try {
    const input = parseRouteSearchRequest(await readJson(request));
    const result = await dependencies.searchRoutes(input);
    if (result.error) return errorResponse(new Error(result.error.code));
    return jsonResponse(result);
  } catch (error) {
    return errorResponse(error);
  }
}

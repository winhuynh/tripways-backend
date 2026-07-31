import { assertMethod, errorResponse, jsonResponse, readJson } from '@shared/edge.ts';
import { parseAirportPageQueryRequest } from './request.ts';

export type AirportPageQueryDependencies = {
  query(action: 'get_page' | 'search_routes', input: Record<string, unknown>): Promise<unknown>;
};

export async function handleAirportPageQuery(
  request: Request,
  dependencies: AirportPageQueryDependencies,
): Promise<Response> {
  const methodError = assertMethod(request, ['POST']);
  if (methodError) return methodError;
  try {
    const parsed = parseAirportPageQueryRequest(await readJson(request));
    return jsonResponse(await dependencies.query(parsed.action, parsed.input));
  } catch (error) {
    return errorResponse(error);
  }
}

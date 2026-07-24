import { assertMethod, errorResponse, jsonResponse, readJson } from '@shared/edge.ts';
import { parseRouteSearchRequest, type RouteSearchInput } from './request.ts';
import { mapRouteSearchResponse } from './response.ts';

export type RouteQueryDependencies = {
  searchRoutes(input: RouteSearchInput): Promise<unknown>;
};

export async function handleRouteQuery(
  request: Request,
  dependencies: RouteQueryDependencies,
): Promise<Response> {
  const methodError = assertMethod(request, ['POST']);
  if (methodError) return methodError;

  try {
    const requestDto = parseRouteSearchRequest(await readJson(request));
    const result = await dependencies.searchRoutes(requestDto.input);
    return jsonResponse(mapRouteSearchResponse(result));
  } catch (error) {
    return errorResponse(error);
  }
}

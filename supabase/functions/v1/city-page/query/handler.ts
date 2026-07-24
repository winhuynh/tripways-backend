import { assertMethod, errorResponse, jsonResponse, readJson } from '@shared/edge.ts';
import {
  type CityPageAction,
  type CityPageQueryInput,
  parseCityPageQueryRequest,
} from './request.ts';
import { mapCityPageResponse } from './response.ts';

export type CityPageQueryDependencies = {
  query(action: CityPageAction, input: CityPageQueryInput): Promise<unknown>;
};

export async function handleCityPageQuery(
  request: Request,
  dependencies: CityPageQueryDependencies,
): Promise<Response> {
  const methodError = assertMethod(request, ['POST']);
  if (methodError) return methodError;

  try {
    const requestDto = parseCityPageQueryRequest(await readJson(request));
    const result = await dependencies.query(requestDto.action, requestDto.input);
    return jsonResponse(mapCityPageResponse(result));
  } catch (error) {
    return errorResponse(error);
  }
}

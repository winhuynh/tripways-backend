import { assertMethod, errorResponse, jsonResponse } from '@shared/edge.ts';
export async function handleSitemapQuery(
  request: Request,
  deps: { query(locale: string | null): Promise<unknown> },
): Promise<Response> {
  const method = assertMethod(request, ['GET']);
  if (method) return method;
  try {
    return jsonResponse(await deps.query(new URL(request.url).searchParams.get('locale')));
  } catch (error) {
    return errorResponse(error);
  }
}

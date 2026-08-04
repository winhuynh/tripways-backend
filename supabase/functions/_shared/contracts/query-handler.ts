import { assertMethod, errorResponse, jsonResponse, readJson } from '@shared/edge.ts';
import { mapRpcEnvelope } from './rpc-envelope.ts';

export type QueryHandlerDependencies<TInput> = {
  parse(value: unknown): TInput;
  query(input: TInput): Promise<unknown>;
  contractErrorCode: string;
};

export function createQueryHandler<TInput>(
  dependencies: QueryHandlerDependencies<TInput>,
): (request: Request) => Promise<Response> {
  return async (request) => {
    const methodError = assertMethod(request, ['POST']);
    if (methodError) return methodError;
    try {
      const input = dependencies.parse(await readJson(request));
      const result = await dependencies.query(input);
      return jsonResponse(mapRpcEnvelope(result, dependencies.contractErrorCode));
    } catch (error) {
      return errorResponse(error);
    }
  };
}

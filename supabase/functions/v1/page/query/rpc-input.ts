import type { PageRequest } from '@shared/contracts/page-request.ts';

export type PageRpcInput = {
  page_type: PageRequest['input']['pageType'];
  entity_key: string;
  locale: string;
};

export function toPageRpcInput(request: PageRequest): PageRpcInput {
  return {
    page_type: request.input.pageType,
    entity_key: request.input.entityKey,
    locale: request.input.locale,
  };
}

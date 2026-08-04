import { assertAllowedFields, isRecord } from './guards.ts';
import { parseCode, parseLocale, parseSlug } from './primitives.ts';

const ERROR_CODE = 'ERR_PAGE_INVALID_REQUEST';
const ROOT_FIELDS = new Set(['action', 'input']);
const INPUT_FIELDS = new Set(['page_type', 'entity_key', 'locale']);

export type PageType = 'homepage' | 'city' | 'airport' | 'route';
export type PageRequest = {
  action: 'get_page';
  input: { pageType: PageType; entityKey: string; locale: string };
};

export function parsePageRequest(value: unknown): PageRequest {
  if (!isRecord(value) || value.action !== 'get_page' || !isRecord(value.input)) invalid();
  assertAllowedFields(value, ROOT_FIELDS, ERROR_CODE);
  assertAllowedFields(value.input, INPUT_FIELDS, ERROR_CODE);
  const pageType = value.input.page_type;
  if (!['homepage', 'city', 'airport', 'route'].includes(String(pageType))) invalid();
  const entityKey = pageType === 'airport'
    ? parseCode(value.input.entity_key, 3, ERROR_CODE)
    : parseSlug(value.input.entity_key, ERROR_CODE);
  return {
    action: 'get_page',
    input: {
      pageType: pageType as PageType,
      entityKey,
      locale: parseLocale(value.input.locale, 'en-GB', ERROR_CODE),
    },
  };
}

function invalid(): never {
  throw new Error(ERROR_CODE);
}

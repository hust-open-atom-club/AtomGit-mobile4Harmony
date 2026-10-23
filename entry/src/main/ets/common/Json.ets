import { JSON as ArkJSON } from '@kit.ArkTS';

export function safeParse(text: string): Object | undefined {
  if (!text || text.length === 0) {
    return undefined;
  }
  try {
    const parsed = ArkJSON.parse(text);
    if (parsed === null || parsed === undefined) {
      return undefined;
    }
    return parsed;
  } catch {
    return undefined;
  }
}

// v5 列表多为裸数组；通知为 { list: [...] }，不按裸数组解析
export function safeParseArray(text: string): Object[] | undefined {
  if (!text || text.length === 0) {
    return undefined;
  }
  try {
    const parsed = ArkJSON.parse(text);
    if (Array.isArray(parsed)) {
      return parsed as Object[];
    }
    return undefined;
  } catch {
    return undefined;
  }
}

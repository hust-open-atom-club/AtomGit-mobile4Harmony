export enum PagingType {
  // page / per_page（页码型）
  Offset = 'Offset',
  // year + next（游标型）
  Cursor = 'Cursor'
}

export class PagingState {
  readonly type: PagingType;
  readonly page: number;
  readonly cursor?: string;

  constructor(type: PagingType, page: number, cursor?: string) {
    this.type = type;
    this.page = page;
    this.cursor = cursor;
  }

  static first(type: PagingType): PagingState {
    return type === PagingType.Cursor
      ? new PagingState(PagingType.Cursor, 1, undefined)
      : new PagingState(PagingType.Offset, 1, undefined);
  }

  next(): PagingState {
    if (this.type === PagingType.Cursor) {
      return new PagingState(PagingType.Cursor, this.page, this.cursor);
    }
    return new PagingState(PagingType.Offset, this.page + 1, undefined);
  }
}

// hasMore 判据：Offset 看是否满 per_page，Cursor 看是否返回 next
export class Page<T> {
  readonly items: T[];
  readonly hasMore: boolean;
  readonly paging: PagingState;

  constructor(items: T[], hasMore: boolean, paging: PagingState) {
    this.items = items;
    this.hasMore = hasMore;
    this.paging = paging;
  }

  static empty<T>(paging: PagingState): Page<T> {
    return new Page<T>([], false, paging);
  }
}

// per_page 上限 100
export const MAX_PER_PAGE: number = 100;

// 默认每页 20
export const DEFAULT_PER_PAGE: number = 20;

export function clampPage(page: number): number {
  if (!Number.isFinite(page) || page < 1) {
    return 1;
  }
  return Math.floor(page);
}

export function clampPerPage(perPage: number): number {
  if (!Number.isFinite(perPage) || perPage < 1) {
    return DEFAULT_PER_PAGE;
  }
  return Math.min(Math.floor(perPage), MAX_PER_PAGE);
}

// 返回条数不足 per_page 时不能断言末页，满页才继续探测
export function offsetHasMore(received: number, perPage: number): boolean {
  return received >= perPage;
}

// next 缺失即终止，不得臆造下一页参数
export function cursorHasMore(nextCursor: string | undefined | null): boolean {
  return typeof nextCursor === 'string' && nextCursor.length > 0;
}

// 空页必终止，避免重复请求同一页
export function appendPage<T>(previous: T[], incoming: T[], declaredHasMore: boolean, paging: PagingState): Page<T> {
  if (incoming.length === 0) {
    return new Page<T>(previous, false, paging);
  }
  const merged = previous.concat(incoming);
  return new Page<T>(merged, declaredHasMore, paging);
}

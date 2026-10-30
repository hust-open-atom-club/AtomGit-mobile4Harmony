export enum PagingType {
  Offset = 'Offset',
  Cursor = 'Cursor'
}

/** Request position for APIs that use page/per_page. */
export class OffsetPageRequest {
  readonly type: PagingType = PagingType.Offset;
  readonly page: number;
  readonly perPage: number;

  constructor(page: number = 1, perPage: number = DEFAULT_PER_PAGE) {
    this.page = clampPage(page);
    this.perPage = clampPerPage(perPage);
  }

  next(): OffsetPageRequest {
    return new OffsetPageRequest(this.page + 1, this.perPage);
  }
}

/** Request position for APIs that return an opaque next cursor. */
export class CursorPageRequest {
  readonly type: PagingType = PagingType.Cursor;
  readonly cursor: string | undefined;

  constructor(cursor?: string) {
    this.cursor = cursor;
  }
}

export type PageRequest = OffsetPageRequest | CursorPageRequest;

/** Legacy state retained while existing repositories migrate to PageRequest. */
export class PagingState {
  readonly type: PagingType;
  readonly page: number;
  readonly cursor?: string;
  readonly perPage: number;

  constructor(type: PagingType, page: number, cursor?: string, perPage: number = DEFAULT_PER_PAGE) {
    this.type = type;
    this.page = clampPage(page);
    this.cursor = cursor;
    this.perPage = clampPerPage(perPage);
  }

  static first(type: PagingType, perPage: number = DEFAULT_PER_PAGE): PagingState {
    return new PagingState(type, 1, undefined, perPage);
  }

  static fromRequest(request: PageRequest): PagingState {
    return request instanceof CursorPageRequest
      ? new PagingState(PagingType.Cursor, 1, request.cursor)
      : new PagingState(PagingType.Offset, request.page, undefined, request.perPage);
  }

  next(nextCursor?: string): PagingState {
    if (this.type === PagingType.Cursor) {
      return new PagingState(PagingType.Cursor, this.page, nextCursor, this.perPage);
    }
    return new PagingState(PagingType.Offset, this.page + 1, undefined, this.perPage);
  }

  request(): PageRequest {
    return this.type === PagingType.Cursor
      ? new CursorPageRequest(this.cursor)
      : new OffsetPageRequest(this.page, this.perPage);
  }
}

/** A page carries the exact next request position supplied by the API. */
export class Page<T> {
  readonly items: T[];
  readonly hasMore: boolean;
  readonly paging: PagingState;
  readonly nextRequest: PageRequest | undefined;

  constructor(items: T[], hasMore: boolean, paging: PagingState, nextRequest?: PageRequest) {
    this.items = items;
    this.paging = paging;
    const resolvedNext = nextRequest ?? (paging.type === PagingType.Offset && hasMore && items.length > 0
      ? new OffsetPageRequest(paging.page + 1, paging.perPage) : undefined);
    const validNext = resolvedNext !== undefined && (paging.type === PagingType.Offset
      ? resolvedNext instanceof OffsetPageRequest && resolvedNext.page > paging.page
      : resolvedNext instanceof CursorPageRequest
        && cursorCanContinue(paging.cursor, resolvedNext.cursor));
    this.hasMore = hasMore && items.length > 0 && validNext;
    this.nextRequest = this.hasMore ? resolvedNext : undefined;
  }

  static empty<T>(paging: PagingState): Page<T> {
    return new Page<T>([], false, paging);
  }
}

export const MAX_PER_PAGE: number = 100;
export const DEFAULT_PER_PAGE: number = 20;

export function clampPage(page: number): number {
  if (!Number.isFinite(page) || page < 1) return 1;
  return Math.floor(page);
}

export function clampPerPage(perPage: number): number {
  if (!Number.isFinite(perPage) || perPage < 1) return DEFAULT_PER_PAGE;
  return Math.min(Math.floor(perPage), MAX_PER_PAGE);
}

export function offsetHasMore(received: number, perPage: number): boolean {
  return received >= clampPerPage(perPage);
}

export function cursorHasMore(nextCursor: string | undefined | null): boolean {
  return typeof nextCursor === 'string' && nextCursor.length > 0;
}

export function cursorCanContinue(currentCursor: string | undefined, nextCursor: string | undefined | null): boolean {
  return cursorHasMore(nextCursor) && nextCursor !== currentCursor;
}

export function nextOffsetRequest(current: OffsetPageRequest, received: number): PageRequest | undefined {
  return offsetHasMore(received, current.perPage) ? current.next() : undefined;
}

export function nextCursorRequest(current: CursorPageRequest, nextCursor: string | undefined | null,
  received: number): PageRequest | undefined {
  if (received === 0 || !cursorCanContinue(current.cursor, nextCursor)) return undefined;
  return new CursorPageRequest(nextCursor as string);
}

export function appendPage<T>(previous: T[], incoming: T[], declaredHasMore: boolean,
  paging: PagingState, nextRequest?: PageRequest): Page<T> {
  if (incoming.length === 0) return new Page<T>(previous, false, paging);
  return new Page<T>(previous.concat(incoming), declaredHasMore, paging, nextRequest);
}

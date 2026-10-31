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

/** A page carries the exact next request position supplied by the API. */
export class Page<T> {
  readonly items: T[];
  readonly hasMore: boolean;
  readonly request: PageRequest;
  readonly nextRequest: PageRequest | undefined;

  constructor(items: T[], request: PageRequest, nextRequest?: PageRequest) {
    this.items = items;
    this.request = request;
    const validNext = nextRequest !== undefined && (request instanceof OffsetPageRequest
      ? nextRequest instanceof OffsetPageRequest && nextRequest.page === request.page + 1
        && nextRequest.perPage === request.perPage
      : nextRequest instanceof CursorPageRequest && cursorCanContinue(request.cursor, nextRequest.cursor));
    this.nextRequest = items.length > 0 && validNext ? nextRequest : undefined;
    this.hasMore = this.nextRequest !== undefined;
  }

  static empty<T>(request: PageRequest): Page<T> {
    return new Page<T>([], request);
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

export function nextOffsetRequest(current: OffsetPageRequest, shouldContinue: boolean): PageRequest | undefined {
  return shouldContinue ? current.next() : undefined;
}

export function nextCursorRequest(current: CursorPageRequest, nextCursor: string | undefined | null,
  received: number): PageRequest | undefined {
  if (received === 0 || !cursorCanContinue(current.cursor, nextCursor)) return undefined;
  return new CursorPageRequest(nextCursor as string);
}

export function appendPage<T>(previous: T[], incoming: Page<T>): Page<T> {
  return new Page<T>(previous.concat(incoming.items), incoming.request, incoming.nextRequest);
}

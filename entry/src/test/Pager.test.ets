import { describe, it, expect } from '@ohos/hypium';
import {
  CursorPageRequest,
  DEFAULT_PER_PAGE,
  MAX_PER_PAGE,
  OffsetPageRequest,
  Page,
  appendPage,
  clampPage,
  clampPerPage,
  cursorCanContinue,
  cursorHasMore,
  nextCursorRequest,
  nextOffsetRequest,
  offsetHasMore
} from '../main/ets/common/Pager';

export default function pagerTest() {
  describe('Pager', () => {
    it('starts_offset_at_page_1', 0, () => {
      const request = new OffsetPageRequest();
      expect(request.page).assertEqual(1);
      expect(request.perPage).assertEqual(DEFAULT_PER_PAGE);
    });

    it('increments_offset_request', 0, () => {
      const second = new OffsetPageRequest(1, 30).next();
      expect(second.page).assertEqual(2);
      expect(second.perPage).assertEqual(30);
    });

    it('cursor_request_carries_opaque_value', 0, () => {
      const first = new CursorPageRequest();
      const next = new CursorPageRequest('2026-01-01');
      expect(first.cursor === undefined).assertTrue();
      expect(next.cursor).assertEqual('2026-01-01');
      expect(cursorCanContinue(first.cursor, next.cursor)).assertTrue();
    });

    it('terminates_cursor_when_next_absent_or_repeated', 0, () => {
      expect(cursorHasMore('2026-01-01')).assertTrue();
      expect(cursorHasMore('')).assertFalse();
      expect(cursorHasMore(undefined)).assertFalse();
      expect(cursorHasMore(null)).assertFalse();
      expect(cursorCanContinue('same', 'same')).assertFalse();
    });

    it('offset_has_more_requires_full_page', 0, () => {
      expect(offsetHasMore(20, 20)).assertTrue();
      expect(offsetHasMore(19, 20)).assertFalse();
      expect(offsetHasMore(0, 20)).assertFalse();
    });

    it('clamps_page_and_per_page_at_request_construction', 0, () => {
      expect(clampPage(0)).assertEqual(1);
      expect(clampPage(-5)).assertEqual(1);
      expect(clampPage(3)).assertEqual(3);
      expect(clampPage(2.7)).assertEqual(2);
      expect(clampPage(NaN)).assertEqual(1);
      expect(clampPerPage(0)).assertEqual(DEFAULT_PER_PAGE);
      expect(clampPerPage(50)).assertEqual(50);
      expect(clampPerPage(500)).assertEqual(MAX_PER_PAGE);

      const normalized = new OffsetPageRequest(0, 500);
      expect(normalized.page).assertEqual(1);
      expect(normalized.perPage).assertEqual(MAX_PER_PAGE);
    });

    it('creates_next_offset_request_from_current_request', 0, () => {
      const first = new OffsetPageRequest(1, 5);
      const next = nextOffsetRequest(first, offsetHasMore(5, first.perPage));
      expect(next instanceof OffsetPageRequest).assertTrue();
      expect((next as OffsetPageRequest).page).assertEqual(2);
      expect(nextOffsetRequest(first, offsetHasMore(4, first.perPage)) === undefined).assertTrue();
    });

    it('creates_next_cursor_request_only_when_cursor_advances', 0, () => {
      const first = new CursorPageRequest();
      const next = nextCursorRequest(first, 'cursor-1', 2);
      expect(next instanceof CursorPageRequest).assertTrue();
      expect((next as CursorPageRequest).cursor).assertEqual('cursor-1');
      expect(nextCursorRequest(new CursorPageRequest('cursor-1'), 'cursor-1', 2) === undefined).assertTrue();
      expect(nextCursorRequest(first, 'cursor-1', 0) === undefined).assertTrue();
    });

    it('page_owns_validated_next_request', 0, () => {
      const firstRequest = new OffsetPageRequest(1, 2);
      const page = new Page<string>(['a', 'b'], firstRequest, new OffsetPageRequest(2, 2));
      expect(page.hasMore).assertTrue();
      expect(page.nextRequest instanceof OffsetPageRequest).assertTrue();

      const wrongPage = new Page<string>(['a', 'b'], firstRequest, new OffsetPageRequest(4, 2));
      expect(wrongPage.hasMore).assertFalse();
    });

    it('append_page_concatenates_and_keeps_incoming_continuation', 0, () => {
      const first = new Page<string>(['a', 'b'], new OffsetPageRequest(1, 2), new OffsetPageRequest(2, 2));
      const second = new Page<string>(['c'], new OffsetPageRequest(2, 2));
      const combined = appendPage(first.items, second);
      expect(combined.items.length).assertEqual(3);
      expect(combined.hasMore).assertFalse();
      expect((combined.request as OffsetPageRequest).page).assertEqual(2);
    });

    it('empty_page_is_terminal', 0, () => {
      const request = new CursorPageRequest('cursor-1');
      const page = Page.empty<string>(request);
      expect(page.items.length).assertEqual(0);
      expect(page.hasMore).assertFalse();
      const withItemsButNoContinuation = new Page<string>(['x'], request);
      expect(withItemsButNoContinuation.hasMore).assertFalse();
    });
  });
}

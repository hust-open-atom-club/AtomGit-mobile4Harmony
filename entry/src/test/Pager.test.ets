import { describe, it, expect } from '@ohos/hypium';
import {
  DEFAULT_PER_PAGE,
  MAX_PER_PAGE,
  Page,
  PagingState,
  PagingType,
  appendPage,
  clampPage,
  clampPerPage,
  cursorHasMore,
  offsetHasMore
} from '../main/ets/common/Pager';

export default function pagerTest() {
  describe('Pager', () => {
    it('starts_offset_at_page_1', 0, () => {
      const p = PagingState.first(PagingType.Offset);
      expect(p.type).assertEqual(PagingType.Offset);
      expect(p.page).assertEqual(1);
      expect(p.cursor === undefined).assertTrue();
    });

    it('increments_offset_page', 0, () => {
      const p2 = PagingState.first(PagingType.Offset).next();
      expect(p2.page).assertEqual(2);
      expect(p2.next().page).assertEqual(3);
    });

    it('cursor_state_carries_cursor_verbatim', 0, () => {
      const first = PagingState.first(PagingType.Cursor);
      const withCursor = new PagingState(PagingType.Cursor, 1, '2026-01-01');
      const advanced = withCursor.next('2026-01-01');
      expect(advanced.cursor).assertEqual('2026-01-01');
      expect(advanced.page).assertEqual(1);
      expect(first.next().cursor === undefined).assertTrue();
    });

    it('terminates_cursor_when_next_absent', 0, () => {
      expect(cursorHasMore('2026-01-01')).assertTrue();
      expect(cursorHasMore('')).assertFalse();
      expect(cursorHasMore(undefined)).assertFalse();
      expect(cursorHasMore(null)).assertFalse();
    });

    it('offset_has_more_requires_full_page', 0, () => {
      expect(offsetHasMore(20, 20)).assertTrue();
      expect(offsetHasMore(19, 20)).assertFalse();
      expect(offsetHasMore(0, 20)).assertFalse();
    });

    it('clamps_page_and_per_page', 0, () => {
      expect(clampPage(0)).assertEqual(1);
      expect(clampPage(-5)).assertEqual(1);
      expect(clampPage(3)).assertEqual(3);
      expect(clampPage(2.7)).assertEqual(2);
      expect(clampPage(NaN)).assertEqual(1);

      expect(clampPerPage(0)).assertEqual(DEFAULT_PER_PAGE);
      expect(clampPerPage(50)).assertEqual(50);
      expect(clampPerPage(500)).assertEqual(MAX_PER_PAGE);
      expect(MAX_PER_PAGE).assertEqual(100);
    });

    it('append_page_concatenates', 0, () => {
      const st = PagingState.first(PagingType.Offset);
      const first = appendPage<string>([], ['a', 'b'], true, st);
      expect(first.items.length).assertEqual(2);
      expect(first.hasMore).assertTrue();

      const second = appendPage<string>(first.items, ['c'], false, st.next());
      expect(second.items.length).assertEqual(3);
      expect(second.hasMore).assertFalse();
    });

    it('empty_page_forces_termination', 0, () => {
      const st = PagingState.first(PagingType.Offset);
      const prev = ['a', 'b'];
      const res = appendPage<string>(prev, [], true, st.next());
      expect(res.items.length).assertEqual(2);
      expect(res.hasMore).assertFalse();
    });

    it('cursor_empty_next_terminates', 0, () => {
      const st = new PagingState(PagingType.Cursor, 1, 'c1');
      const res = appendPage<string>(['x'], ['y'], cursorHasMore(undefined), st);
      expect(res.items.length).assertEqual(2);
      expect(res.hasMore).assertFalse();
    });

    it('empty_page_helper_is_terminal', 0, () => {
      const st = PagingState.first(PagingType.Offset);
      const p = Page.empty<string>(st);
      expect(p.items.length).assertEqual(0);
      expect(p.hasMore).assertFalse();
    });
  });
}

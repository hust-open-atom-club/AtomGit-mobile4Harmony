import { describe, it, expect } from '@ohos/hypium';
import { DisplayMetrics } from '../main/ets/common/DisplayMetrics';

function resetMetrics(m: DisplayMetrics): void {
  m.applyWidth(360);
  m.applyInsets(0, 0);
}

export default function displayMetricsTest() {
  describe('DisplayMetrics', () => {
    it('maps_width_to_breakpoint_boundaries', 0, () => {
      const m: DisplayMetrics = DisplayMetrics.instance();
      resetMetrics(m);

      m.applyWidth(359);
      expect(m.widthVp).assertEqual(359);
      expect(m.breakpoint).assertEqual('sm');

      m.applyWidth(599);
      expect(m.widthVp).assertEqual(599);
      expect(m.breakpoint).assertEqual('sm');

      m.applyWidth(600);
      expect(m.widthVp).assertEqual(600);
      expect(m.breakpoint).assertEqual('md');

      m.applyWidth(839);
      expect(m.widthVp).assertEqual(839);
      expect(m.breakpoint).assertEqual('md');

      m.applyWidth(840);
      expect(m.widthVp).assertEqual(840);
      expect(m.breakpoint).assertEqual('lg');

      m.applyWidth(1200);
      expect(m.widthVp).assertEqual(1200);
      expect(m.breakpoint).assertEqual('lg');
    });

    it('ignores_non_positive_width', 0, () => {
      const m: DisplayMetrics = DisplayMetrics.instance();
      resetMetrics(m);

      m.applyWidth(0);
      expect(m.widthVp).assertEqual(360);
      expect(m.breakpoint).assertEqual('sm');

      m.applyWidth(-1);
      expect(m.widthVp).assertEqual(360);
      expect(m.breakpoint).assertEqual('sm');
    });

    it('applies_both_insets_and_rejects_negative', 0, () => {
      const m: DisplayMetrics = DisplayMetrics.instance();
      resetMetrics(m);

      m.applyInsets(44, 20);
      expect(m.topInsetVp).assertEqual(44);
      expect(m.bottomInsetVp).assertEqual(20);

      m.setTopInset(-1);
      m.setBottomInset(-5);
      expect(m.topInsetVp).assertEqual(44);
      expect(m.bottomInsetVp).assertEqual(20);
    });

    it('isWide_only_for_md_and_lg', 0, () => {
      const m: DisplayMetrics = DisplayMetrics.instance();
      resetMetrics(m);

      m.applyWidth(360);
      expect(m.isWide()).assertFalse();

      m.applyWidth(600);
      expect(m.breakpoint).assertEqual('md');
      expect(m.isWide()).assertTrue();

      m.applyWidth(900);
      expect(m.breakpoint).assertEqual('lg');
      expect(m.isWide()).assertTrue();
    });

    it('instance_returns_same_singleton', 0, () => {
      const a: DisplayMetrics = DisplayMetrics.instance();
      const b: DisplayMetrics = DisplayMetrics.instance();
      expect(a === b).assertTrue();

      a.applyWidth(700);
      expect(b.widthVp).assertEqual(700);
      expect(b.breakpoint).assertEqual('md');

      resetMetrics(a);
    });
  });
}

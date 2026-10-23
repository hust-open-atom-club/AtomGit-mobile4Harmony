import { describe, it, expect } from '@ohos/hypium';
import { safeParse, safeParseArray } from '../main/ets/common/Json';

export default function jsonTest() {
  describe('Json', () => {
    it('parses_valid_json_object', 0, () => {
      const o = safeParse('{"a":1}');
      expect(o === undefined).assertFalse();
    });

    it('returns_undefined_on_bad_json', 0, () => {
      expect(safeParse('not-json')).assertEqual(undefined);
      expect(safeParse('')).assertEqual(undefined);
    });

    it('parses_top_level_array', 0, () => {
      // v5 列表多为裸数组
      const arr = safeParseArray('[{"id":1},{"id":2}]');
      expect(arr === undefined).assertFalse();
      expect(arr?.length).assertEqual(2);
    });

    it('array_parser_rejects_objects', 0, () => {
      // 通知为 { list: [...] }
      expect(safeParseArray('{"list":[]}')).assertEqual(undefined);
      expect(safeParseArray('')).assertEqual(undefined);
      expect(safeParseArray('not-json')).assertEqual(undefined);
    });

    it('handles_empty_container_payloads', 0, () => {
      expect(safeParse('[]') === undefined).assertFalse();
      expect(safeParse('{}') === undefined).assertFalse();
      const arr = safeParseArray('[]');
      expect(arr?.length).assertEqual(0);
    });
  });
}

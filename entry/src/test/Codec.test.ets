import { describe, it, expect } from '@ohos/hypium';
import { fromBase64, utf8Decode, utf8Encode } from '../main/ets/common/Codec';

export default function codecTest() {
  describe('Codec', () => {
    it('roundtrips_ascii', 0, () => {
      const s = 'hello-token-123';
      expect(utf8Decode(utf8Encode(s))).assertEqual(s);
    });

    it('roundtrips_chinese', 0, () => {
      expect(utf8Decode(utf8Encode('令牌-中文-测试'))).assertEqual('令牌-中文-测试');
    });

    it('roundtrips_long_string', 0, () => {
      let s = '';
      for (let i = 0; i < 5000; i++) {
        s += 'ab';
      }
      expect(utf8Decode(utf8Encode(s)).length).assertEqual(s.length);
    });

    it('handles_empty', 0, () => {
      expect(utf8Encode('').length).assertEqual(0);
      expect(utf8Decode(new Uint8Array(0))).assertEqual('');
      expect(fromBase64('').length).assertEqual(0);
    });

    it('base64_of_invalid_returns_empty', 0, () => {
      expect(fromBase64('!!!not-base64!!!').length).assertEqual(0);
    });

    it('decodes_malformed_bytes_without_throwing', 0, () => {
      const bad = new Uint8Array([0xC3, 0x28, 0xFF]);
      const out = utf8Decode(bad);
      expect(out.length > 0).assertTrue();
    });
  });
}

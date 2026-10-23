import { describe, it, expect } from '@ohos/hypium';
import {
  AccountGuard,
  ENVELOPE_VERSION,
  HUKS_KEY_ALIAS,
  TokenEnvelope,
  accountScopedKey,
  buildEnvelope,
  deserializeEnvelope,
  isUsableEnvelope,
  serializeEnvelope,
} from '../main/ets/security/TokenEnvelope';

export default function tokenEnvelopeTest() {
  describe('TokenEnvelope', () => {
    it('envelope_never_carries_key_material', 0, () => {
      const env = buildEnvelope('acc-1', 'BASE64CIPHERTEXT', 'AES|GCM|NoPadding');
      expect(env.keyAlias).assertEqual(HUKS_KEY_ALIAS);
      const raw = serializeEnvelope(env);
      // 序列化只含 alias，无密钥字段
      expect(raw.indexOf('alias') >= 0).assertTrue();
      expect(raw.toLowerCase().indexOf('keymaterial')).assertEqual(-1);
    });

    it('roundtrips_serialization', 0, () => {
      const env = buildEnvelope('acc-1', 'CIPHER', 'AES|GCM|NoPadding');
      const back = deserializeEnvelope(serializeEnvelope(env));
      expect(back === undefined).assertFalse();
      expect(back?.accountId).assertEqual('acc-1');
      expect(back?.ciphertext).assertEqual('CIPHER');
      expect(back?.keyAlias).assertEqual(HUKS_KEY_ALIAS);
      expect(back?.version).assertEqual(ENVELOPE_VERSION);
    });

    it('rejects_malformed_payloads', 0, () => {
      expect(deserializeEnvelope('')).assertEqual(undefined);
      expect(deserializeEnvelope('not-json')).assertEqual(undefined);
      expect(deserializeEnvelope('{}')).assertEqual(undefined);
      expect(deserializeEnvelope('{"v":1,"acc":"a"}')).assertEqual(undefined);
      expect(deserializeEnvelope('{"v":1,"acc":"","alias":"k","ct":"c"}')).assertEqual(undefined);
      expect(deserializeEnvelope('{"v":1,"acc":"a","alias":"","ct":"c"}')).assertEqual(undefined);
      expect(deserializeEnvelope('{"v":1,"acc":"a","alias":"k","ct":""}')).assertEqual(undefined);
    });

    it('rejects_unknown_version', 0, () => {
      const future = new TokenEnvelope('acc-1', 'alias', 'ct', 'alg', 99);
      expect(isUsableEnvelope(future)).assertFalse();
      expect(isUsableEnvelope(buildEnvelope('acc-1', 'ct', 'alg'))).assertTrue();
    });

    it('rejects_envelope_without_key_alias', 0, () => {
      const noKey = new TokenEnvelope('acc-1', '', 'ct', 'alg', ENVELOPE_VERSION);
      expect(isUsableEnvelope(noKey)).assertFalse();
      expect(isUsableEnvelope(undefined)).assertFalse();
    });

    it('guard_requires_login_before_match', 0, () => {
      const g = new AccountGuard();
      expect(g.isLoggedIn()).assertFalse();
      expect(g.matches('acc-1')).assertFalse();

      g.setAccount('acc-1');
      expect(g.isLoggedIn()).assertTrue();
      expect(g.matches('acc-1')).assertTrue();
      expect(g.matches('acc-2')).assertFalse();
    });

    it('guard_blocks_stale_account_after_logout', 0, () => {
      const g = new AccountGuard();
      g.setAccount('acc-old');
      g.clear();
      expect(g.matches('acc-old')).assertFalse();
      expect(g.isLoggedIn()).assertFalse();

      g.setAccount('acc-new');
      expect(g.matches('acc-old')).assertFalse();
      expect(g.matches('acc-new')).assertTrue();
    });

    it('scoped_keys_isolate_accounts', 0, () => {
      expect(accountScopedKey('a', 'todos')).assertEqual('acc:a:todos');
      expect(accountScopedKey('b', 'todos') === accountScopedKey('a', 'todos')).assertFalse();
    });
  });
}

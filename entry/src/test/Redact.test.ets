import { describe, it, expect } from '@ohos/hypium';
import {
  errorSummary,
  maskAuthorization,
  maskToken,
  redactHeaders,
  redactText,
  redactUrl
} from '../main/ets/common/Redact';

export default function redactTest() {
  describe('Redact', () => {
    it('masks_token_keeping_short_tail', 0, () => {
      const masked = maskToken('abcdefghijklmnop');
      expect(masked.indexOf('abcdefghijkl')).assertEqual(-1);
      expect(masked.endsWith('mnop')).assertTrue();
      expect(masked.startsWith('********')).assertTrue();
    });

    it('masks_empty_token_safely', 0, () => {
      expect(maskToken('')).assertEqual('(empty)');
      expect(maskToken(undefined)).assertEqual('(empty)');
    });

    it('mask_does_not_leak_length_via_variable_stars', 0, () => {
      // 固定 8 颗星，避免星号数泄露长度
      const short = maskToken('short');
      const long = maskToken('a'.repeat(500));
      expect(short.split('*').length).assertEqual(long.split('*').length);
    });

    it('masks_authorization_preserving_scheme', 0, () => {
      const m = maskAuthorization('Bearer abcdefgh12345678');
      expect(m.startsWith('Bearer ')).assertTrue();
      expect(m.indexOf('abcdefgh1234')).assertEqual(-1);
      expect(m.endsWith('5678')).assertTrue();
    });

    it('masks_authorization_without_scheme', 0, () => {
      expect(maskAuthorization('rawtokenvalue').startsWith('********')).assertTrue();
    });

    it('redacts_sensitive_headers_only', 0, () => {
      const headers: Record<string, string> = {};
      headers['Authorization'] = 'Bearer secret-token-value-1234';
      headers['Accept'] = 'application/json';
      headers['access_token'] = 'query-token-abcdef';
      const out = redactHeaders(headers);
      expect(out['Authorization'].indexOf('secret-token-value')).assertEqual(-1);
      expect(out['access_token'].indexOf('query-token')).assertEqual(-1);
      expect(out['Accept']).assertEqual('application/json');
      expect(headers['Authorization']).assertEqual('Bearer secret-token-value-1234');
    });

    it('redacts_token_in_query_string', 0, () => {
      const url = 'https://api.atomgit.com/api/v5/user?access_token=SECRETVALUE123&page=2';
      const out = redactUrl(url);
      expect(out.indexOf('SECRETVALUE123')).assertEqual(-1);
      expect(out.indexOf('page=2') >= 0).assertTrue();
    });

    it('redact_url_without_query_is_unchanged', 0, () => {
      const u = 'https://api.atomgit.com/api/v5/user';
      expect(redactUrl(u)).assertEqual(u);
    });

    it('redacts_bearer_token_in_free_text', 0, () => {
      const t = 'failed with Bearer eyJhbGciOiJIUzI1NiJ9.abcdef payload';
      const out = redactText(t);
      expect(out.indexOf('eyJhbGciOiJIUzI1NiJ9.abcdef')).assertEqual(-1);
      expect(out.indexOf('Bearer') >= 0).assertTrue();
    });

    it('redacts_access_token_assignment_in_free_text', 0, () => {
      const t = 'query was access_token=abcdef123456 rest';
      const out = redactText(t);
      expect(out.indexOf('abcdef123456')).assertEqual(-1);
      expect(out.indexOf('access_token=********') >= 0).assertTrue();
    });

    it('redact_text_handles_empty', 0, () => {
      expect(redactText('')).assertEqual('');
    });

    it('error_summary_is_safe_and_keeps_trace', 0, () => {
      const s = errorSummary(
        'https://api.atomgit.com/api/v5/user?access_token=LEAKME123',
        403, 'trace-abc', 'no scopes:read_user');
      expect(s.indexOf('LEAKME123')).assertEqual(-1);
      expect(s.indexOf('trace-abc') >= 0).assertTrue();
      expect(s.indexOf('403') >= 0).assertTrue();
    });
  });
}

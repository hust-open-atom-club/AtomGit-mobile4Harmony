import { describe, it, expect } from '@ohos/hypium';
import {
  BASE_V5,
  BASE_V8,
  RequestSpec,
  buildHeaders,
  buildQuery,
  buildUrl,
  flag,
  kv,
} from '../main/ets/network/RequestSpec';
import { HttpMethod } from '../main/ets/network/NetworkPolicy';

export default function requestSpecTest() {
  describe('RequestSpec', () => {
    it('builds_v5_and_v8_urls', 0, () => {
      const v5 = buildUrl(new RequestSpec(HttpMethod.GET, '/user', [], false, true));
      expect(v5).assertEqual(BASE_V5 + '/user');
      const v8 = buildUrl(new RequestSpec(HttpMethod.GET, '/repos/o/r/actions/runs', [], true, true));
      expect(v8).assertEqual(BASE_V8 + '/repos/o/r/actions/runs');
    });

    it('normalizes_leading_slash', 0, () => {
      const u = buildUrl(new RequestSpec(HttpMethod.GET, 'user', [], false, true));
      expect(u).assertEqual(BASE_V5 + '/user');
    });

    it('appends_query_string', 0, () => {
      const spec = new RequestSpec(HttpMethod.GET, '/user/issues',
        [kv('filter', 'assigned'), kv('per_page', 20)], false, true);
      expect(buildUrl(spec)).assertEqual(BASE_V5 + '/user/issues?filter=assigned&per_page=20');
    });

    it('encodes_query_values', 0, () => {
      // 路径与查询值中的斜杠、空格必须转义
      expect(buildQuery([kv('path', 'src/main dir')])).assertEqual('path=src%2Fmain%20dir');
      expect(buildQuery([kv('q', 'a&b=c')])).assertEqual('q=a%26b%3Dc');
    });

    it('supports_bare_flags', 0, () => {
      expect(buildQuery([flag('unread')])).assertEqual('unread');
      expect(buildQuery([kv('unread', true)])).assertEqual('unread=true');
    });

    it('empty_query_produces_no_question_mark', 0, () => {
      expect(buildQuery([])).assertEqual('');
      expect(buildUrl(new RequestSpec(HttpMethod.GET, '/user', [], false, true)).indexOf('?')).assertEqual(-1);
    });

    it('injects_bearer_for_trusted_reads', 0, () => {
      const spec = new RequestSpec(HttpMethod.GET, '/user', [], false, true);
      const h = buildHeaders(spec, 'TOKEN123');
      expect(h['Authorization']).assertEqual('Bearer TOKEN123');
      expect(h['Accept']).assertEqual('application/json');
    });

    it('never_puts_token_in_query_string', 0, () => {
      const url = buildUrl(new RequestSpec(HttpMethod.GET, '/user', [], false, true));
      expect(url.toLowerCase().indexOf('token')).assertEqual(-1);
    });

    it('omits_auth_when_no_token', 0, () => {
      const spec = new RequestSpec(HttpMethod.GET, '/user', [], false, true);
      expect(buildHeaders(spec, undefined)['Authorization'] === undefined).assertTrue();
      expect(buildHeaders(spec, '')['Authorization'] === undefined).assertTrue();
    });

    it('omits_auth_for_public_specs', 0, () => {
      const spec = new RequestSpec(HttpMethod.GET, '/users/openEuler/repos', [], false, false);
      expect(buildHeaders(spec, 'TOKEN123')['Authorization'] === undefined).assertTrue();
    });

    it('sets_content_type_only_with_body', 0, () => {
      const withBody = new RequestSpec(HttpMethod.POST, '/repos/o/r/pulls/1/review', [], false, true, '{}');
      expect(buildHeaders(withBody, 'T')['Content-Type']).assertEqual('application/json');
      const noBody = new RequestSpec(HttpMethod.GET, '/user', [], false, true);
      expect(buildHeaders(noBody, 'T')['Content-Type'] === undefined).assertTrue();
    });
  });
}

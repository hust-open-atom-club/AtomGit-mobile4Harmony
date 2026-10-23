import { describe, it, expect } from '@ohos/hypium';
import {
  ApiError,
  ApiErrorKind,
  buildApiError,
  kindFromStatus,
  parseErrorBody
} from '../main/ets/common/ApiError';

export default function apiErrorTest() {
  describe('ApiError', () => {
    it('parses_atomgit_error_envelope', 0, () => {
      // 线上真实响应体
      const raw = '{"error_code":403,"error_code_name":"FORBIDDEN",'
        + '"error_message":"no scopes:read_user","trace_id":"6cce5918301d579cfd0ca79b8dc491ca"}';
      const err = buildApiError(403, raw, '/api/v5/user');
      expect(err.kind).assertEqual(ApiErrorKind.Forbidden);
      expect(err.errorCode).assertEqual(403);
      expect(err.message).assertEqual('no scopes:read_user');
      expect(err.traceId).assertEqual('6cce5918301d579cfd0ca79b8dc491ca');
    });

    it('falls_back_to_documented_message_field', 0, () => {
      // 文档 { message } 兼容形态
      const err = buildApiError(401, '{"message":"401 Unauthorized"}', '/api/v5/user');
      expect(err.kind).assertEqual(ApiErrorKind.Unauthorized);
      expect(err.message).assertEqual('401 Unauthorized');
    });

    it('maps_all_documented_status_codes', 0, () => {
      expect(kindFromStatus(401, 0)).assertEqual(ApiErrorKind.Unauthorized);
      expect(kindFromStatus(403, 0)).assertEqual(ApiErrorKind.Forbidden);
      expect(kindFromStatus(404, 0)).assertEqual(ApiErrorKind.NotFound);
      expect(kindFromStatus(405, 0)).assertEqual(ApiErrorKind.MethodNotAllowed);
      expect(kindFromStatus(409, 0)).assertEqual(ApiErrorKind.Conflict);
      expect(kindFromStatus(418, 0)).assertEqual(ApiErrorKind.UnsafeRequest);
      expect(kindFromStatus(422, 0)).assertEqual(ApiErrorKind.Unprocessable);
      expect(kindFromStatus(429, 0)).assertEqual(ApiErrorKind.RateLimited);
      expect(kindFromStatus(500, 0)).assertEqual(ApiErrorKind.ServerError);
      expect(kindFromStatus(503, 0)).assertEqual(ApiErrorKind.ServerError);
    });

    it('falls_back_to_error_code_when_status_unmapped', 0, () => {
      expect(kindFromStatus(0, 401)).assertEqual(ApiErrorKind.Unauthorized);
      expect(kindFromStatus(0, 404)).assertEqual(ApiErrorKind.NotFound);
      expect(kindFromStatus(200, 0)).assertEqual(ApiErrorKind.Unknown);
    });

    it('only_401_requires_relogin', 0, () => {
      const unauth = buildApiError(401, '', '/api/v5/user');
      const forbidden = buildApiError(403, '', '/api/v5/user/issues');
      expect(unauth.requiresReLogin()).assertTrue();
      expect(forbidden.requiresReLogin()).assertFalse();
    });

    it('classifies_retryability', 0, () => {
      expect(buildApiError(500, '', '/x').isRetryable()).assertTrue();
      expect(buildApiError(429, '', '/x').isRetryable()).assertTrue();
      expect(buildApiError(403, '', '/x').isRetryable()).assertFalse();
      expect(buildApiError(404, '', '/x').isRetryable()).assertFalse();
      expect(buildApiError(422, '', '/x').isRetryable()).assertFalse();
    });

    it('handles_empty_and_non_json_body', 0, () => {
      expect(buildApiError(500, undefined, '/x').message).assertEqual('');
      expect(buildApiError(500, '', '/x').message).assertEqual('');
      // HTML 错误页不能整页塞进 message
      const html = '<html><body>' + 'x'.repeat(5000) + '</body></html>';
      const err = buildApiError(502, html, '/x');
      expect(err.message.length).assertEqual(200);
    });

    it('parse_error_body_on_null_json', 0, () => {
      expect(parseErrorBody('null').message).assertEqual('null');
      expect(parseErrorBody('123').message).assertEqual('123');
    });

    it('exposes_user_facing_message_without_secrets', 0, () => {
      const err = new ApiError(ApiErrorKind.RateLimited, 429, 429, 'rate limited', 't-1', '/api/v5/user/issues');
      expect(err.toUserMessage()).assertEqual('请求过于频繁，请稍后再试');
      expect(err.toUserMessage().indexOf('Bearer')).assertEqual(-1);
    });
  });
}

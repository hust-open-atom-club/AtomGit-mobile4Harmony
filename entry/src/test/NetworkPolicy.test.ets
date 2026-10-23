import { describe, it, expect } from '@ohos/hypium';
import { ApiErrorKind } from '../main/ets/common/ApiError';
import {
  BackoffPolicy,
  DEFAULT_BACKOFF,
  HttpMethod,
  MAX_RETRIES,
  RetryContext,
  computeDelayMs,
  isIdempotent,
  isTrustedUrl,
  parseRetryAfter,
  shouldRetry
} from '../main/ets/network/NetworkPolicy';

export default function networkPolicyTest() {
  describe('NetworkPolicy', () => {
    it('identifies_idempotent_methods', 0, () => {
      expect(isIdempotent(HttpMethod.GET)).assertTrue();
      expect(isIdempotent(HttpMethod.PUT)).assertTrue();
      expect(isIdempotent(HttpMethod.PATCH)).assertTrue();
      expect(isIdempotent(HttpMethod.DELETE)).assertTrue();
      expect(isIdempotent(HttpMethod.POST)).assertFalse();
    });

    it('never_retries_write_operations', 0, () => {
      const kinds: ApiErrorKind[] = [ApiErrorKind.Network, ApiErrorKind.ServerError, ApiErrorKind.RateLimited];
      for (const k of kinds) {
        expect(shouldRetry(new RetryContext(HttpMethod.POST, 0, k))).assertFalse();
      }
    });

    it('retries_get_on_transient_failures', 0, () => {
      expect(shouldRetry(new RetryContext(HttpMethod.GET, 0, ApiErrorKind.Network))).assertTrue();
      expect(shouldRetry(new RetryContext(HttpMethod.GET, 0, ApiErrorKind.ServerError))).assertTrue();
      expect(shouldRetry(new RetryContext(HttpMethod.GET, 0, ApiErrorKind.RateLimited))).assertTrue();
    });

    it('does_not_retry_client_errors', 0, () => {
      expect(shouldRetry(new RetryContext(HttpMethod.GET, 0, ApiErrorKind.Unauthorized))).assertFalse();
      expect(shouldRetry(new RetryContext(HttpMethod.GET, 0, ApiErrorKind.Forbidden))).assertFalse();
      expect(shouldRetry(new RetryContext(HttpMethod.GET, 0, ApiErrorKind.NotFound))).assertFalse();
      expect(shouldRetry(new RetryContext(HttpMethod.GET, 0, ApiErrorKind.Unprocessable))).assertFalse();
      expect(shouldRetry(new RetryContext(HttpMethod.GET, 0, ApiErrorKind.Canceled))).assertFalse();
      expect(shouldRetry(new RetryContext(HttpMethod.GET, 0, ApiErrorKind.Parse))).assertFalse();
    });

    it('respects_retry_cap', 0, () => {
      for (let a = 0; a < MAX_RETRIES; a++) {
        expect(shouldRetry(new RetryContext(HttpMethod.GET, a, ApiErrorKind.ServerError))).assertTrue();
      }
      expect(shouldRetry(new RetryContext(HttpMethod.GET, MAX_RETRIES, ApiErrorKind.ServerError))).assertFalse();
      expect(shouldRetry(new RetryContext(HttpMethod.GET, MAX_RETRIES + 1, ApiErrorKind.ServerError))).assertFalse();
    });

    it('parses_retry_after_seconds', 0, () => {
      expect(parseRetryAfter('3', 0)).assertEqual(3000);
      expect(parseRetryAfter('0', 0)).assertEqual(0);
      expect(parseRetryAfter('120', 0)).assertEqual(120000);
    });

    it('parses_retry_after_http_date', 0, () => {
      const now = Date.parse('2026-01-01T00:00:00Z');
      expect(parseRetryAfter('Thu, 01 Jan 2026 00:00:10 GMT', now)).assertEqual(10000);
      expect(parseRetryAfter('Thu, 01 Jan 2026 00:00:00 GMT', now)).assertEqual(0);
    });

    it('ignores_invalid_retry_after', 0, () => {
      expect(parseRetryAfter(undefined, 0)).assertEqual(undefined);
      expect(parseRetryAfter('', 0)).assertEqual(undefined);
      expect(parseRetryAfter('   ', 0)).assertEqual(undefined);
      expect(parseRetryAfter('soon', 0)).assertEqual(undefined);
      expect(parseRetryAfter('-5', 0)).assertEqual(undefined);
    });

    it('prefers_retry_after_over_backoff', 0, () => {
      // 服务端 Retry-After 优先于指数退避
      const d = computeDelayMs(2000, 3, DEFAULT_BACKOFF, () => 0.5);
      expect(d).assertEqual(2000);
    });

    it('caps_huge_retry_after', 0, () => {
      const d = computeDelayMs(999999999, 0, DEFAULT_BACKOFF, () => 0.5);
      expect(d).assertEqual(DEFAULT_BACKOFF.maxDelayMs);
    });

    it('exponential_backoff_without_retry_after', 0, () => {
      const noJitter = new BackoffPolicy(500, 8000, 0);
      expect(computeDelayMs(undefined, 0, noJitter, () => 0.5)).assertEqual(500);
      expect(computeDelayMs(undefined, 1, noJitter, () => 0.5)).assertEqual(1000);
      expect(computeDelayMs(undefined, 2, noJitter, () => 0.5)).assertEqual(2000);
    });

    it('caps_exponential_growth', 0, () => {
      const noJitter = new BackoffPolicy(500, 8000, 0);
      expect(computeDelayMs(undefined, 10, noJitter, () => 0.5)).assertEqual(8000);
    });

    it('applies_jitter_within_bounds', 0, () => {
      const p = new BackoffPolicy(1000, 100000, 0.2);
      expect(computeDelayMs(undefined, 0, p, () => 0)).assertEqual(800);
      expect(computeDelayMs(undefined, 0, p, () => 1)).assertEqual(1200);
      expect(computeDelayMs(undefined, 0, p, () => 0.5)).assertEqual(1000);
    });

    it('delay_never_negative_or_exceeds_cap', 0, () => {
      const p = new BackoffPolicy(1000, 5000, 0.5);
      expect(computeDelayMs(undefined, 0, p, () => 0)).assertEqual(500);
      expect(computeDelayMs(undefined, 20, p, () => 1)).assertEqual(5000);
    });

    it('trusts_only_api_host', 0, () => {
      expect(isTrustedUrl('https://api.atomgit.com/api/v5/user')).assertTrue();
      expect(isTrustedUrl('https://API.ATOMGIT.COM/api/v5/user')).assertTrue();
      expect(isTrustedUrl('https://api.atomgit.com:443/api/v5/user')).assertTrue();
    });

    it('rejects_untrusted_hosts', 0, () => {
      // 外链、图片、下载不得携带凭据
      expect(isTrustedUrl('https://evil.example.com/steal')).assertFalse();
      expect(isTrustedUrl('https://atomgit.com/api/v5/user')).assertFalse();
      expect(isTrustedUrl('https://api.atomgit.com.evil.com/x')).assertFalse();
      expect(isTrustedUrl('https://sub.api.atomgit.com/x')).assertFalse();
      expect(isTrustedUrl('ftp://api.atomgit.com/x')).assertFalse();
      expect(isTrustedUrl('not-a-url')).assertFalse();
      expect(isTrustedUrl('')).assertFalse();
    });
  });
}

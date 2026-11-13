import { ApiErrorKind } from '../common/ApiError';

export enum HttpMethod {
  GET = 'GET',
  POST = 'POST',
  PUT = 'PUT',
  PATCH = 'PATCH',
  DELETE = 'DELETE'
}

export function isIdempotent(method: HttpMethod): boolean {
  return method === HttpMethod.GET
    || method === HttpMethod.PUT
    || method === HttpMethod.PATCH
    || method === HttpMethod.DELETE;
}

export class BackoffPolicy {
  readonly baseDelayMs: number;
  readonly maxDelayMs: number;
  // 抖动比例 0~1，避免重试尖峰
  readonly jitterRatio: number;

  constructor(baseDelayMs: number, maxDelayMs: number, jitterRatio: number) {
    this.baseDelayMs = baseDelayMs;
    this.maxDelayMs = maxDelayMs;
    this.jitterRatio = jitterRatio;
  }
}

export const DEFAULT_BACKOFF: BackoffPolicy = new BackoffPolicy(500, 8000, 0.2);

// 429 限额：400 次/分、4000 次/时
export const RATE_LIMIT_PER_MINUTE: number = 400;
export const RATE_LIMIT_PER_HOUR: number = 4000;

export const MAX_RETRIES: number = 2;

export const MAX_RESPONSE_BYTES: number = 5 * 1024 * 1024;

export const TRUNCATION_PREFIX: string = '[响应体超过有界上限，已截断]';

// Retry-After 支持秒数与 HTTP 日期两种形态
export function parseRetryAfter(headerValue: string | undefined, nowMs: number): number | undefined {
  if (!headerValue) {
    return undefined;
  }
  const trimmed = headerValue.trim();
  if (trimmed.length === 0) {
    return undefined;
  }
  // 形态一：纯秒数
  if (isAllDigits(trimmed)) {
    return Number(trimmed) * 1000;
  }
  // 形态二：HTTP-date；'-5' 会被 Date.parse 误解析，先校验形态
  if (!looksLikeHttpDate(trimmed)) {
    return undefined;
  }
  const parsed = Date.parse(trimmed);
  if (!Number.isNaN(parsed)) {
    const delta = parsed - nowMs;
    return delta > 0 ? delta : 0;
  }
  return undefined;
}

// 判据：含 ':' 与 4 位年份；rfc850 例外为 dd-Mon-yy
function looksLikeHttpDate(s: string): boolean {
  if (!hasFourDigitYear(s)) {
    return hasRfc850DatePattern(s);
  }
  for (let i = 0; i < s.length; i++) {
    if (s.charAt(i) === ':') {
      return true;
    }
  }
  return false;
}

function hasRfc850DatePattern(s: string): boolean {
  const firstDash: number = s.indexOf('-');
  if (firstDash <= 0) {
    return false;
  }
  if (firstDash !== 2) {
    return false;
  }
  for (let i = 0; i < 2; i++) {
    const c = s.charCodeAt(i);
    if (c < 48 || c > 57) {
      return false;
    }
  }
  let dashCount = 0;
  for (let i = 0; i < s.length; i++) {
    if (s.charAt(i) === '-') {
      dashCount++;
    }
  }
  return dashCount >= 2;
}

function hasFourDigitYear(s: string): boolean {
  let run = 0;
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c >= 48 && c <= 57) {
      run++;
      if (run === 4) {
        return true;
      }
    } else {
      run = 0;
    }
  }
  return false;
}

function isAllDigits(s: string): boolean {
  for (let i = 0; i < s.length; i++) {
    const c = s.charCodeAt(i);
    if (c < 48 || c > 57) {
      return false;
    }
  }
  return s.length > 0;
}

export function computeDelayMs(retryAfterMs: number | undefined, attempt: number, policy: BackoffPolicy,
  randomFn: () => number = Math.random): number {
  if (retryAfterMs !== undefined && retryAfterMs >= 0) {
    return Math.min(retryAfterMs, policy.maxDelayMs);
  }
  const exponential: number = policy.baseDelayMs * Math.pow(2, attempt);
  const capped: number = Math.min(exponential, policy.maxDelayMs);
  // 抖动区间 [1-jitter, 1+jitter]，避免负延迟
  const factor: number = 1 + (randomFn() * 2 - 1) * policy.jitterRatio;
  const delayed: number = capped * factor;
  return Math.max(0, Math.min(delayed, policy.maxDelayMs));
}

export class RetryContext {
  readonly method: HttpMethod;
  readonly attempt: number;
  readonly kind: ApiErrorKind;

  constructor(method: HttpMethod, attempt: number, kind: ApiErrorKind) {
    this.method = method;
    this.attempt = attempt;
    this.kind = kind;
  }
}

export function shouldRetry(ctx: RetryContext): boolean {
  if (!isIdempotent(ctx.method)) {
    return false;
  }
  if (ctx.attempt >= MAX_RETRIES) {
    return false;
  }
  return ctx.kind === ApiErrorKind.Network
    || ctx.kind === ApiErrorKind.ServerError
    || ctx.kind === ApiErrorKind.RateLimited;
}

export const TRUSTED_HOSTS: string[] = [
  'api.atomgit.com'
];

export const MAX_REDIRECT_FOLLOWS: number = 3;

export const REDIRECT_BLOCKED_CODE: number = 2300047;

export function isRedirectBlockedCode(code: number): boolean {
  return code === REDIRECT_BLOCKED_CODE;
}

const REDIRECT_STATUSES: number[] = [301, 302, 303, 307, 308];

export function isRedirectStatus(status: number): boolean {
  return REDIRECT_STATUSES.indexOf(status) >= 0;
}

export function extractAuthority(url: string): string {
  const schemeIdx: number = url.indexOf('://');
  if (schemeIdx < 0) {
    return '';
  }
  const afterScheme: string = url.substring(schemeIdx + 3);
  const slash: number = afterScheme.indexOf('/');
  const query: number = afterScheme.indexOf('?');
  const hash: number = afterScheme.indexOf('#');
  let end: number = afterScheme.length;
  if (slash >= 0 && slash < end) {
    end = slash;
  }
  if (query >= 0 && query < end) {
    end = query;
  }
  if (hash >= 0 && hash < end) {
    end = hash;
  }
  return afterScheme.substring(0, end).toLowerCase();
}

export function isSameOrigin(originalUrl: string, targetUrl: string): boolean {
  const scheme: string = extractScheme(originalUrl);
  if (scheme.length === 0 || scheme !== extractScheme(targetUrl)) {
    return false;
  }
  const authority: string = extractAuthority(originalUrl);
  if (authority.length === 0) {
    return false;
  }
  return authority === extractAuthority(targetUrl);
}

export function resolveRedirectTarget(originalUrl: string, location: string): string | undefined {
  const loc: string = (location ?? '').trim();
  if (loc.length === 0) {
    return undefined;
  }
  let target: string;
  if (loc.indexOf('://') > 0) {
    target = loc;
  } else if (loc.startsWith('//')) {
    const scheme: string = extractScheme(originalUrl);
    if (scheme.length === 0) {
      return undefined;
    }
    target = scheme + ':' + loc;
  } else if (loc.startsWith('/')) {
    const schemeIdx: number = originalUrl.indexOf('://');
    if (schemeIdx < 0) {
      return undefined;
    }
    const afterScheme: string = originalUrl.substring(schemeIdx + 3);
    const slash: number = afterScheme.indexOf('/');
    if (slash < 0) {
      return undefined;
    }
    target = originalUrl.substring(0, schemeIdx + 3 + slash) + loc;
  } else {
    return undefined;
  }
  if (TRUSTED_SCHEMES.indexOf(extractScheme(target)) < 0) {
    return undefined;
  }
  if (!isSameOrigin(originalUrl, target)) {
    return undefined;
  }
  return target;
}

export class RedirectDecision {
  readonly follow: boolean;
  readonly targetUrl: string;
  readonly method: HttpMethod;
  readonly body: string | undefined;
  readonly reason: string;

  constructor(follow: boolean, targetUrl: string, method: HttpMethod,
    body: string | undefined, reason: string) {
    this.follow = follow;
    this.targetUrl = targetUrl;
    this.method = method;
    this.body = body;
    this.reason = reason;
  }
}

export function decideRedirect(status: number, method: HttpMethod, body: string | undefined,
  currentUrl: string, location: string, hop: number): RedirectDecision {
  const target: string | undefined = resolveRedirectTarget(currentUrl, location);
  if (target === undefined) {
    return new RedirectDecision(false, currentUrl, method, body,
      'redirect target is not same-origin https');
  }
  if (hop >= MAX_REDIRECT_FOLLOWS) {
    return new RedirectDecision(false, currentUrl, method, body, 'too many redirects');
  }
  let next: HttpMethod = method;
  let nextBody: string | undefined = body;
  if (status === 303 || ((status === 301 || status === 302) && method !== HttpMethod.GET)) {
    next = HttpMethod.GET;
    nextBody = undefined;
  }
  return new RedirectDecision(true, target, next, nextBody, '');
}

export function extractHost(url: string): string {
  const schemeIdx: number = url.indexOf('://');
  if (schemeIdx < 0) {
    return '';
  }
  const afterScheme: string = url.substring(schemeIdx + 3);
  const slash: number = afterScheme.indexOf('/');
  const query: number = afterScheme.indexOf('?');
  const hash: number = afterScheme.indexOf('#');
  let end: number = afterScheme.length;
  if (slash >= 0 && slash < end) {
    end = slash;
  }
  if (query >= 0 && query < end) {
    end = query;
  }
  if (hash >= 0 && hash < end) {
    end = hash;
  }
  const hostPort: string = afterScheme.substring(0, end);
  const colon: number = hostPort.indexOf(':');
  const host: string = colon >= 0 ? hostPort.substring(0, colon) : hostPort;
  return host.toLowerCase();
}

export const TRUSTED_SCHEMES: string[] = ['https'];

// 仅 https + 精确主机名，防止把凭据发给相似域名
export function isTrustedUrl(url: string): boolean {
  const scheme: string = extractScheme(url);
  if (TRUSTED_SCHEMES.indexOf(scheme) < 0) {
    return false;
  }
  const host: string = extractHost(url);
  if (host.length === 0) {
    return false;
  }
  return TRUSTED_HOSTS.indexOf(host) >= 0;
}

export function extractScheme(url: string): string {
  const schemeIdx: number = url.indexOf('://');
  if (schemeIdx <= 0) {
    return '';
  }
  return url.substring(0, schemeIdx).toLowerCase();
}

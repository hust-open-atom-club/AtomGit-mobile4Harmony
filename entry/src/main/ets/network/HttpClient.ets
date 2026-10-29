import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { ApiError, ApiErrorKind, buildApiError } from '../common/ApiError';
import { errorSummary, redactUrl } from '../common/Redact';
import { RequestSpec, buildHeaders, buildUrl } from './RequestSpec';
import { HttpPort } from './HttpPort';
import {
  BackoffPolicy,
  DEFAULT_BACKOFF,
  HttpMethod,
  MAX_RESPONSE_BYTES,
  MAX_RETRIES,
  RetryContext,
  computeDelayMs,
  isTrustedUrl,
  parseRetryAfter,
  shouldRetry
} from './NetworkPolicy';

const DOMAIN = 0x0000;

export class CancelToken {
  private canceled: boolean = false;
  private pending: Array<() => void> = [];

  isCanceled(): boolean {
    return this.canceled;
  }

  cancel(): void {
    if (this.canceled) {
      return;
    }
    this.canceled = true;
    const waiters = this.pending.slice();
    this.pending = [];
    for (const w of waiters) {
      w();
    }
  }

  wait(): Promise<void> {
    if (this.canceled) {
      return Promise.resolve();
    }
    return new Promise<void>((resolve) => {
      this.pending.push(resolve);
    });
  }
}

export class HttpResult {
  readonly body: string;
  readonly status: number;
  // 429 判断用的原始 Retry-After
  readonly retryAfter: string | undefined;
  readonly truncated: boolean;

  constructor(body: string, status: number, retryAfter: string | undefined, truncated: boolean) {
    this.body = body;
    this.status = status;
    this.retryAfter = retryAfter;
    this.truncated = truncated;
  }
}

export class HttpConfig {
  readonly connectTimeoutMs: number;
  readonly readTimeoutMs: number;
  readonly maxBytes: number;
  readonly backoff: BackoffPolicy;

  constructor(connectTimeoutMs: number, readTimeoutMs: number, maxBytes: number,
    backoff: BackoffPolicy) {
    this.connectTimeoutMs = connectTimeoutMs;
    this.readTimeoutMs = readTimeoutMs;
    this.maxBytes = maxBytes;
    this.backoff = backoff;
  }
}

export function defaultConfig(): HttpConfig {
  return new HttpConfig(10000, 20000, MAX_RESPONSE_BYTES, DEFAULT_BACKOFF);
}

export interface TokenSource {
  currentToken(): string | undefined;
}

export class HttpClient implements HttpPort {
  private readonly config: HttpConfig;
  private tokenSource: TokenSource | undefined;

  constructor(config: HttpConfig) {
    this.config = config;
  }

  setTokenSource(src: TokenSource | undefined): void {
    this.tokenSource = src;
  }

  async request(spec: RequestSpec, cancel?: CancelToken): Promise<HttpResult> {
    const url = buildUrl(spec);
    const token = this.tokenSource === undefined ? undefined : this.tokenSource.currentToken();
    const headers = buildHeaders(spec, token);

    let attempt = 0;
    for (;;) {
      if (cancel !== undefined && cancel.isCanceled()) {
        throw new ApiError(ApiErrorKind.Canceled, 0, 0, 'canceled', '', redactUrl(url));
      }
      let lastError: ApiError | undefined = undefined;
      let retryAfter: string | undefined = undefined;
      try {
        const res = await this.once(spec, headers, url, cancel);
        return res;
      } catch (err) {
        lastError = this.asApiError(err, url);
        // 429 的 Retry-After 决定下次等待
        if (lastError.kind === ApiErrorKind.RateLimited) {
          retryAfter = (err instanceof ApiError) ? lastError.message : undefined;
        }
      }
      const ctx = new RetryContext(spec.method, attempt, lastError.kind);
      if (!shouldRetry(ctx)) {
        throw lastError;
      }
      const delay = computeDelayMs(parseRetryAfter(retryAfter, Date.now()), attempt, this.config.backoff);
      hilog.info(DOMAIN, 'AtomGit', 'retry in %{public}d ms: %{public}s', delay, errorSummary(url, lastError.status, lastError.traceId, lastError.message));
      attempt++;
      if (cancel !== undefined) {
        await this.raceCancel(cancel, delay);
        if (cancel.isCanceled()) {
          throw new ApiError(ApiErrorKind.Canceled, 0, 0, 'canceled', '', redactUrl(url));
        }
      } else {
        await sleep(delay);
      }
      if (attempt > MAX_RETRIES) {
        throw lastError;
      }
    }
  }

  private async once(spec: RequestSpec, headers: Record<string, string>, url: string,
    cancel?: CancelToken): Promise<HttpResult> {
    const client = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: toRequestMethod(spec.method),
        header: headers,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        connectTimeout: this.config.connectTimeoutMs,
        readTimeout: this.config.readTimeoutMs,
        maxLimit: this.config.maxBytes
      };
      if (spec.body !== undefined) {
        options.extraData = spec.body;
      }
      const resp = await client.request(url, options);
      const status = typeof resp.responseCode === 'number' ? resp.responseCode : 0;
      const rawResult = resp.result;
      let bodyText = '';
      if (typeof rawResult === 'string') {
        bodyText = rawResult;
      }
      if (status < 200 || status >= 300) {
        // Retry-After 存进 error.message 供重试使用
        const retryAfter = readHeader(resp.header, 'retry-after');
        const err = buildApiError(status, bodyText, redactUrl(url));
        throw new ApiError(err.kind, err.status, err.errorCode, retryAfter ?? err.message,
          err.traceId, err.endpoint);
      }
      const truncated = bodyText.length >= this.config.maxBytes;
      return new HttpResult(bodyText, status, readHeader(resp.header, 'retry-after'), truncated);
    } catch (err) {
      if (err instanceof ApiError) {
        throw err;
      }
      if (cancel !== undefined && cancel.isCanceled()) {
        throw new ApiError(ApiErrorKind.Canceled, 0, 0, 'canceled', '', redactUrl(url));
      }
      throw this.asApiError(err, url);
    } finally {
      client.destroy();
    }
  }

  private asApiError(err: Object, url: string): ApiError {
    return toTransportApiError(err, url);
  }

  private async raceCancel(cancel: CancelToken, delay: number): Promise<void> {
    await Promise.race([cancel.wait(), sleep(delay)]);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(() => resolve(), ms);
  });
}

function toRequestMethod(m: HttpMethod): http.RequestMethod {
  if (m === HttpMethod.POST) {
    return http.RequestMethod.POST;
  }
  if (m === HttpMethod.PUT) {
    return http.RequestMethod.PUT;
  }
  if (m === HttpMethod.PATCH) {
    return http.RequestMethod.PATCH;
  }
  if (m === HttpMethod.DELETE) {
    return http.RequestMethod.DELETE;
  }
  return http.RequestMethod.GET;
}

// 头字段大小写不敏感；ArkTS 禁止下标访问，转键值数组后匹配
function readHeader(header: Object, name: string): string | undefined {
  if (header === undefined || header === null) {
    return undefined;
  }
  const target = name.toLowerCase();
  let entries: Array<string[]> = [];
  try {
    const rec = header as Record<string, string>;
    const keys: string[] = Object.keys(rec);
    for (const k of keys) {
      const v = rec[k];
      if (typeof v === 'string') {
        entries.push([k.toLowerCase(), v]);
      }
    }
  } catch {
    return undefined;
  }
  for (const e of entries) {
    if (e.length === 2 && e[0] === target) {
      return e[1];
    }
  }
  return undefined;
}

export function toTransportApiError(err: Object, url: string): ApiError {
  if (err instanceof ApiError) {
    return err;
  }
  const be = err as BusinessError;
  if (be !== undefined && be !== null && be.code !== undefined) {
    const code = be.code;
    let kind = ApiErrorKind.Network;
    if (code === 2090001) {
      kind = ApiErrorKind.Canceled;
    }
    return new ApiError(kind, 0, code, be.message ?? '', '', redactUrl(url));
  }
  return new ApiError(ApiErrorKind.Network, 0, 0, 'request failed', '', redactUrl(url));
}

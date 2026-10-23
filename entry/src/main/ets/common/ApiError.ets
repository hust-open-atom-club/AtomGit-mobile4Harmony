export enum ApiErrorKind {
  Unauthorized = 'Unauthorized',
  Forbidden = 'Forbidden',
  NotFound = 'NotFound',
  MethodNotAllowed = 'MethodNotAllowed',
  Conflict = 'Conflict',
  UnsafeRequest = 'UnsafeRequest',
  Unprocessable = 'Unprocessable',
  RateLimited = 'RateLimited',
  ServerError = 'ServerError',
  Network = 'Network',
  Canceled = 'Canceled',
  Parse = 'Parse',
  Unknown = 'Unknown'
}

// 线上错误体（实测）
export interface AtomGitErrorBody {
  error_code?: number;
  error_code_name?: string;
  error_message?: string;
  trace_id?: string;
  // 文档兼容字段，部分接口仍会返回
  message?: string;
}

export class ApiError extends Error {
  readonly kind: ApiErrorKind;
  // HTTP 状态码；传输层失败为 0
  readonly status: number;
  // 平台 error_code，可能与 HTTP status 不同
  readonly errorCode: number;
  readonly traceId: string;
  readonly endpoint: string;

  constructor(kind: ApiErrorKind, status: number, errorCode: number,
    message: string, traceId: string, endpoint: string) {
    super(message);
    this.name = 'ApiError';
    this.kind = kind;
    this.status = status;
    this.errorCode = errorCode;
    this.traceId = traceId;
    this.endpoint = endpoint;
  }

  requiresReLogin(): boolean {
    return this.kind === ApiErrorKind.Unauthorized;
  }

  isRetryable(): boolean {
    return this.kind === ApiErrorKind.Network
      || this.kind === ApiErrorKind.ServerError
      || this.kind === ApiErrorKind.RateLimited;
  }

  toUserMessage(): string {
    switch (this.kind) {
      case ApiErrorKind.Unauthorized:
        return '登录已失效，请重新登录';
      case ApiErrorKind.Forbidden:
        return '没有访问该资源的权限';
      case ApiErrorKind.NotFound:
        return '资源不存在或已被删除';
      case ApiErrorKind.MethodNotAllowed:
        return '当前操作不被支持';
      case ApiErrorKind.Conflict:
        return '资源状态冲突，请刷新后重试';
      case ApiErrorKind.UnsafeRequest:
        return '请求被安全策略拒绝';
      case ApiErrorKind.Unprocessable:
        return '提交的内容不符合要求';
      case ApiErrorKind.RateLimited:
        return '请求过于频繁，请稍后再试';
      case ApiErrorKind.ServerError:
        return '服务暂时不可用，请稍后重试';
      case ApiErrorKind.Network:
        return '网络连接不可用';
      case ApiErrorKind.Canceled:
        return '请求已取消';
      case ApiErrorKind.Parse:
        return '数据解析失败';
      default:
        return '请求失败，请稍后重试';
    }
  }
}

// HTTP 状态码 → 类别；error_code 仅作回退
export function kindFromStatus(status: number, errorCode: number): ApiErrorKind {
  if (status === 401) {
    return ApiErrorKind.Unauthorized;
  }
  if (status === 403) {
    return ApiErrorKind.Forbidden;
  }
  if (status === 429) {
    return ApiErrorKind.RateLimited;
  }
  if (status >= 500) {
    return ApiErrorKind.ServerError;
  }
  switch (status) {
    case 404:
      return ApiErrorKind.NotFound;
    case 405:
      return ApiErrorKind.MethodNotAllowed;
    case 409:
      return ApiErrorKind.Conflict;
    case 418:
      return ApiErrorKind.UnsafeRequest;
    case 422:
      return ApiErrorKind.Unprocessable;
    default:
      break;
  }
  if (errorCode === 401) {
    return ApiErrorKind.Unauthorized;
  }
  if (errorCode === 403) {
    return ApiErrorKind.Forbidden;
  }
  if (errorCode === 404) {
    return ApiErrorKind.NotFound;
  }
  if (errorCode === 429) {
    return ApiErrorKind.RateLimited;
  }
  return ApiErrorKind.Unknown;
}

export function parseErrorBody(body: string | undefined): AtomGitErrorBody {
  if (!body || body.length === 0) {
    return {};
  }
  try {
    const parsed = JSON.parse(body) as AtomGitErrorBody;
    if (parsed === null || typeof parsed !== 'object') {
      return { message: body.substring(0, 200) };
    }
    return parsed;
  } catch {
    // 非 JSON（如 HTML 错误页）只保留前 200 字符
    return { message: body.substring(0, 200) };
  }
}

export function buildApiError(status: number, body: string | undefined, endpoint: string): ApiError {
  const parsed = parseErrorBody(body);
  const errorCode = typeof parsed.error_code === 'number' ? parsed.error_code : 0;
  const message = parsed.error_message ?? parsed.message ?? '';
  const traceId = parsed.trace_id ?? '';
  return new ApiError(kindFromStatus(status, errorCode), status, errorCode, message, traceId, endpoint);
}

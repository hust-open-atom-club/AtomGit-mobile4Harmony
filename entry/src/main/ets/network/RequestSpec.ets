import { HttpMethod, TRUSTED_HOSTS, isTrustedUrl } from './NetworkPolicy';

// v5 主 API；v8 承载 Actions
export const BASE_V5: string = 'https://api.atomgit.com/api/v5';
export const BASE_V8: string = 'https://api.atomgit.com/api/v8';

export class RequestSpec {
  readonly method: HttpMethod;
  readonly path: string;
  // 每项形如 k=v 或裸 k
  readonly query: string[];
  readonly body?: string;
  readonly useV8: boolean;
  readonly withAuth: boolean;

  constructor(method: HttpMethod, path: string, query: string[],
    useV8: boolean, withAuth: boolean, body?: string) {
    this.method = method;
    this.path = path;
    this.query = query;
    this.useV8 = useV8;
    this.withAuth = withAuth;
    this.body = body;
  }
}

export function kv(key: string, value: string | number | boolean): string {
  return encodeURIComponent(key) + '=' + encodeURIComponent(String(value));
}

export function flag(key: string): string {
  return encodeURIComponent(key);
}

export function buildQuery(query: string[]): string {
  if (query.length === 0) {
    return '';
  }
  return query.join('&');
}

export function buildUrl(spec: RequestSpec): string {
  const base = spec.useV8 ? BASE_V8 : BASE_V5;
  const path = spec.path.startsWith('/') ? spec.path : '/' + spec.path;
  const qs = buildQuery(spec.query);
  return qs.length > 0 ? base + path + '?' + qs : base + path;
}

// 凭据只注入受信任主机，且绝不放进查询串
export function buildHeaders(spec: RequestSpec, token: string | undefined): Record<string, string> {
  const headers: Record<string, string> = {};
  headers['Accept'] = 'application/json';
  if (spec.body !== undefined) {
    headers['Content-Type'] = 'application/json';
  }
  const url = buildUrl(spec);
  if (spec.withAuth && token !== undefined && token.length > 0 && isTrustedUrl(url)) {
    headers['Authorization'] = 'Bearer ' + token;
  }
  return headers;
}

export function trustedHosts(): string[] {
  return TRUSTED_HOSTS.slice();
}

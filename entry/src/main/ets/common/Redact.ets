const SENSITIVE_HEADERS: string[] = [
  'authorization',
  'private-token',
  'access_token',
  'accesstoken',
  'token',
  'cookie',
  'set-cookie'
];

const TOKEN_TAIL: number = 4;

// 固定星号数，避免从星号数推断令牌长度
const MASK: string = '********';

export function maskToken(token: string | undefined | null): string {
  if (!token || token.length === 0) {
    return '(empty)';
  }
  const tail = token.length <= TOKEN_TAIL ? token : token.substring(token.length - TOKEN_TAIL);
  return MASK + tail;
}

// 'Bearer abc123' → 'Bearer ********c123'
export function maskAuthorization(headerValue: string): string {
  const sp = headerValue.indexOf(' ');
  if (sp <= 0) {
    return maskToken(headerValue);
  }
  const scheme = headerValue.substring(0, sp);
  return scheme + ' ' + maskToken(headerValue.substring(sp + 1));
}

// 令牌字符集：URL-safe 变体
function isTokenChar(c: string): boolean {
  const code = c.charCodeAt(0);
  if (code >= 48 && code <= 57) {
    return true;
  }
  if (code >= 65 && code <= 90) {
    return true;
  }
  if (code >= 97 && code <= 122) {
    return true;
  }
  return c === '.' || c === '_' || c === '~' || c === '+' || c === '/' || c === '=' || c === '-';
}

function scanToken(text: string, start: number): number {
  let i = start;
  while (i < text.length && isTokenChar(text.charAt(i))) {
    i++;
  }
  return i;
}

function skipSpaces(text: string, start: number): number {
  let i = start;
  while (i < text.length && (text.charAt(i) === ' ' || text.charAt(i) === '\t')) {
    i++;
  }
  return i;
}

const MIN_TOKEN_LEN: number = 8;

export function redactText(text: string): string {
  if (!text) {
    return text;
  }
  const lower = text.toLowerCase();
  const n = text.length;
  const marks: boolean[] = new Array<boolean>(n).fill(false);

  // 形态一：Bearer <token>
  const bearer: string = 'bearer';
  let i: number = 0;
  while (i < n) {
    if (i + bearer.length <= n && lower.substring(i, i + bearer.length) === bearer) {
      const after: number = skipSpaces(text, i + bearer.length);
      // 方案名与令牌之间需有空白，'bearerXxx' 不匹配
      if (after > i + bearer.length) {
        const end: number = scanToken(text, after);
        if (end - after >= MIN_TOKEN_LEN) {
          for (let k = after; k < end; k++) {
            marks[k] = true;
          }
          i = end;
          continue;
        }
      }
    }
    i++;
  }

  // 形态二：access_token / private_token / private-token = <token>
  const names: string[] = ['access_token', 'private_token', 'private-token'];
  i = 0;
  while (i < n) {
    let matchedName: string = '';
    for (const name of names) {
      if (i + name.length <= n && lower.substring(i, i + name.length) === name) {
        matchedName = name;
        break;
      }
    }
    if (matchedName.length > 0) {
      let j: number = skipSpaces(text, i + matchedName.length);
      // 允许 "name" : value 形态
      if (j < n && (text.charAt(j) === '"' || text.charAt(j) === '\'')) {
        j = skipSpaces(text, j + 1);
      }
      if (j < n && (text.charAt(j) === ':' || text.charAt(j) === '=')) {
        j = skipSpaces(text, j + 1);
        if (j < n && (text.charAt(j) === '"' || text.charAt(j) === '\'')) {
          j = skipSpaces(text, j + 1);
        }
        const end: number = scanToken(text, j);
        if (end - j >= MIN_TOKEN_LEN) {
          for (let k = j; k < end; k++) {
            marks[k] = true;
          }
          i = end;
          continue;
        }
      }
    }
    i++;
  }

  let out: string = '';
  let inMask: boolean = false;
  for (let k = 0; k < n; k++) {
    if (marks[k]) {
      if (!inMask) {
        out += MASK;
        inMask = true;
      }
    } else {
      out += text.charAt(k);
      inMask = false;
    }
  }
  return out;
}

export function redactHeaders(headers: Record<string, string>): Record<string, string> {
  const out: Record<string, string> = {};
  const keys: string[] = Object.keys(headers);
  for (let i = 0; i < keys.length; i++) {
    const k: string = keys[i];
    const lower: string = k.toLowerCase();
    if (SENSITIVE_HEADERS.indexOf(lower) >= 0) {
      out[k] = lower === 'authorization' ? maskAuthorization(headers[k]) : maskToken(headers[k]);
    } else {
      out[k] = headers[k];
    }
  }
  return out;
}

// AtomGit 也支持 ?access_token= 认证，URL 中的凭据必须清理
export function redactUrl(url: string): string {
  const q: number = url.indexOf('?');
  if (q < 0) {
    return url;
  }
  const base: string = url.substring(0, q);
  const query: string = url.substring(q + 1);
  const parts: string[] = query.split('&');
  const kept: string[] = [];
  for (let i = 0; i < parts.length; i++) {
    const eq: number = parts[i].indexOf('=');
    if (eq < 0) {
      kept.push(parts[i]);
      continue;
    }
    const name: string = parts[i].substring(0, eq);
    if (SENSITIVE_HEADERS.indexOf(name.toLowerCase()) >= 0) {
      kept.push(name + '=' + MASK);
    } else {
      kept.push(parts[i]);
    }
  }
  return base + '?' + kept.join('&');
}

export function errorSummary(endpoint: string, status: number, traceId: string, message: string): string {
  return redactUrl(endpoint) + ' -> ' + status + (traceId ? ' trace=' + traceId : '')
    + (message ? ' msg=' + redactText(message) : '');
}

const B64: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

// 字符 → 6 位值查表；-1 表示非法
function b64Value(c: string): number {
  const i = B64.indexOf(c);
  if (i < 0) {
    return -1;
  }
  return i;
}

export function utf8Encode(s: string): Uint8Array {
  if (s.length === 0) {
    return new Uint8Array(0);
  }
  const encoded = encodeURIComponent(s);
  const out = new Uint8Array(encoded.length);
  let n = 0;
  for (let i = 0; i < encoded.length; i++) {
    if (encoded.charAt(i) === '%') {
      const v = parseInt(encoded.substring(i + 1, i + 3), 16);
      if (Number.isNaN(v)) {
        continue;
      }
      out[n] = v;
      n++;
      i = i + 2;
    } else {
      const v = encoded.charCodeAt(i);
      if (v < 128) {
        out[n] = v;
        n++;
      }
    }
  }
  return out.slice(0, n);
}

// 非法序列替换为 U+FFFD，不抛异常
export function utf8Decode(b: Uint8Array): string {
  if (b === undefined || b.length === 0) {
    return '';
  }
  let out = '';
  let i = 0;
  const n = b.length;
  while (i < n) {
    const byte = b[i];
    let cp = 0;
    let size = 0;
    if (byte < 0x80) {
      cp = byte;
      size = 1;
    } else if ((byte & 0xE0) === 0xC0) {
      cp = byte & 0x1F;
      size = 2;
    } else if ((byte & 0xF0) === 0xE0) {
      cp = byte & 0x0F;
      size = 3;
    } else if ((byte & 0xF8) === 0xF0) {
      cp = byte & 0x07;
      size = 4;
    } else {
      out += '\uFFFD';
      i++;
      continue;
    }
    if (i + size > n) {
      out += '\uFFFD';
      i++;
      continue;
    }
    let valid = true;
    for (let k = 1; k < size; k++) {
      const cont = b[i + k];
      if ((cont & 0xC0) !== 0x80) {
        valid = false;
        break;
      }
      cp = (cp << 6) | (cont & 0x3F);
    }
    if (!valid) {
      out += '\uFFFD';
      i++;
      continue;
    }
    i = i + size;
    out += safeFromCodePoint(cp);
  }
  return out;
}

function safeFromCodePoint(cp: number): string {
  if (!Number.isFinite(cp) || cp < 0 || cp > 0x10FFFF) {
    return '\uFFFD';
  }
  if (cp >= 0xD800 && cp <= 0xDFFF) {
    return '\uFFFD';
  }
  return String.fromCodePoint(cp);
}

export function toBase64(b: Uint8Array): string {
  if (b === undefined || b.length === 0) {
    return '';
  }
  let out = '';
  const n = b.length;
  let i = 0;
  for (; i + 2 < n; i += 3) {
    const n0 = b[i];
    const n1 = b[i + 1];
    const n2 = b[i + 2];
    out += B64.charAt(n0 >> 2);
    out += B64.charAt(((n0 & 0x03) << 4) | (n1 >> 4));
    out += B64.charAt(((n1 & 0x0F) << 2) | (n2 >> 6));
    out += B64.charAt(n2 & 0x3F);
  }
  const rem = n - i;
  if (rem === 1) {
    const n0 = b[i];
    out += B64.charAt(n0 >> 2);
    out += B64.charAt((n0 & 0x03) << 4);
    out += '==';
  } else if (rem === 2) {
    const n0 = b[i];
    const n1 = b[i + 1];
    out += B64.charAt(n0 >> 2);
    out += B64.charAt(((n0 & 0x03) << 4) | (n1 >> 4));
    out += B64.charAt((n1 & 0x0F) << 2);
    out += '=';
  }
  return out;
}

export function fromBase64(s: string): Uint8Array {
  if (s === undefined || s.length === 0) {
    return new Uint8Array(0);
  }
  // API 返回的 base64 可能含换行，先剔除空白
  let clean = '';
  for (let i = 0; i < s.length; i++) {
    const c = s.charAt(i);
    if (c === '\n' || c === '\r' || c === ' ' || c === '\t') {
      continue;
    }
    clean += c;
  }
  if (clean.length === 0 || clean.length % 4 !== 0) {
    return new Uint8Array(0);
  }
  const out = new Uint8Array(clean.length / 4 * 3);
  let o = 0;
  for (let i = 0; i < clean.length; i += 4) {
    const c0 = b64Value(clean.charAt(i));
    const c1 = b64Value(clean.charAt(i + 1));
    const pad = clean.charAt(i + 2) === '=';
    const pad2 = clean.charAt(i + 3) === '=';
    const c2 = pad ? 0 : b64Value(clean.charAt(i + 2));
    const c3 = pad2 ? 0 : b64Value(clean.charAt(i + 3));
    if (c0 < 0 || c1 < 0 || c2 < 0 || c3 < 0) {
      return new Uint8Array(0);
    }
    out[o] = (c0 << 2) | (c1 >> 4);
    o++;
    if (!pad) {
      out[o] = ((c1 & 0x0F) << 4) | (c2 >> 2);
      o++;
    }
    if (!pad2) {
      out[o] = ((c2 & 0x03) << 6) | c3;
      o++;
    }
  }
  return out.slice(0, o);
}

export const ENVELOPE_VERSION: number = 1;

// HUKS 密钥别名，与密文分开存储
export const HUKS_KEY_ALIAS: string = 'atomgit_mobile_token_key';

export class TokenEnvelope {
  // 账号标识，用于缓存分区
  readonly accountId: string;
  keyAlias: string;
  // Base64 密文（含 auth tag）
  ciphertext: string;
  readonly algorithm: string;
  readonly version: number;

  constructor(accountId: string, keyAlias: string, ciphertext: string, algorithm: string, version: number) {
    this.accountId = accountId;
    this.keyAlias = keyAlias;
    this.ciphertext = ciphertext;
    this.algorithm = algorithm;
    this.version = version;
  }
}

export class AccountGuard {
  private currentAccountId: string = '';

  setAccount(accountId: string): void {
    this.currentAccountId = accountId;
  }

  current(): string {
    return this.currentAccountId;
  }

  isLoggedIn(): boolean {
    return this.currentAccountId.length > 0;
  }

  matches(accountId: string): boolean {
    if (!this.isLoggedIn()) {
      return false;
    }
    return this.currentAccountId === accountId;
  }

  clear(): void {
    this.currentAccountId = '';
  }
}

// 缓存键形如 acc:<accountId>:<key>
export function accountScopedKey(accountId: string, key: string): string {
  return 'acc:' + accountId + ':' + key;
}

export function buildEnvelope(accountId: string, ciphertext: string, algorithm: string): TokenEnvelope {
  return new TokenEnvelope(accountId, HUKS_KEY_ALIAS, ciphertext, algorithm, ENVELOPE_VERSION);
}

export function isUsableEnvelope(env: TokenEnvelope | undefined): boolean {
  if (env === undefined) {
    return false;
  }
  if (env.version !== ENVELOPE_VERSION) {
    return false;
  }
  if (env.keyAlias.length === 0) {
    return false;
  }
  if (env.ciphertext.length === 0) {
    return false;
  }
  return true;
}

// 序列化字段：v / acc / alias / alg / ct
export function serializeEnvelope(env: TokenEnvelope): string {
  return JSON.stringify({
    v: env.version,
    acc: env.accountId,
    alias: env.keyAlias,
    alg: env.algorithm,
    ct: env.ciphertext
  });
}

export function deserializeEnvelope(raw: string): TokenEnvelope | undefined {
  if (raw.length === 0) {
    return undefined;
  }
  let parsed: Record<string, ESObject> = {};
  try {
    parsed = JSON.parse(raw) as Record<string, ESObject>;
  } catch {
    return undefined;
  }
  if (parsed === undefined || parsed === null || typeof parsed !== 'object') {
    return undefined;
  }
  const v = Number(parsed['v']);
  const acc = String(parsed['acc'] ?? '');
  const alias = String(parsed['alias'] ?? '');
  const alg = String(parsed['alg'] ?? '');
  const ct = String(parsed['ct'] ?? '');
  if (Number.isNaN(v) || acc.length === 0 || alias.length === 0 || ct.length === 0) {
    return undefined;
  }
  return new TokenEnvelope(acc, alias, ct, alg, v);
}

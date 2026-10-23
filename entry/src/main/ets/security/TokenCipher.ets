import { asset } from '@kit.AssetStoreKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { utf8Decode, utf8Encode } from '../common/Codec';
import { CredentialStore } from './CredentialStore';

export const TOKEN_ALIAS: string = 'atomgit_mobile_token';

const DOMAIN = 0x0000;

// 凭据存于系统 Asset Store：只落 alias 与密文，不落明文密钥
export class TokenCipher implements CredentialStore {

  async save(token: string): Promise<void> {
    if (token.length === 0) {
      throw new Error('empty token');
    }
    const secret: asset.AssetMap = new Map();
    secret.set(asset.Tag.ALIAS, utf8Encode(TOKEN_ALIAS));
    secret.set(asset.Tag.SECRET, utf8Encode(token));
    secret.set(asset.Tag.REQUIRE_ATTR_ENCRYPTED, true);
    secret.set(asset.Tag.AUTH_TYPE, asset.AuthType.ANY);
    secret.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
    // 不设 IS_PERSISTENT：需 system_basic 权限，重启后凭据丢失
    secret.set(asset.Tag.CONFLICT_RESOLUTION, asset.ConflictResolution.OVERWRITE);
    try {
      await asset.add(secret);
    } catch (err) {
      const be = err as BusinessError;
      hilog.error(DOMAIN, 'AtomGit', 'asset add failed: %{public}d %{public}s',
        be.code ?? -1, be.message ?? '');
      throw err as Error;
    }
    hilog.info(DOMAIN, 'AtomGit', '%{public}s', 'token saved to asset store');
  }

  // 不存在、被撤销或无法解密时返回 undefined
  async load(): Promise<string | undefined> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, utf8Encode(TOKEN_ALIAS));
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    let rows: Array<asset.AssetMap> = [];
    try {
      rows = await asset.query(query);
    } catch (err) {
      const be = err as BusinessError;
      hilog.warn(DOMAIN, 'AtomGit', 'asset query failed: %{public}d', be.code ?? -1);
      return undefined;
    }
    if (rows === undefined || rows.length === 0) {
      return undefined;
    }
    const secret = rows[0].get(asset.Tag.SECRET);
    if (secret === undefined || !(secret instanceof Uint8Array)) {
      return undefined;
    }
    const token = utf8Decode(secret);
    return token.length === 0 ? undefined : token;
  }

  async exists(): Promise<boolean> {
    return (await this.load()) !== undefined;
  }

  async remove(): Promise<void> {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, utf8Encode(TOKEN_ALIAS));
    try {
      await asset.remove(query);
      hilog.info(DOMAIN, 'AtomGit', '%{public}s', 'token removed from asset store');
    } catch {
    }
  }
}

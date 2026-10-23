import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { AccountGuard, accountScopedKey } from '../security/TokenEnvelope';
import { CacheCleaner } from './StoragePorts';

const DOMAIN = 0x0000;

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'atomgit_cache.db',
  securityLevel: relationalStore.SecurityLevel.S2,
};

export function resolveCacheScope(guard: AccountGuard, key: string): string | undefined {
  if (!guard.isLoggedIn()) {
    return undefined;
  }
  return accountScopedKey(guard.current(), key);
}

export function resolveClearPrefix(guard: AccountGuard): string | undefined {
  if (!guard.isLoggedIn()) {
    return undefined;
  }
  return 'acc:' + guard.current() + ':';
}

export class CacheStore implements CacheCleaner {
  private rdb: relationalStore.RdbStore | undefined = undefined;
  private guard: AccountGuard;

  constructor(guard: AccountGuard) {
    this.guard = guard;
  }

  async open(ctx: common.Context): Promise<void> {
    try {
      this.rdb = await relationalStore.getRdbStore(ctx, STORE_CONFIG);
      await this.migrate();
    } catch (err) {
      const be = err as BusinessError;
      hilog.error(DOMAIN, 'AtomGit', 'open cache failed: %{public}d', be.code ?? -1);
    }
  }

  private async migrate(): Promise<void> {
    if (this.rdb === undefined) {
      return;
    }
    try {
      const ddl: string = 'CREATE TABLE IF NOT EXISTS cache ('
        + 'k TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)';
      await this.rdb.executeSql(ddl);
    } catch (err) {
      const be = err as BusinessError;
      hilog.warn(DOMAIN, 'AtomGit', 'migrate failed: %{public}d', be.code ?? -1);
    }
  }

  async put(key: string, payload: string): Promise<void> {
    if (this.rdb === undefined) {
      return;
    }
    const scoped = resolveCacheScope(this.guard, key);
    if (scoped === undefined) {
      return;
    }
    try {
      const sql: string = 'INSERT OR REPLACE INTO cache (k, payload, updated_at) VALUES (?, ?, ?)';
      await this.rdb.executeSql(sql, [scoped, payload, Date.now()]);
    } catch (err) {
      const be = err as BusinessError;
      hilog.warn(DOMAIN, 'AtomGit', 'cache put failed: %{public}d', be.code ?? -1);
    }
  }

  async get(key: string): Promise<string | undefined> {
    if (this.rdb === undefined) {
      return undefined;
    }
    const scoped = resolveCacheScope(this.guard, key);
    if (scoped === undefined) {
      return undefined;
    }
    try {
      const sql: string = 'SELECT payload FROM cache WHERE k = ?';
      // querySql 直接返回 ResultSet，无 rows 外层
      const result = await this.rdb.querySql(sql, [scoped]);
      if (result === undefined || result.rowCount === 0) {
        return undefined;
      }
      const value = result.getString(0);
      if (value === undefined || value === null) {
        return undefined;
      }
      return value;
    } catch (err) {
      const be = err as BusinessError;
      hilog.warn(DOMAIN, 'AtomGit', 'cache get failed: %{public}d', be.code ?? -1);
      return undefined;
    }
  }

  async remove(key: string): Promise<void> {
    if (this.rdb === undefined) {
      return;
    }
    const scoped = resolveCacheScope(this.guard, key);
    if (scoped === undefined) {
      return;
    }
    try {
      const sql: string = 'DELETE FROM cache WHERE k = ?';
      await this.rdb.executeSql(sql, [scoped]);
    } catch (err) {
      const be = err as BusinessError;
      hilog.warn(DOMAIN, 'AtomGit', 'cache remove failed: %{public}d', be.code ?? -1);
    }
  }

  async clearCurrentAccount(): Promise<void> {
    if (this.rdb === undefined) {
      return;
    }
    const prefix = resolveClearPrefix(this.guard);
    if (prefix === undefined) {
      return;
    }
    try {
      const sql: string = 'DELETE FROM cache WHERE k LIKE ?';
      await this.rdb.executeSql(sql, [prefix + '%']);
    } catch (err) {
      const be = err as BusinessError;
      hilog.warn(DOMAIN, 'AtomGit', 'clear cache failed: %{public}d', be.code ?? -1);
    }
  }
}

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { SettingsCleaner } from './StoragePorts';

const DOMAIN = 0x0000;
const PREF_NAME: string = 'atomgit_settings';

export class SettingsStore implements SettingsCleaner {
  private store: preferences.Preferences | undefined = undefined;

  async open(ctx: common.Context): Promise<void> {
    try {
      this.store = await preferences.getPreferences(ctx, PREF_NAME);
    } catch (err) {
      const be = err as BusinessError;
      hilog.error(DOMAIN, 'AtomGit', 'open settings failed: %{public}d', be.code ?? -1);
    }
  }

  async getString(key: string, fallback: string): Promise<string> {
    if (this.store === undefined) {
      return fallback;
    }
    try {
      const v = await this.store.get(key, fallback);
      return typeof v === 'string' ? v : fallback;
    } catch {
      return fallback;
    }
  }

  async putString(key: string, value: string): Promise<void> {
    if (this.store === undefined) {
      return;
    }
    try {
      await this.store.put(key, value);
      await this.store.flush();
    } catch (err) {
      const be = err as BusinessError;
      hilog.warn(DOMAIN, 'AtomGit', 'put %{public}s failed: %{public}d', key, be.code ?? -1);
    }
  }

  async getNumber(key: string, fallback: number): Promise<number> {
    if (this.store === undefined) {
      return fallback;
    }
    try {
      const v = await this.store.get(key, fallback);
      return typeof v === 'number' && Number.isFinite(v) ? v : fallback;
    } catch {
      return fallback;
    }
  }

  async putNumber(key: string, value: number): Promise<void> {
    if (this.store === undefined) {
      return;
    }
    try {
      await this.store.put(key, value);
      await this.store.flush();
    } catch (err) {
      const be = err as BusinessError;
      hilog.warn(DOMAIN, 'AtomGit', 'put %{public}s failed: %{public}d', key, be.code ?? -1);
    }
  }

  async delete(key: string): Promise<void> {
    if (this.store === undefined) {
      return;
    }
    try {
      await this.store.delete(key);
      await this.store.flush();
    } catch {
    }
  }

  async clear(): Promise<void> {
    if (this.store === undefined) {
      return;
    }
    try {
      await this.store.clear();
      await this.store.flush();
    } catch (err) {
      const be = err as BusinessError;
      hilog.warn(DOMAIN, 'AtomGit', 'clear settings failed: %{public}d', be.code ?? -1);
    }
  }
}

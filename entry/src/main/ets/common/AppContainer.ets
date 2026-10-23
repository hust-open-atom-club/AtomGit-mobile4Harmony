import { common } from '@kit.AbilityKit';

import { HttpClient, defaultConfig } from '../network/HttpClient';
import { AtomGitRepository } from '../repository/AtomGitRepository';
import { AccountGuard } from '../security/TokenEnvelope';
import { TokenCipher } from '../security/TokenCipher';
import { CacheStore } from '../storage/CacheStore';
import { SettingsStore } from '../storage/SettingsStore';
import { SessionStore } from '../viewmodel/SessionStore';
import { RepoBrowseStore } from '../viewmodel/RepoBrowseStore';

@ObservedV2
export class AppContainer {
  private readonly settings: SettingsStore;
  private readonly cache: CacheStore;
  readonly session: SessionStore;
  readonly repoBrowse: RepoBrowseStore;

  private readonly http: HttpClient;
  private readonly dataSource: AtomGitRepository;

  constructor(ctx: common.Context) {
    this.http = new HttpClient(defaultConfig());
    this.dataSource = new AtomGitRepository(this.http);
    const guard = new AccountGuard();
    const cipher = new TokenCipher();
    this.cache = new CacheStore(guard);
    this.settings = new SettingsStore();
    const cache = this.cache;
    const settings = this.settings;
    this.session = new SessionStore(this.dataSource, cipher, cache, settings, guard);
    this.repoBrowse = new RepoBrowseStore(this.dataSource);
    this.http.setTokenSource(this.session.tokenSource());
    this.settings.open(ctx);
    this.cache.open(ctx);
  }

  async bootstrap(): Promise<void> {
    await this.session.restore();
  }
}

import { common } from '@kit.AbilityKit';

import { HttpClient, defaultConfig } from '../network/HttpClient';
import { AtomGitRepository } from '../repository/AtomGitRepository';
import { AccountGuard } from '../security/TokenEnvelope';
import { TokenCipher } from '../security/TokenCipher';
import { CacheStore } from '../storage/CacheStore';
import { SettingsStore } from '../storage/SettingsStore';
import { SessionStore } from '../viewmodel/SessionStore';
import { RepoBrowseStore } from '../viewmodel/RepoBrowseStore';
import { RefreshCoordinator } from './RefreshCoordinator';

@ObservedV2
export class AppContainer {
  private readonly settings: SettingsStore;
  private readonly cache: CacheStore;
  readonly session: SessionStore;
  readonly repoBrowse: RepoBrowseStore;
  /** Shared in-process invalidation channel for feature stores. */
  readonly refresh: RefreshCoordinator;
  /** Current data source for session and repository browsing; collaboration ports are contracts only. */
  readonly repository: AtomGitRepository;

  private readonly http: HttpClient;

  constructor(ctx: common.Context) {
    this.http = new HttpClient(defaultConfig());
    this.repository = new AtomGitRepository(this.http);
    this.refresh = new RefreshCoordinator();
    const guard = new AccountGuard();
    const cipher = new TokenCipher();
    this.cache = new CacheStore(guard);
    this.settings = new SettingsStore();
    const cache = this.cache;
    const settings = this.settings;
    this.session = new SessionStore(this.repository, cipher, cache, settings, guard);
    this.repoBrowse = new RepoBrowseStore(this.repository);
    this.http.setTokenSource(this.session.tokenSource());
    this.settings.open(ctx);
    this.cache.open(ctx);
  }

  async bootstrap(): Promise<void> {
    await this.session.restore();
  }
}

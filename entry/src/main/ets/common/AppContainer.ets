import { common } from '@kit.AbilityKit';

import { HttpClient, defaultConfig } from '../network/HttpClient';
import { ActivityApiRepository } from '../repository/ActivityRepository';
import { AtomGitRepository } from '../repository/AtomGitRepository';
import { AccountGuard } from '../security/TokenEnvelope';
import { TokenCipher } from '../security/TokenCipher';
import { CacheStore } from '../storage/CacheStore';
import { SettingsStore } from '../storage/SettingsStore';
import { ActivityStore } from '../viewmodel/ActivityStore';
import { SessionStore } from '../viewmodel/SessionStore';
import { RepoBrowseStore } from '../viewmodel/RepoBrowseStore';
import { RefreshCoordinator } from './RefreshCoordinator';

@ObservedV2
export class AppContainer {
  private readonly settings: SettingsStore;
  private readonly cache: CacheStore;
  readonly session: SessionStore;
  readonly repoBrowse: RepoBrowseStore;
  /** Activity feed backed by its feature-specific repository port. */
  readonly activity: ActivityStore;
  /** Shared in-process invalidation channel for feature stores. */
  readonly refresh: RefreshCoordinator;
  /** Existing data source for session and repository browsing. */
  readonly coreRepository: AtomGitRepository;

  private readonly http: HttpClient;

  constructor(ctx: common.Context) {
    this.http = new HttpClient(defaultConfig());
    this.coreRepository = new AtomGitRepository(this.http);
    this.refresh = new RefreshCoordinator();
    const guard = new AccountGuard();
    const cipher = new TokenCipher();
    this.cache = new CacheStore(guard);
    this.settings = new SettingsStore();
    const cache = this.cache;
    const settings = this.settings;
    this.session = new SessionStore(this.coreRepository, cipher, cache, settings, guard);
    this.repoBrowse = new RepoBrowseStore(this.coreRepository);
    this.activity = new ActivityStore(new ActivityApiRepository(this.http));
    this.http.setTokenSource(this.session.tokenSource());
    this.settings.open(ctx);
    this.cache.open(ctx);
  }

  async bootstrap(): Promise<void> {
    await this.session.restore();
  }
}

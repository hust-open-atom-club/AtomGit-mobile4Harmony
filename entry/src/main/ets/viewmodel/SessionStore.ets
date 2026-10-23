import { ApiError, ApiErrorKind } from '../common/ApiError';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TokenSource } from '../network/HttpClient';
import { SessionReadRepository } from '../repository/Ports';
import { AccountGuard } from '../security/TokenEnvelope';
import { CredentialStore } from '../security/CredentialStore';
import { CacheCleaner, SettingsCleaner } from '../storage/StoragePorts';
import { CurrentUser, NamespaceItem, OrgSummary, RepoSummary } from '../model/Entities';

export enum LoadState {
  Idle = 'Idle',
  Loading = 'Loading',
  Refreshing = 'Refreshing',
  Ready = 'Ready',
  Error = 'Error',
}

class SessionTokenSource implements TokenSource {
  private readonly store: SessionStore;

  constructor(store: SessionStore) {
    this.store = store;
  }

  currentToken(): string | undefined {
    return this.store.peekToken();
  }
}

@ObservedV2
export class SessionStore {
  @Trace state: LoadState = LoadState.Idle;
  @Trace user: CurrentUser | undefined = undefined;
  // @Trace 镜像；isLoggedIn() 非响应式，视图层须读此字段
  @Trace loggedIn: boolean = false;
  @Trace repos: RepoSummary[] = [];
  // 触底续载依据：空页才置 false
  @Trace hasMoreRepos: boolean = true;
  @Trace orgs: OrgSummary[] = [];
  @Trace namespaces: NamespaceItem[] = [];
  @Trace errorMessage: string = '';
  @Trace needReLogin: boolean = false;

  private token: string = '';
  private page: number = 1;
  private readonly perPage: number = 20;

  private readonly dataSource: SessionReadRepository;
  private readonly cipher: CredentialStore;
  private readonly cache: CacheCleaner;
  private readonly settings: SettingsCleaner;
  private readonly guard: AccountGuard;

  constructor(dataSource: SessionReadRepository, cipher: CredentialStore,
    cache: CacheCleaner, settings: SettingsCleaner, guard: AccountGuard) {
    this.dataSource = dataSource;
    this.cipher = cipher;
    this.cache = cache;
    this.settings = settings;
    this.guard = guard;
  }

  peekToken(): string | undefined {
    return this.token.length > 0 ? this.token : undefined;
  }

  tokenSource(): TokenSource {
    return new SessionTokenSource(this);
  }

  isLoggedIn(): boolean {
    return this.guard.isLoggedIn();
  }

  async login(rawToken: string): Promise<boolean> {
    const candidate = rawToken.trim();
    if (candidate.length === 0) {
      this.errorMessage = '请输入访问令牌';
      this.state = LoadState.Error;
      return false;
    }
    this.state = LoadState.Loading;
    this.errorMessage = '';
    this.token = candidate;
    try {
      const user = await this.dataSource.currentUser();
      if (user.accountId.length === 0 || user.login.length === 0) {
        throw new ApiError(ApiErrorKind.Parse, 200, 0,
          'user payload incomplete', '', '/user');
      }
      await this.cipher.save(candidate);
      this.guard.setAccount(user.accountId);
      this.user = user;
      this.loggedIn = true;
      this.state = LoadState.Ready;
      await this.loadMine();
      return true;
    } catch (err) {
      this.token = '';
      this.user = undefined;
      this.guard.clear();
      this.loggedIn = false;
      hilog.error(0x0000, 'AtomGit', 'login failed: %{public}s :: %{public}s',
        err instanceof ApiError ? 'ApiError kind=' + err.kind.toString() : 'raw ' + (typeof err),
        err instanceof Error ? err.message : '');
      this.errorMessage = toUserMessage(err);
      this.needReLogin = err instanceof ApiError && err.requiresReLogin();
      this.state = LoadState.Error;
      return false;
    }
  }

  async restore(): Promise<boolean> {
    const saved = await this.cipher.load();
    if (saved === undefined || saved.length === 0) {
      this.state = LoadState.Idle;
      return false;
    }
    this.token = saved;
    try {
      const user = await this.dataSource.currentUser();
      if (user.accountId.length === 0) {
        throw new Error('user payload incomplete');
      }
      this.guard.setAccount(user.accountId);
      this.user = user;
      this.loggedIn = true;
      this.state = LoadState.Ready;
      await this.loadMine();
      return true;
    } catch (err) {
      await this.cipher.remove();
      this.token = '';
      this.guard.clear();
      this.user = undefined;
      this.needReLogin = true;
      this.errorMessage = toUserMessage(err);
      this.state = LoadState.Error;
      return false;
    }
  }

  async loadMine(): Promise<void> {
    await this.loadRepos();
    await this.loadOrgs();
  }

  // 平台可能返回短于 per_page 的非终页，空页才终止
  async loadRepos(): Promise<void> {
    if (!this.hasMoreRepos) {
      return;
    }
    try {
      const res = await this.dataSource.myRepos(this.page, this.perPage);
      this.repos = this.page === 1 ? res.items : this.repos.concat(res.items);
      this.hasMoreRepos = res.items.length > 0;
      this.page++;
      this.state = LoadState.Ready;
    } catch (err) {
      this.errorMessage = toUserMessage(err);
      this.state = LoadState.Error;
    }
  }

  async loadOrgs(): Promise<void> {
    const me = this.user;
    if (me === undefined) {
      return;
    }
    try {
      this.orgs = await this.dataSource.orgsOf(me.login);
      this.namespaces = await this.dataSource.myNamespaces();
    } catch (err) {
      this.errorMessage = toUserMessage(err);
    }
  }

  async refresh(): Promise<void> {
    this.page = 1;
    this.hasMoreRepos = true;
    this.state = LoadState.Refreshing;
    await this.loadMine();
    const failed: boolean = this.errorMessage.length > 0;
    if (!failed) {
      this.state = LoadState.Ready;
    }
  }

  async logout(): Promise<void> {
    this.guard.clear();
    this.token = '';
    this.user = undefined;
    this.loggedIn = false;
    this.repos = [];
    this.orgs = [];
    this.namespaces = [];
    this.page = 1;
    this.hasMoreRepos = true;
    this.errorMessage = '';
    this.needReLogin = false;
    this.state = LoadState.Idle;
    await this.cipher.remove();
    await this.cache.clearCurrentAccount();
    await this.settings.clear();
  }
}

function toUserMessage(err: Object): string {
  if (err instanceof ApiError) {
    return err.toUserMessage();
  }
  return '操作失败，请稍后重试';
}

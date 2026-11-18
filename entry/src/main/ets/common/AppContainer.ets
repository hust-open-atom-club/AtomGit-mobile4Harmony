import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { HttpClient, defaultConfig } from '../network/HttpClient';
import { ActivityApiRepository } from '../repository/ActivityRepository';
import { IssueApiRepository } from '../repository/IssueRepository';
import { PullRequestApiRepository } from '../repository/PullRequestRepository';
import { TodoApiRepository } from '../repository/TodoRepository';
import { PullRequestFilesOptions } from '../repository/Ports';
import { AtomGitRepository } from '../repository/AtomGitRepository';
import { AccountGuard } from '../security/TokenEnvelope';
import { TokenCipher } from '../security/TokenCipher';
import { CacheStore } from '../storage/CacheStore';
import { SettingsStore } from '../storage/SettingsStore';
import { RepositoryItemRef } from '../model/CollaborationEntities';
import { ActivityStore } from '../viewmodel/ActivityStore';
import { IssueDetailStore } from '../viewmodel/IssueDetailStore';
import { PullRequestDetailStore } from '../viewmodel/PullRequestDetailStore';
import { TodoStore } from '../viewmodel/TodoStore';
import { SessionStore } from '../viewmodel/SessionStore';
import { RepoBrowseStore } from '../viewmodel/RepoBrowseStore';
import { RefreshCoordinator, RefreshDomain, RefreshEvent } from './RefreshCoordinator';

@ObservedV2
export class AppContainer {
  private readonly settings: SettingsStore;
  private readonly cache: CacheStore;
  readonly session: SessionStore;
  readonly repoBrowse: RepoBrowseStore;
  /** Activity feed backed by its feature-specific repository port. */
  readonly activity: ActivityStore;
  /** Issue detail and comment collaboration repository. */
  readonly issueRepository: IssueApiRepository;
  /** Shared Issue detail state, reset when the routed reference changes. */
  readonly issueDetail: IssueDetailStore;
  /** Pull request detail, diff, comment, and approval repository. */
  readonly pullRequestRepository: PullRequestApiRepository;
  /** Shared pull request review state for the routed reference. */
  readonly pullRequestDetail: PullRequestDetailStore;
  /** Todo workbench repository for the authenticated user. */
  readonly todoRepository: TodoApiRepository;
  /** Shared Todo workbench state for the authenticated user. */
  readonly todo: TodoStore;
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
    this.issueRepository = new IssueApiRepository(this.http);
    this.todoRepository = new TodoApiRepository(this.http);
    this.todo = new TodoStore(this.todoRepository);
    this.issueDetail = new IssueDetailStore(this.issueRepository, (ref: RepositoryItemRef) => {
      this.publishCollaborationRefresh(RefreshDomain.Issue, ref);
    });
    this.pullRequestRepository = new PullRequestApiRepository(this.http);
    this.pullRequestDetail = new PullRequestDetailStore(this.pullRequestRepository, '', 20,
      new PullRequestFilesOptions(), () => {
        const ref = this.pullRequestDetail.ref;
        if (ref !== undefined) {
          this.publishCollaborationRefresh(RefreshDomain.PullRequest, ref);
        }
      }, (ref: RepositoryItemRef) => {
        this.publishCollaborationRefresh(RefreshDomain.PullRequest, ref);
      });
    this.http.setTokenSource(this.session.tokenSource());
    this.settings.open(ctx);
    this.cache.open(ctx);
    this.subscribeTodoRefresh();
  }

  async bootstrap(): Promise<void> {
    await this.session.restore();
    this.syncCollaborationUser();
  }

  /** Keep user-specific approval readback aligned after login or restore. */
  syncCollaborationUser(): void {
    const login = this.session.user === undefined ? '' : this.session.user.login;
    this.pullRequestRepository.setCurrentUser(login);
    this.pullRequestDetail.setCurrentUser(login);
  }

  private publishCollaborationRefresh(domain: RefreshDomain, ref: RepositoryItemRef): void {
    const user = this.session.user;
    if (user === undefined) {
      return;
    }
    this.refresh.publish(domain, user.accountId, 'collaboration-write-confirmed',
      ref.owner + '/' + ref.repo, ref.key());
  }

  private subscribeTodoRefresh(): void {
    this.refresh.subscribe((event: RefreshEvent) => {
      if (event.domain !== RefreshDomain.Issue && event.domain !== RefreshDomain.PullRequest) {
        return;
      }
      this.todo.refreshForAccount(event.accountId).catch((err: Error) => {
        hilog.warn(0x0000, 'AtomGit', 'Todo refresh failed: %{public}s', err.message);
      });
    });
  }
}

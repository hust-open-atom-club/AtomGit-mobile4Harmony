import { common } from '@kit.AbilityKit';

import { HttpClient, defaultConfig } from '../network/HttpClient';
import { ActivityApiRepository } from '../repository/ActivityRepository';
import { IssueApiRepository } from '../repository/IssueRepository';
import { PullRequestApiRepository } from '../repository/PullRequestRepository';
import { PullRequestFilesOptions } from '../repository/Ports';
import { AtomGitRepository } from '../repository/AtomGitRepository';
import { AccountGuard } from '../security/TokenEnvelope';
import { TokenCipher } from '../security/TokenCipher';
import { CacheStore } from '../storage/CacheStore';
import { SettingsStore } from '../storage/SettingsStore';
import { ActivityStore } from '../viewmodel/ActivityStore';
import { IssueDetailStore } from '../viewmodel/IssueDetailStore';
import { PullRequestDetailStore } from '../viewmodel/PullRequestDetailStore';
import { SessionStore } from '../viewmodel/SessionStore';
import { RepoBrowseStore } from '../viewmodel/RepoBrowseStore';
import { RefreshCoordinator, RefreshDomain } from './RefreshCoordinator';

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
    this.issueDetail = new IssueDetailStore(this.issueRepository);
    this.pullRequestRepository = new PullRequestApiRepository(this.http);
    this.pullRequestDetail = new PullRequestDetailStore(this.pullRequestRepository, '', 20,
      new PullRequestFilesOptions(), () => {
        const user = this.session.user;
        const ref = this.pullRequestDetail.ref;
        if (user !== undefined && ref !== undefined) {
          this.refresh.publish(RefreshDomain.PullRequest, user.accountId,
            'approval-confirmed', ref.owner + '/' + ref.repo, ref.key());
        }
      });
    this.http.setTokenSource(this.session.tokenSource());
    this.settings.open(ctx);
    this.cache.open(ctx);
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
}

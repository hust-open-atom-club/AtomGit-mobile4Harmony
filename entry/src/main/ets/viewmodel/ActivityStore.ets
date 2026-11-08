import { ApiError, ApiErrorKind } from '../common/ApiError';
import { CancelToken } from '../network/HttpClient';
import {
  CursorPageRequest,
  OffsetPageRequest,
  Page,
  PageRequest
} from '../common/Pager';
import { ActivityItem } from '../model/CollaborationEntities';
import { RepoSummary } from '../model/Entities';
import { ActivityRepository } from '../repository/Ports';
import { LoadState } from './SessionStore';

export enum ActivitySource {
  Personal = 'personal',
  Project = 'project'
}

export class ActivityDay {
  readonly key: string;
  readonly label: string;
  readonly items: ActivityItem[];

  constructor(key: string, label: string, items: ActivityItem[]) {
    this.key = key;
    this.label = label;
    this.items = items;
  }
}

class EmptyActivityRepository implements ActivityRepository {
  async personalActivity(username: string, year: number, request: PageRequest):
    Promise<Page<ActivityItem>> {
    return Page.empty<ActivityItem>(request);
  }

  async repositoryActivity(owner: string, repo: string, request: PageRequest):
    Promise<Page<ActivityItem>> {
    return Page.empty<ActivityItem>(request);
  }
}

@ObservedV2
export class ActivityStore {
  @Trace state: LoadState = LoadState.Idle;
  @Trace source: ActivitySource = ActivitySource.Personal;
  @Trace items: ActivityItem[] = [];
  @Trace days: ActivityDay[] = [];
  @Trace projects: RepoSummary[] = [];
  @Trace selectedProjectKey: string = '';
  @Trace hasMore: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace errorMessage: string = '';
  @Trace lastUpdatedAt: string = '';

  private readonly dataSource: ActivityRepository;
  private accountId: string = '';
  private login: string = '';
  private year: number = new Date().getFullYear();

  private personalItems: ActivityItem[] = [];
  private projectItems: ActivityItem[] = [];
  private personalRequest: PageRequest = new CursorPageRequest();
  private projectRequest: OffsetPageRequest = new OffsetPageRequest();
  private personalHasMore: boolean = false;
  private projectHasMore: boolean = false;
  private personalReady: boolean = false;
  private projectReady: boolean = false;
  private personalError: string = '';
  private projectError: string = '';
  private busy: boolean = false;
  private revision: number = 0;
  private cancelToken: CancelToken | undefined = undefined;

  constructor(dataSource: ActivityRepository) {
    this.dataSource = dataSource;
  }

  initialize(accountId: string, login: string, projects: RepoSummary[]): void {
    const accountChanged = this.accountId.length > 0 && this.accountId !== accountId;
    const loginChanged = this.login.length > 0 && this.login !== login;
    this.setProjects(projects);
    if (accountChanged || loginChanged) {
      this.reset();
    }
    this.accountId = accountId;
    this.login = login;
    this.year = new Date().getFullYear();
  }

  async openPersonal(): Promise<void> {
    if (!this.switchSource(ActivitySource.Personal)) {
      return;
    }
    if (!this.personalReady) {
      await this.load(true);
    }
  }

  async openProjects(): Promise<void> {
    this.switchSource(ActivitySource.Project);
    const repo = this.selectedProject();
    if (repo === undefined) {
      this.items = [];
      this.days = [];
      this.hasMore = false;
      this.errorMessage = '';
      this.state = LoadState.Ready;
      return;
    }
    if (!this.projectReady) {
      await this.load(true);
    }
  }

  async openProject(owner: string, repo: string): Promise<void> {
    const key = owner + '/' + repo;
    if (this.selectedProjectKey !== key) {
      this.selectedProjectKey = key;
      this.projectItems = [];
      this.projectRequest = new OffsetPageRequest();
      this.projectHasMore = false;
      this.projectReady = false;
      this.projectError = '';
    }
    if (!this.switchSource(ActivitySource.Project)) {
      return;
    }
    if (!this.projectReady) {
      await this.load(true);
    }
  }

  async refresh(): Promise<void> {
    if (this.busy) {
      return;
    }
    await this.load(true);
  }

  async loadMore(): Promise<void> {
    if (this.busy || !this.hasMore || this.items.length === 0) {
      return;
    }
    await this.load(false);
  }

  retry(): Promise<void> {
    return this.load(true);
  }

  cancelPending(): void {
    const wasBusy = this.busy;
    this.cancelActiveRequest();
    if (wasBusy && this.items.length === 0) {
      this.state = LoadState.Idle;
    } else if (this.state === LoadState.Refreshing) {
      this.state = LoadState.Ready;
    }
  }

  hasProjects(): boolean {
    return this.projects.length > 0;
  }

  selectedProject(): RepoSummary | undefined {
    for (const repo of this.projects) {
      if (repo.owner + '/' + repo.name === this.selectedProjectKey) {
        return repo;
      }
    }
    return undefined;
  }

  private setProjects(projects: RepoSummary[]): void {
    this.projects = projects.slice();
    if (projects.length === 0) {
      this.selectedProjectKey = '';
      return;
    }
    for (const repo of projects) {
      if (repo.owner + '/' + repo.name === this.selectedProjectKey) {
        return;
      }
    }
    this.selectedProjectKey = projects[0].owner + '/' + projects[0].name;
    this.projectReady = false;
    this.projectItems = [];
    this.projectRequest = new OffsetPageRequest();
    this.projectHasMore = false;
    this.projectError = '';
    if (this.source === ActivitySource.Project) {
      this.commitActive();
    }
  }

  private switchSource(source: ActivitySource): boolean {
    if (this.source === source) {
      return true;
    }
    this.cancelActiveRequest();
    this.source = source;
    this.commitActive();
    return true;
  }

  private async load(reset: boolean): Promise<void> {
    if (this.busy || this.accountId.length === 0) {
      return;
    }
    const source = this.source;
    if (reset) {
      this.resetRequest(source);
    }
    const request = this.requestFor(source);
    if (request === undefined) {
      this.items = [];
      this.days = [];
      this.hasMore = false;
      this.state = LoadState.Ready;
      return;
    }
    this.cancelActiveRequest();
    this.busy = true;
    this.errorMessage = '';
    if (reset) {
      this.state = this.items.length > 0 ? LoadState.Refreshing : LoadState.Loading;
    } else {
      this.loadingMore = true;
    }
    const token = new CancelToken();
    this.cancelToken = token;
    const revision = ++this.revision;
    try {
      const page = source === ActivitySource.Personal
        ? await this.dataSource.personalActivity(this.login, this.year, request, token)
        : await this.dataSource.repositoryActivity(this.projectOwner(), this.projectName(), request, token);
      if (revision !== this.revision || token.isCanceled()) {
        return;
      }
      const current = reset ? [] : this.items.slice();
      const merged = mergeUnique(current, page.items);
      if (source === ActivitySource.Personal) {
        this.personalItems = merged;
        this.personalRequest = page.nextRequest === undefined
          ? new CursorPageRequest() : page.nextRequest;
        this.personalHasMore = page.hasMore;
        this.personalReady = true;
        this.personalError = '';
      } else {
        this.projectItems = merged;
        this.projectRequest = page.nextRequest instanceof OffsetPageRequest
          ? page.nextRequest : request as OffsetPageRequest;
        this.projectHasMore = page.hasMore;
        this.projectReady = true;
        this.projectError = '';
      }
      this.lastUpdatedAt = formatClock(new Date());
      this.commitActive();
    } catch (err) {
      if (revision !== this.revision || token.isCanceled()) {
        return;
      }
      if (err instanceof ApiError && err.kind === ApiErrorKind.Canceled) {
        return;
      }
      const message = err instanceof ApiError ? err.toUserMessage() : 'Unable to load activity';
      if (source === ActivitySource.Personal) {
        this.personalError = message;
        if (this.personalItems.length === 0) {
          this.personalReady = false;
        }
      } else {
        this.projectError = message;
        if (this.projectItems.length === 0) {
          this.projectReady = false;
        }
      }
      if (this.source === source) {
        this.errorMessage = message;
        this.state = this.items.length === 0 ? LoadState.Error : LoadState.Ready;
      }
    } finally {
      if (revision === this.revision) {
        this.busy = false;
        this.loadingMore = false;
        if (this.errorMessage.length === 0) {
          this.state = LoadState.Ready;
        }
      }
    }
  }

  private requestFor(source: ActivitySource): PageRequest | undefined {
    if (source === ActivitySource.Personal) {
      return this.personalRequest;
    }
    if (this.selectedProjectKey.length === 0) {
      return undefined;
    }
    return this.projectRequest;
  }

  private resetRequest(source: ActivitySource): void {
    if (source === ActivitySource.Personal) {
      this.personalRequest = new CursorPageRequest();
    } else {
      this.projectRequest = new OffsetPageRequest();
    }
  }

  private projectOwner(): string {
    const repo = this.selectedProject();
    return repo === undefined ? '' : repo.owner;
  }

  private projectName(): string {
    const repo = this.selectedProject();
    return repo === undefined ? '' : repo.name;
  }

  private commitActive(): void {
    if (this.source === ActivitySource.Personal) {
      this.items = this.personalItems.slice();
      this.hasMore = this.personalHasMore;
      this.errorMessage = this.personalError;
    } else {
      this.items = this.projectItems.slice();
      this.hasMore = this.projectHasMore;
      this.errorMessage = this.projectError;
    }
    this.days = groupByDay(this.items);
    if (this.errorMessage.length > 0) {
      this.state = this.items.length === 0 ? LoadState.Error : LoadState.Ready;
    }
  }

  private cancelActiveRequest(): void {
    if (this.cancelToken !== undefined) {
      this.cancelToken.cancel();
      this.cancelToken = undefined;
    }
    this.revision++;
    this.busy = false;
    this.loadingMore = false;
  }

  private reset(): void {
    this.cancelActiveRequest();
    this.personalItems = [];
    this.projectItems = [];
    this.personalRequest = new CursorPageRequest();
    this.projectRequest = new OffsetPageRequest();
    this.personalHasMore = false;
    this.projectHasMore = false;
    this.personalReady = false;
    this.projectReady = false;
    this.personalError = '';
    this.projectError = '';
    this.items = [];
    this.days = [];
    this.hasMore = false;
    this.loadingMore = false;
    this.errorMessage = '';
    this.lastUpdatedAt = '';
    this.state = LoadState.Idle;
  }
}

function mergeUnique(previous: ActivityItem[], incoming: ActivityItem[]): ActivityItem[] {
  const result: ActivityItem[] = [];
  const seen: Set<string> = new Set<string>();
  for (const item of previous.concat(incoming)) {
    if (!seen.has(item.id)) {
      seen.add(item.id);
      result.push(item);
    }
  }
  result.sort((a: ActivityItem, b: ActivityItem) => timestamp(b.createdAt) - timestamp(a.createdAt));
  return result;
}

function timestamp(value: string): number {
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function dateKey(date: Date): string {
  return date.getFullYear().toString() + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate());
}

function pad(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

function formatClock(date: Date): string {
  return pad(date.getHours()) + ':' + pad(date.getMinutes());
}

function groupByDay(items: ActivityItem[]): ActivityDay[] {
  const groups: ActivityDay[] = [];
  const today = new Date();
  const yesterday = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 1);
  for (const item of items) {
    const parsed = new Date(item.createdAt);
    const valid = !Number.isNaN(parsed.getTime());
    const key = valid ? dateKey(parsed) : 'unknown';
    let group = groups.find((candidate: ActivityDay) => candidate.key === key);
    if (group === undefined) {
      const label = !valid ? 'Unknown date'
        : key === dateKey(today) ? 'Today'
          : key === dateKey(yesterday) ? 'Yesterday'
            : monthName(parsed.getMonth()) + ' ' + parsed.getDate().toString() + ', '
              + parsed.getFullYear().toString();
      group = new ActivityDay(key, label, []);
      groups.push(group);
    }
    group.items.push(item);
  }
  return groups;
}

function monthName(month: number): string {
  const names: string[] = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return names[month];
}

export class EmptyActivityStore extends ActivityStore {
  constructor() {
    super(new EmptyActivityRepository());
  }
}

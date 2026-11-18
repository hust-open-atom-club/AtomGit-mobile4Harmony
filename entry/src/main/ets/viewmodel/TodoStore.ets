import { ApiError, ApiErrorKind } from '../common/ApiError';
import { CancellationSignal } from '../common/Cancellation';
import { OffsetPageRequest, Page, PageRequest } from '../common/Pager';
import { CancelToken } from '../network/HttpClient';
import { WorkItem } from '../model/CollaborationEntities';
import { PullRequestTodoScope, TodoRepository } from '../repository/Ports';

export enum TodoCategory {
  Pending = 'pending',
  Created = 'created'
}

export enum TodoScope {
  AssignedIssues = 'assigned_issues',
  AssignedPullRequests = 'assigned_pull_requests',
  NeedsApprovalPullRequests = 'needs_approval_pull_requests',
  NeedsReviewPullRequests = 'needs_review_pull_requests',
  CreatedIssues = 'created_issues',
  CreatedPullRequests = 'created_pull_requests'
}

function allScopes(): TodoScope[] {
  return [
    TodoScope.AssignedIssues,
    TodoScope.AssignedPullRequests,
    TodoScope.NeedsApprovalPullRequests,
    TodoScope.NeedsReviewPullRequests,
    TodoScope.CreatedIssues,
    TodoScope.CreatedPullRequests
  ];
}

export function scopesForCategory(category: TodoCategory): TodoScope[] {
  return category === TodoCategory.Pending
    ? [
      TodoScope.AssignedIssues,
      TodoScope.AssignedPullRequests,
      TodoScope.NeedsApprovalPullRequests,
      TodoScope.NeedsReviewPullRequests
    ]
    : [TodoScope.CreatedIssues, TodoScope.CreatedPullRequests];
}

@ObservedV2
export class TodoScopeState {
  readonly scope: TodoScope;
  @Trace items: WorkItem[] = [];
  @Trace loading: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace hasMore: boolean = false;
  @Trace errorMessage: string = '';
  @Trace ready: boolean = false;

  request: OffsetPageRequest = new OffsetPageRequest();
  revision: number = 0;
  retryFromStart: boolean = true;
  cancelToken: CancelToken | undefined = undefined;

  constructor(scope: TodoScope) {
    this.scope = scope;
  }

  begin(reset: boolean): number {
    this.cancel();
    this.revision++;
    this.errorMessage = '';
    this.retryFromStart = reset;
    this.loading = reset;
    this.loadingMore = !reset;
    return this.revision;
  }

  reset(): void {
    this.cancel();
    this.revision++;
    this.items = [];
    this.loading = false;
    this.loadingMore = false;
    this.hasMore = false;
    this.errorMessage = '';
    this.ready = false;
    this.request = new OffsetPageRequest();
    this.retryFromStart = true;
  }

  cancel(): void {
    if (this.cancelToken !== undefined) {
      this.cancelToken.cancel();
      this.cancelToken = undefined;
    }
  }
}

class EmptyTodoRepository implements TodoRepository {
  async assignedIssues(request: PageRequest): Promise<Page<WorkItem>> {
    return Page.empty<WorkItem>(request);
  }

  async createdIssues(request: PageRequest): Promise<Page<WorkItem>> {
    return Page.empty<WorkItem>(request);
  }

  async pullRequests(scope: PullRequestTodoScope, request: PageRequest): Promise<Page<WorkItem>> {
    return Page.empty<WorkItem>(request);
  }
}

function itemKey(item: WorkItem): string {
  return item.kind + '|' + item.ref.key();
}

function mergeUnique(previous: WorkItem[], incoming: WorkItem[]): WorkItem[] {
  const result: WorkItem[] = [];
  const seen: Set<string> = new Set<string>();
  for (const item of previous.concat(incoming)) {
    const key = itemKey(item);
    if (!seen.has(key)) {
      seen.add(key);
      result.push(item);
    }
  }
  result.sort((left: WorkItem, right: WorkItem) => {
    const difference = timestamp(right.updatedAt) - timestamp(left.updatedAt);
    return difference === 0 ? itemKey(left).localeCompare(itemKey(right)) : difference;
  });
  return result;
}

function timestamp(value: string): number {
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function errorText(error: Object): string {
  if (!(error instanceof ApiError)) {
    return 'The request failed. Try again.';
  }
  switch (error.kind) {
    case ApiErrorKind.Unauthorized:
      return 'Your session has expired. Sign in again.';
    case ApiErrorKind.Forbidden:
      return 'You do not have permission to view this source.';
    case ApiErrorKind.NotFound:
      return 'This source is no longer available.';
    case ApiErrorKind.RateLimited:
      return 'Too many requests. Try again shortly.';
    case ApiErrorKind.ServerError:
      return 'AtomGit is temporarily unavailable.';
    case ApiErrorKind.Network:
      return 'The network connection is unavailable.';
    case ApiErrorKind.Parse:
      return 'The server returned data in an unexpected format.';
    case ApiErrorKind.Canceled:
      return '';
    default:
      return 'The request failed. Try again.';
  }
}

@ObservedV2
export class TodoStore {
  private readonly dataSource: TodoRepository;
  private accountKey: string = '';
  private projectKey: string = '';
  private generation: number = 0;

  private assignedIssuesState: TodoScopeState = new TodoScopeState(TodoScope.AssignedIssues);
  private assignedPullRequestsState: TodoScopeState =
    new TodoScopeState(TodoScope.AssignedPullRequests);
  private needsApprovalState: TodoScopeState =
    new TodoScopeState(TodoScope.NeedsApprovalPullRequests);
  private needsReviewState: TodoScopeState =
    new TodoScopeState(TodoScope.NeedsReviewPullRequests);
  private createdIssuesState: TodoScopeState = new TodoScopeState(TodoScope.CreatedIssues);
  private createdPullRequestsState: TodoScopeState =
    new TodoScopeState(TodoScope.CreatedPullRequests);

  constructor(dataSource: TodoRepository) {
    this.dataSource = dataSource;
  }

  initialize(accountId: string, projectScope: string = ''): void {
    const nextAccount = accountId.trim();
    const nextProject = projectScope.trim();
    if (nextAccount === this.accountKey && nextProject === this.projectKey) {
      return;
    }
    this.reset();
    this.accountKey = nextAccount;
    this.projectKey = nextProject;
  }

  stateFor(scope: TodoScope): TodoScopeState {
    switch (scope) {
      case TodoScope.AssignedIssues:
        return this.assignedIssuesState;
      case TodoScope.AssignedPullRequests:
        return this.assignedPullRequestsState;
      case TodoScope.NeedsApprovalPullRequests:
        return this.needsApprovalState;
      case TodoScope.NeedsReviewPullRequests:
        return this.needsReviewState;
      case TodoScope.CreatedIssues:
        return this.createdIssuesState;
      default:
        return this.createdPullRequestsState;
    }
  }

  async loadAll(): Promise<void> {
    const tasks: Promise<void>[] = [];
    for (const scope of allScopes()) {
      tasks.push(this.load(scope, true));
    }
    await Promise.all(tasks);
  }

  async loadCategory(category: TodoCategory): Promise<void> {
    const tasks: Promise<void>[] = [];
    for (const scope of scopesForCategory(category)) {
      tasks.push(this.load(scope, true));
    }
    await Promise.all(tasks);
  }

  async refresh(): Promise<void> {
    await this.loadAll();
  }

  async refreshScope(scope: TodoScope): Promise<void> {
    await this.load(scope, true);
  }

  async ensureLoaded(scope: TodoScope): Promise<void> {
    const state = this.stateFor(scope);
    if (!state.ready && !state.loading && !state.loadingMore) {
      await this.load(scope, true);
    }
  }

  async loadMore(scope: TodoScope): Promise<void> {
    const state = this.stateFor(scope);
    if (state.loading || state.loadingMore || !state.hasMore || state.items.length === 0) {
      return;
    }
    await this.load(scope, false);
  }

  async retry(scope: TodoScope): Promise<void> {
    const state = this.stateFor(scope);
    if (state.retryFromStart) {
      await this.load(scope, true);
    } else {
      await this.load(scope, false);
    }
  }

  cancelPending(): void {
    this.generation++;
    for (const scope of allScopes()) {
      const state = this.stateFor(scope);
      state.cancel();
      state.revision++;
      state.loading = false;
      state.loadingMore = false;
    }
  }

  loadedCount(scope: TodoScope): number {
    return this.stateFor(scope).items.length;
  }

  categoryLoadedCount(category: TodoCategory): number {
    const seen: Set<string> = new Set<string>();
    for (const scope of scopesForCategory(category)) {
      for (const item of this.stateFor(scope).items) {
        seen.add(itemKey(item));
      }
    }
    return seen.size;
  }

  failedScopeCount(category: TodoCategory): number {
    let count = 0;
    for (const scope of scopesForCategory(category)) {
      if (this.stateFor(scope).errorMessage.length > 0) {
        count++;
      }
    }
    return count;
  }

  scopeCountText(scope: TodoScope): string {
    const state = this.stateFor(scope);
    if (state.loading && state.items.length === 0) {
      return 'Loading';
    }
    if (state.errorMessage.length > 0 && state.items.length === 0) {
      return 'Unavailable';
    }
    return state.items.length.toString() + ' loaded';
  }

  private async load(scope: TodoScope, reset: boolean): Promise<void> {
    const state = this.stateFor(scope);
    if (!reset && (state.loading || state.loadingMore || !state.hasMore
      || state.items.length === 0)) {
      return;
    }
    const revision = state.begin(reset);
    const generation = this.generation;
    const request = reset ? new OffsetPageRequest() : state.request;
    const token = new CancelToken();
    state.cancelToken = token;
    try {
      const page = await this.request(scope, request, token);
      if (!this.isCurrent(state, revision, generation)) {
        return;
      }
      state.items = reset ? mergeUnique([], page.items) : mergeUnique(state.items, page.items);
      state.hasMore = page.hasMore;
      state.request = page.nextRequest instanceof OffsetPageRequest
        ? page.nextRequest : new OffsetPageRequest(request.page, request.perPage);
      state.ready = true;
      state.errorMessage = '';
    } catch (error) {
      if (!this.isCurrent(state, revision, generation)) {
        return;
      }
      const message = errorText(error as Object);
      if (message.length > 0) {
        state.errorMessage = message;
        state.retryFromStart = reset;
        state.ready = state.items.length > 0;
      }
    } finally {
      if (this.isCurrent(state, revision, generation)) {
        state.loading = false;
        state.loadingMore = false;
        state.cancelToken = undefined;
      }
    }
  }

  private request(scope: TodoScope, request: PageRequest,
    cancel: CancellationSignal): Promise<Page<WorkItem>> {
    switch (scope) {
      case TodoScope.AssignedIssues:
        return this.dataSource.assignedIssues(request, cancel);
      case TodoScope.CreatedIssues:
        return this.dataSource.createdIssues(request, cancel);
      case TodoScope.AssignedPullRequests:
        return this.dataSource.pullRequests(PullRequestTodoScope.AssignedToMe, request, cancel);
      case TodoScope.NeedsApprovalPullRequests:
        return this.dataSource.pullRequests(PullRequestTodoScope.NeedsApproval, request, cancel);
      case TodoScope.NeedsReviewPullRequests:
        return this.dataSource.pullRequests(PullRequestTodoScope.NeedsReview, request, cancel);
      default:
        return this.dataSource.pullRequests(PullRequestTodoScope.CreatedByMe, request, cancel);
    }
  }

  private isCurrent(state: TodoScopeState, revision: number, generation: number): boolean {
    return state.revision === revision && this.generation === generation;
  }

  private reset(): void {
    this.generation++;
    for (const scope of allScopes()) {
      this.stateFor(scope).reset();
    }
  }
}

export class EmptyTodoStore extends TodoStore {
  constructor() {
    super(new EmptyTodoRepository());
  }
}

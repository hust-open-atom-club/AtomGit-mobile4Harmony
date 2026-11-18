import { ApiError, ApiErrorKind } from '../common/ApiError';
import { CancelToken } from '../network/HttpClient';
import { OffsetPageRequest, Page, PageRequest } from '../common/Pager';
import {
  CollaborationComment,
  IssueDetail,
  RepositoryItemRef
} from '../model/CollaborationEntities';
import { IssueRepository } from '../repository/Ports';
import { LoadState } from './SessionStore';

const COMMENT_READBACK_PAGE_SIZE: number = 100;
const MAX_COMMENT_READBACK_PAGES: number = 100;

class EmptyIssueRepository implements IssueRepository {
  async issue(ref: RepositoryItemRef): Promise<IssueDetail> {
    return new IssueDetail(ref, '', '', '', '', '', '', '', []);
  }

  async issueComments(ref: RepositoryItemRef, request: PageRequest):
    Promise<Page<CollaborationComment>> {
    return Page.empty<CollaborationComment>(request);
  }

  async addIssueComment(ref: RepositoryItemRef, body: string): Promise<void> {
  }
}

function mergeUnique(previous: CollaborationComment[],
  incoming: CollaborationComment[]): CollaborationComment[] {
  const result: CollaborationComment[] = [];
  const seen: Set<string> = new Set<string>();
  for (const comment of previous.concat(incoming)) {
    if (!seen.has(comment.id)) {
      seen.add(comment.id);
      result.push(comment);
    }
  }
  return result;
}

function isCanceled(err: Object): boolean {
  return err instanceof ApiError && err.kind === ApiErrorKind.Canceled;
}

function errorMessage(err: Object, fallback: string): string {
  if (!(err instanceof ApiError)) {
    return fallback;
  }
  switch (err.kind) {
    case ApiErrorKind.Unauthorized:
      return 'Your session has expired. Sign in again.';
    case ApiErrorKind.Forbidden:
      return 'You do not have permission to access this issue.';
    case ApiErrorKind.NotFound:
      return 'This issue or comment could not be found.';
    case ApiErrorKind.MethodNotAllowed:
      return 'This operation is not supported.';
    case ApiErrorKind.Conflict:
      return 'The issue changed. Refresh and try again.';
    case ApiErrorKind.UnsafeRequest:
      return 'The request was blocked by the security policy.';
    case ApiErrorKind.Unprocessable:
      return 'The comment was rejected. Check the text and try again.';
    case ApiErrorKind.RateLimited:
      return 'Too many requests. Try again shortly.';
    case ApiErrorKind.ServerError:
      return 'AtomGit is temporarily unavailable.';
    case ApiErrorKind.Network:
      return 'Network connection is unavailable.';
    case ApiErrorKind.Parse:
      return 'The server returned an invalid issue response.';
    case ApiErrorKind.Canceled:
      return 'Request canceled.';
    default:
      return fallback;
  }
}

@ObservedV2
export class IssueDetailStore {
  @Trace state: LoadState = LoadState.Idle;
  @Trace issue: IssueDetail | undefined = undefined;
  @Trace comments: CollaborationComment[] = [];
  @Trace hasMore: boolean = false;
  @Trace loadingMore: boolean = false;
  @Trace sending: boolean = false;
  @Trace empty: boolean = true;
  @Trace errorMessage: string = '';
  @Trace commentError: string = '';
  @Trace sendErrorMessage: string = '';
  @Trace successMessage: string = '';
  @Trace commentPosted: boolean = false;
  @Trace draft: string = '';
  @Trace lastUpdatedAt: string = '';

  private readonly dataSource: IssueRepository;
  private readonly commentPostedCallback: (ref: RepositoryItemRef) => void;
  private ref: RepositoryItemRef = new RepositoryItemRef('', '', 0);
  private request: OffsetPageRequest = new OffsetPageRequest();
  private busy: boolean = false;
  private revision: number = 0;
  private cancelToken: CancelToken | undefined = undefined;

  constructor(dataSource: IssueRepository,
    onCommentPosted: (ref: RepositoryItemRef) => void = () => {}) {
    this.dataSource = dataSource;
    this.commentPostedCallback = onCommentPosted;
  }

  initialize(ref: RepositoryItemRef): void {
    const changed = this.ref.key() !== ref.key();
    if (changed) {
      this.cancelActiveRequest();
      this.reset();
    }
    this.ref = ref;
  }

  async load(): Promise<void> {
    if (this.busy || !this.validRef()) {
      return;
    }
    if (this.issue !== undefined && this.state === LoadState.Ready) {
      return;
    }
    const token = this.startRequest();
    const revision = this.revision;
    let detailLoaded: boolean = false;
    this.state = LoadState.Loading;
    this.errorMessage = '';
    this.commentError = '';
    this.sendErrorMessage = '';
    this.successMessage = '';
    this.commentPosted = false;
    try {
      const issue = await this.dataSource.issue(this.ref, token);
      if (!this.isCurrent(revision, token)) {
        return;
      }
      detailLoaded = true;
      this.issue = issue;
      const page = await this.dataSource.issueComments(this.ref, new OffsetPageRequest(), token);
      if (!this.isCurrent(revision, token)) {
        return;
      }
      this.comments = mergeUnique([], page.items);
      this.request = page.nextRequest instanceof OffsetPageRequest
        ? page.nextRequest : new OffsetPageRequest();
      this.hasMore = page.hasMore;
      this.empty = this.comments.length === 0;
      this.state = LoadState.Ready;
      this.lastUpdatedAt = new Date().toISOString();
    } catch (err) {
      if (!this.isCurrent(revision, token)) {
        return;
      }
      if (isCanceled(err)) {
        this.state = this.issue === undefined ? LoadState.Idle : LoadState.Ready;
        return;
      }
      const message = errorMessage(err, 'Unable to load the issue.');
      if (detailLoaded) {
        this.commentError = message;
        this.state = LoadState.Ready;
      } else {
        this.errorMessage = message;
        this.state = LoadState.Error;
      }
    } finally {
      this.finish(revision);
    }
  }

  async retry(): Promise<void> {
    if (this.issue === undefined) {
      await this.load();
      return;
    }
    await this.refresh();
  }

  async refresh(): Promise<void> {
    if (this.busy || !this.validRef()) {
      return;
    }
    if (this.issue === undefined) {
      await this.load();
      return;
    }
    const token = this.startRequest();
    const revision = this.revision;
    let detailLoaded: boolean = false;
    this.state = LoadState.Refreshing;
    this.errorMessage = '';
    this.commentError = '';
    this.sendErrorMessage = '';
    this.successMessage = '';
    this.commentPosted = false;
    try {
      const issue = await this.dataSource.issue(this.ref, token);
      if (!this.isCurrent(revision, token)) {
        return;
      }
      detailLoaded = true;
      this.issue = issue;
      const page = await this.dataSource.issueComments(this.ref, new OffsetPageRequest(), token);
      if (!this.isCurrent(revision, token)) {
        return;
      }
      this.comments = mergeUnique([], page.items);
      this.request = page.nextRequest instanceof OffsetPageRequest
        ? page.nextRequest : new OffsetPageRequest();
      this.hasMore = page.hasMore;
      this.empty = this.comments.length === 0;
      this.state = LoadState.Ready;
      this.lastUpdatedAt = new Date().toISOString();
    } catch (err) {
      if (!this.isCurrent(revision, token)) {
        return;
      }
      if (isCanceled(err)) {
        this.state = LoadState.Ready;
        return;
      }
      const message = errorMessage(err, 'Unable to refresh the issue.');
      if (detailLoaded) {
        this.commentError = message;
      } else {
        this.errorMessage = message;
      }
      this.state = LoadState.Ready;
    } finally {
      this.finish(revision);
    }
  }

  async loadMore(): Promise<void> {
    if (this.busy || !this.hasMore || this.comments.length === 0 || !this.validRef()) {
      return;
    }
    const token = this.startRequest();
    const revision = this.revision;
    this.loadingMore = true;
    this.commentError = '';
    try {
      const page = await this.dataSource.issueComments(this.ref, this.request, token);
      if (!this.isCurrent(revision, token)) {
        return;
      }
      this.comments = mergeUnique(this.comments, page.items);
      this.request = page.nextRequest instanceof OffsetPageRequest
        ? page.nextRequest : this.request;
      this.hasMore = page.hasMore;
      this.empty = this.comments.length === 0;
      this.state = LoadState.Ready;
    } catch (err) {
      if (!this.isCurrent(revision, token)) {
        return;
      }
      if (!isCanceled(err)) {
        this.commentError = errorMessage(err, 'Unable to load more comments.');
      }
      this.state = LoadState.Ready;
    } finally {
      this.finish(revision);
    }
  }

  async retryComments(): Promise<void> {
    if (this.busy || !this.validRef()) {
      return;
    }
    if (this.issue === undefined) {
      await this.load();
      return;
    }
    const token = this.startRequest();
    const revision = this.revision;
    this.commentError = '';
    this.state = LoadState.Refreshing;
    try {
      const page = await this.dataSource.issueComments(this.ref, new OffsetPageRequest(), token);
      if (!this.isCurrent(revision, token)) {
        return;
      }
      this.comments = mergeUnique([], page.items);
      this.request = page.nextRequest instanceof OffsetPageRequest
        ? page.nextRequest : new OffsetPageRequest();
      this.hasMore = page.hasMore;
      this.empty = this.comments.length === 0;
      this.state = LoadState.Ready;
    } catch (err) {
      if (!this.isCurrent(revision, token)) {
        return;
      }
      if (!isCanceled(err)) {
        this.commentError = errorMessage(err, 'Unable to load comments.');
      }
      this.state = LoadState.Ready;
    } finally {
      this.finish(revision);
    }
  }

  async submitComment(): Promise<boolean> {
    if (this.sending || this.draft.trim().length === 0 || !this.validRef()) {
      return false;
    }
    const body = this.draft;
    const token = this.startRequest();
    const revision = this.revision;
    let accepted: boolean = false;
    this.sending = true;
    this.sendErrorMessage = '';
    this.successMessage = '';
    this.commentPosted = false;
    try {
      const createdId = await this.dataSource.addIssueComment(this.ref, body, token);
      if (!this.isCurrent(revision, token)) {
        return false;
      }
      accepted = true;
      return await this.readBackComments(token, revision, body, createdId);
    } catch (err) {
      if (!this.isCurrent(revision, token)) {
        return false;
      }
      if (isCanceled(err)) {
        return false;
      }
      this.sendErrorMessage = accepted
        ? 'Comment may have been posted, but confirmation failed. Refresh comments before retrying.'
        : errorMessage(err, 'Unable to post the comment.');
      return false;
    } finally {
      this.finish(revision);
    }
  }

  updateDraft(value: string): void {
    this.draft = value;
    this.sendErrorMessage = '';
    this.successMessage = '';
    this.commentPosted = false;
  }

  canSubmit(): boolean {
    return this.issue !== undefined && !this.sending && this.draft.trim().length > 0
      && this.validRef();
  }

  cancelPending(): void {
    const hadIssue = this.issue !== undefined;
    this.cancelActiveRequest();
    if (!hadIssue) {
      this.state = LoadState.Idle;
    } else if (this.state === LoadState.Loading || this.state === LoadState.Refreshing) {
      this.state = LoadState.Ready;
    }
  }

  private async readBackComments(token: CancelToken, revision: number,
    expectedBody: string, expectedId: string): Promise<boolean> {
    let request: OffsetPageRequest = new OffsetPageRequest(1, COMMENT_READBACK_PAGE_SIZE);
    let all: CollaborationComment[] = [];
    let found: boolean = false;
    let lastPage: Page<CollaborationComment> | undefined = undefined;
    for (let pageNumber = 0; pageNumber < MAX_COMMENT_READBACK_PAGES; pageNumber++) {
      const page = await this.dataSource.issueComments(this.ref, request, token);
      if (!this.isCurrent(revision, token)) {
        return false;
      }
      all = mergeUnique(all, page.items);
      lastPage = page;
      for (const comment of page.items) {
        if (expectedId.length > 0 ? comment.id === expectedId : comment.body === expectedBody) {
          found = true;
          break;
        }
      }
      if (found || !page.hasMore || page.nextRequest === undefined) {
        break;
      }
      if (!(page.nextRequest instanceof OffsetPageRequest)) {
        throw new ApiError(ApiErrorKind.Parse, 0, 0,
          'comment readback requires offset paging', '', this.ref.key());
      }
      request = page.nextRequest;
    }
    if (!found) {
      throw new ApiError(ApiErrorKind.Parse, 0, 0,
        'posted comment was not found during readback', '', this.ref.key());
    }
    this.comments = all;
    this.request = lastPage !== undefined && lastPage.nextRequest instanceof OffsetPageRequest
      ? lastPage.nextRequest : new OffsetPageRequest();
    this.hasMore = lastPage !== undefined && lastPage.hasMore;
    this.empty = all.length === 0;
    this.draft = '';
    this.successMessage = 'Comment posted';
    this.commentPosted = true;
    this.sendErrorMessage = '';
    this.state = LoadState.Ready;
    try {
      this.commentPostedCallback(this.ref);
    } catch {
      // A host refresh callback must not turn a confirmed write into a failure.
    }
    return true;
  }

  private validRef(): boolean {
    return this.ref.owner.trim().length > 0 && this.ref.repo.trim().length > 0
      && this.ref.number > 0;
  }

  private startRequest(): CancelToken {
    this.cancelActiveRequest();
    this.busy = true;
    const token = new CancelToken();
    this.cancelToken = token;
    this.revision++;
    return token;
  }

  private isCurrent(revision: number, token: CancelToken): boolean {
    return revision === this.revision && !token.isCanceled();
  }

  private finish(revision: number): void {
    if (revision !== this.revision) {
      return;
    }
    this.busy = false;
    this.loadingMore = false;
    this.sending = false;
    this.cancelToken = undefined;
  }

  private cancelActiveRequest(): void {
    if (this.cancelToken !== undefined) {
      this.cancelToken.cancel();
      this.cancelToken = undefined;
    }
    this.revision++;
    this.busy = false;
    this.loadingMore = false;
    this.sending = false;
  }

  private reset(): void {
    this.state = LoadState.Idle;
    this.issue = undefined;
    this.comments = [];
    this.hasMore = false;
    this.loadingMore = false;
    this.sending = false;
    this.empty = true;
    this.errorMessage = '';
    this.commentError = '';
    this.sendErrorMessage = '';
    this.successMessage = '';
    this.commentPosted = false;
    this.draft = '';
    this.lastUpdatedAt = '';
    this.request = new OffsetPageRequest();
  }
}

export class EmptyIssueDetailStore extends IssueDetailStore {
  constructor() {
    super(new EmptyIssueRepository());
  }
}

import { ApiError, ApiErrorKind } from '../common/ApiError';
import { CancelToken } from '../network/HttpClient';
import { OffsetPageRequest, Page, PageRequest } from '../common/Pager';
import {
  CollaborationComment,
  PullRequestDetail,
  PullRequestFile,
  RepositoryItemRef
} from '../model/CollaborationEntities';
import {
  ApprovePullRequestOptions,
  PullRequestFilesOptions,
  PullRequestRepository
} from '../repository/Ports';
import {
  APPROVAL_READBACK_UNCONFIRMED_MESSAGE,
  PR_HEAD_MISMATCH_MESSAGE,
  PullRequestHeadMismatchError,
  isApprovalAccepted
} from '../repository/PullRequestRepository';

export enum ApprovalUiState {
  Idle = 'idle',
  NeedsReview = 'needs_review',
  Approving = 'approving',
  Confirmed = 'confirmed',
  Unconfirmed = 'unconfirmed'
}

export const COMMENT_CONFIRMATION_FAILED_MESSAGE: string =
  'The comment was submitted, but it could not be confirmed in the refreshed comments.';

class EmptyPullRequestRepository implements PullRequestRepository {
  async pullRequest(ref: RepositoryItemRef): Promise<PullRequestDetail> {
    return new PullRequestDetail(ref, '', '', '', false, '', false, '', '', '', '', '', []);
  }

  async pullRequestComments(ref: RepositoryItemRef, request: PageRequest):
    Promise<Page<CollaborationComment>> {
    return Page.empty<CollaborationComment>(request);
  }

  async pullRequestFiles(ref: RepositoryItemRef): Promise<PullRequestFile[]> {
    return [];
  }

  async addPullRequestComment(ref: RepositoryItemRef, body: string): Promise<void> {
  }

  async approvePullRequest(ref: RepositoryItemRef, options?: ApprovePullRequestOptions): Promise<void> {
  }
}

@ObservedV2
export class PullRequestDetailStore {
  @Trace ref: RepositoryItemRef | undefined = undefined;
  @Trace detail: PullRequestDetail | undefined = undefined;
  @Trace comments: CollaborationComment[] = [];
  @Trace files: PullRequestFile[] = [];
  @Trace loadingDetail: boolean = false;
  @Trace loadingComments: boolean = false;
  @Trace loadingFiles: boolean = false;
  @Trace loadingMoreComments: boolean = false;
  @Trace refreshing: boolean = false;
  @Trace sendingComment: boolean = false;
  @Trace approving: boolean = false;
  @Trace commentDraft: string = '';
  @Trace commentSubmissionConfirmed: boolean = false;
  @Trace commentsHasMore: boolean = false;
  @Trace filesAtLimit: boolean = false;
  @Trace approvalNeedsReview: boolean = false;
  @Trace approvalReadbackConfirmed: boolean = false;
  @Trace approvalState: ApprovalUiState = ApprovalUiState.Idle;
  @Trace approvalMessage: string = '';
  @Trace approvalReadbackHeadSha: string = '';
  @Trace detailErrorMessage: string = '';
  @Trace commentsErrorMessage: string = '';
  @Trace filesErrorMessage: string = '';
  @Trace commentErrorMessage: string = '';
  @Trace approvalErrorMessage: string = '';
  @Trace detailError: ApiError | undefined = undefined;
  @Trace commentsError: ApiError | undefined = undefined;
  @Trace filesError: ApiError | undefined = undefined;
  @Trace commentError: ApiError | undefined = undefined;
  @Trace approvalError: ApiError | undefined = undefined;

  private readonly dataSource: PullRequestRepository;
  private readonly filesOptions: PullRequestFilesOptions;
  private readonly commentsPerPage: number;
  private currentUserLogin: string;
  private approvalSucceededCallback: () => void;
  private commentSucceededCallback: (ref: RepositoryItemRef) => void;
  private reviewedHeadSha: string = '';
  private commentsNextRequest: PageRequest | undefined = undefined;
  private detailRevision: number = 0;
  private commentsRevision: number = 0;
  private filesRevision: number = 0;
  private commentWriteRevision: number = 0;
  private approvalRevision: number = 0;
  private detailToken: CancelToken | undefined = undefined;
  private commentsToken: CancelToken | undefined = undefined;
  private filesToken: CancelToken | undefined = undefined;
  private commentWriteToken: CancelToken | undefined = undefined;
  private approvalToken: CancelToken | undefined = undefined;

  constructor(dataSource: PullRequestRepository, currentUserLogin: string = '',
    commentsPerPage: number = 20, filesOptions: PullRequestFilesOptions = new PullRequestFilesOptions(),
    onApprovalSucceeded: () => void = () => {},
    onCommentSucceeded: (ref: RepositoryItemRef) => void = () => {}) {
    this.dataSource = dataSource;
    this.currentUserLogin = currentUserLogin.trim();
    this.commentsPerPage = Number.isFinite(commentsPerPage) && commentsPerPage >= 1
      ? Math.floor(commentsPerPage) : 20;
    this.filesOptions = filesOptions;
    this.approvalSucceededCallback = onApprovalSucceeded;
    this.commentSucceededCallback = onCommentSucceeded;
  }

  setCurrentUser(login: string): void {
    this.currentUserLogin = login.trim();
  }

  setApprovalSucceededCallback(callback: () => void): void {
    this.approvalSucceededCallback = callback;
  }

  setCommentSucceededCallback(callback: (ref: RepositoryItemRef) => void): void {
    this.commentSucceededCallback = callback;
  }

  async open(ref: RepositoryItemRef): Promise<void> {
    const changed = this.ref === undefined || !sameRef(this.ref, ref);
    if (changed) {
      this.cancelPending();
      this.resetFor(ref);
    }
    await this.refreshAll();
  }

  async refreshAll(): Promise<void> {
    if (this.refreshing || this.ref === undefined) {
      return;
    }
    this.refreshing = true;
    await Promise.all([
      this.refreshDetail(),
      this.refreshComments(),
      this.refreshFiles()
    ]);
    this.refreshing = false;
  }

  async refreshDetail(): Promise<void> {
    const ref = this.ref;
    if (ref === undefined) {
      return;
    }
    const revision = ++this.detailRevision;
    const token = this.replaceToken(this.detailToken);
    this.detailToken = token;
    this.loadingDetail = true;
    this.detailError = undefined;
    this.detailErrorMessage = '';
    try {
      const next = await this.dataSource.pullRequest(ref, token);
      if (!this.isDetailCurrent(revision, token)) {
        return;
      }
      const previous = this.detail;
      this.detail = next;
      if (previous === undefined || this.reviewedHeadSha.length === 0) {
        this.reviewedHeadSha = next.headSha;
        this.approvalNeedsReview = false;
        if (this.approvalState === ApprovalUiState.Idle) {
          this.approvalMessage = '';
        }
      } else if (!sameSha(previous.headSha, next.headSha)) {
        this.approvalNeedsReview = true;
        this.approvalState = ApprovalUiState.NeedsReview;
        this.approvalMessage = PR_HEAD_MISMATCH_MESSAGE;
        this.approvalReadbackConfirmed = false;
      }
    } catch (err) {
      if (!this.isDetailCurrent(revision, token)) {
        return;
      }
      const apiError = asApiError(err);
      this.detailError = apiError;
      this.detailErrorMessage = englishMessage(apiError);
    } finally {
      if (this.isDetailCurrent(revision, token)) {
        this.loadingDetail = false;
      }
    }
  }

  async refreshComments(): Promise<void> {
    const ref = this.ref;
    if (ref === undefined) {
      return;
    }
    const revision = ++this.commentsRevision;
    const token = this.replaceToken(this.commentsToken);
    this.commentsToken = token;
    this.loadingComments = true;
    this.commentsError = undefined;
    this.commentsErrorMessage = '';
    try {
      const page = await this.dataSource.pullRequestComments(ref,
        new OffsetPageRequest(1, this.commentsPerPage), undefined, token);
      if (!this.isCommentsCurrent(revision, token)) {
        return;
      }
      this.comments = page.items.slice();
      this.commentsNextRequest = page.nextRequest;
      this.commentsHasMore = page.hasMore;
    } catch (err) {
      if (!this.isCommentsCurrent(revision, token)) {
        return;
      }
      const apiError = asApiError(err);
      this.commentsError = apiError;
      this.commentsErrorMessage = englishMessage(apiError);
    } finally {
      if (this.isCommentsCurrent(revision, token)) {
        this.loadingComments = false;
        this.loadingMoreComments = false;
      }
    }
  }

  async loadMoreComments(): Promise<void> {
    const ref = this.ref;
    const request = this.commentsNextRequest;
    if (ref === undefined || request === undefined || this.loadingComments
      || this.loadingMoreComments || this.sendingComment) {
      return;
    }
    const revision = ++this.commentsRevision;
    const token = this.replaceToken(this.commentsToken);
    this.commentsToken = token;
    this.loadingMoreComments = true;
    this.commentsError = undefined;
    this.commentsErrorMessage = '';
    try {
      const page = await this.dataSource.pullRequestComments(ref, request, undefined, token);
      if (!this.isCommentsCurrent(revision, token)) {
        return;
      }
      this.comments = mergeComments(this.comments, page.items);
      this.commentsNextRequest = page.nextRequest;
      this.commentsHasMore = page.hasMore;
    } catch (err) {
      if (!this.isCommentsCurrent(revision, token)) {
        return;
      }
      const apiError = asApiError(err);
      this.commentsError = apiError;
      this.commentsErrorMessage = englishMessage(apiError);
    } finally {
      if (this.isCommentsCurrent(revision, token)) {
        this.loadingMoreComments = false;
      }
    }
  }

  async refreshFiles(): Promise<void> {
    const ref = this.ref;
    if (ref === undefined) {
      return;
    }
    const revision = ++this.filesRevision;
    const token = this.replaceToken(this.filesToken);
    this.filesToken = token;
    this.loadingFiles = true;
    this.filesError = undefined;
    this.filesErrorMessage = '';
    try {
      const files = await this.dataSource.pullRequestFiles(ref, this.filesOptions, token);
      if (!this.isFilesCurrent(revision, token)) {
        return;
      }
      this.files = files.slice();
      this.filesAtLimit = files.length >= this.filesOptions.maxFiles;
    } catch (err) {
      if (!this.isFilesCurrent(revision, token)) {
        return;
      }
      const apiError = asApiError(err);
      this.filesError = apiError;
      this.filesErrorMessage = englishMessage(apiError);
    } finally {
      if (this.isFilesCurrent(revision, token)) {
        this.loadingFiles = false;
      }
    }
  }

  setCommentDraft(value: string): void {
    this.commentDraft = value;
    if (this.commentErrorMessage.length > 0 && !this.commentSubmissionConfirmed) {
      this.commentErrorMessage = '';
      this.commentError = undefined;
    }
  }

  async sendComment(): Promise<boolean> {
    if (this.sendingComment || this.ref === undefined || this.commentDraft.trim().length === 0) {
      return false;
    }
    const ref = this.ref;
    const body = this.commentDraft;
    const previousIds = commentIds(this.comments);
    const revision = ++this.commentWriteRevision;
    const token = this.replaceToken(this.commentWriteToken);
    this.commentWriteToken = token;
    this.invalidateCommentsForMutation();
    const commentsRevisionAtStart = this.commentsRevision;
    this.sendingComment = true;
    this.commentSubmissionConfirmed = false;
    this.commentError = undefined;
    this.commentErrorMessage = '';
    try {
      await this.dataSource.addPullRequestComment(ref, body, token);
      if (!this.isCommentWriteCurrent(revision, token)) {
        return false;
      }
      const readback = await this.dataSource.pullRequestComments(ref,
        new OffsetPageRequest(1, this.commentsPerPage), undefined, token);
      if (!this.isCommentWriteCurrent(revision, token)) {
        return false;
      }
      if (!this.containsSubmittedComment(readback.items, body, previousIds)) {
        throw new ApiError(ApiErrorKind.Conflict, 200, 0,
          COMMENT_CONFIRMATION_FAILED_MESSAGE, '', '/pulls/comments');
      }
      if (this.commentsRevision === commentsRevisionAtStart) {
        this.comments = readback.items.slice();
        this.commentsNextRequest = readback.nextRequest;
        this.commentsHasMore = readback.hasMore;
      }
      this.commentDraft = '';
      this.commentSubmissionConfirmed = true;
      try {
        this.commentSucceededCallback(ref);
      } catch {
        // A host refresh callback must not turn a confirmed write into a failure.
      }
      return true;
    } catch (err) {
      if (!this.isCommentWriteCurrent(revision, token)) {
        return false;
      }
      const apiError = asApiError(err);
      this.commentError = apiError;
      this.commentErrorMessage = englishMessage(apiError);
      this.commentSubmissionConfirmed = false;
      return false;
    } finally {
      if (this.isCommentWriteCurrent(revision, token)) {
        this.sendingComment = false;
      }
    }
  }

  markLatestHeadReviewed(): void {
    if (this.detail === undefined || this.approving) {
      return;
    }
    this.reviewedHeadSha = this.detail.headSha;
    this.approvalNeedsReview = false;
    this.approvalState = this.approvalReadbackConfirmed
      ? ApprovalUiState.Confirmed : ApprovalUiState.Idle;
    this.approvalMessage = this.approvalReadbackConfirmed ? 'Approval confirmed.' : '';
    this.approvalErrorMessage = '';
    this.approvalError = undefined;
  }

  canApprove(): boolean {
    if (this.detail === undefined || this.approving || this.approvalNeedsReview
      || this.approvalReadbackConfirmed) {
      return false;
    }
    return this.detail.state.toLowerCase() === 'open' && !this.detail.merged;
  }

  async approve(): Promise<boolean> {
    if (this.approving || this.ref === undefined || this.detail === undefined) {
      return false;
    }
    if (this.reviewedHeadSha.length === 0) {
      this.setApprovalFailure(new ApiError(ApiErrorKind.Conflict, 0, 0,
        'Refresh the pull request before approving.', '', '/pulls/approve'));
      return false;
    }
    const ref = this.ref;
    const reviewedHead = this.reviewedHeadSha;
    const revision = ++this.approvalRevision;
    const token = this.replaceToken(this.approvalToken);
    this.approvalToken = token;
    this.approving = true;
    this.approvalState = ApprovalUiState.Approving;
    this.approvalMessage = '';
    this.approvalErrorMessage = '';
    this.approvalError = undefined;
    this.approvalReadbackConfirmed = false;
    try {
      const preflight = await this.dataSource.pullRequest(ref, token);
      if (!this.isApprovalCurrent(revision, token)) {
        return false;
      }
      if (!sameSha(reviewedHead, preflight.headSha)) {
        this.detail = preflight;
        const mismatch = new PullRequestHeadMismatchError(reviewedHead, preflight.headSha);
        this.approvalNeedsReview = true;
        this.approvalState = ApprovalUiState.NeedsReview;
        this.approvalErrorMessage = PR_HEAD_MISMATCH_MESSAGE;
        this.approvalMessage = PR_HEAD_MISMATCH_MESSAGE;
        this.approvalError = mismatch;
        return false;
      }
      this.detail = preflight;
      await this.dataSource.approvePullRequest(ref,
        new ApprovePullRequestOptions(false, reviewedHead), token);
      if (!this.isApprovalCurrent(revision, token)) {
        return false;
      }
      const readback = await this.dataSource.pullRequest(ref, token);
      if (!this.isApprovalCurrent(revision, token)) {
        return false;
      }
      this.detail = readback;
      this.approvalReadbackHeadSha = readback.headSha;
      if (!sameSha(reviewedHead, readback.headSha)) {
        const mismatch = new PullRequestHeadMismatchError(reviewedHead, readback.headSha);
        this.approvalNeedsReview = true;
        this.approvalState = ApprovalUiState.NeedsReview;
        this.approvalErrorMessage = PR_HEAD_MISMATCH_MESSAGE;
        this.approvalMessage = PR_HEAD_MISMATCH_MESSAGE;
        this.approvalError = mismatch;
        return false;
      }
      if (!this.isApprovedByCurrentUser(readback)) {
        const unconfirmed = new ApiError(ApiErrorKind.Conflict, 200, 0,
          APPROVAL_READBACK_UNCONFIRMED_MESSAGE, '', '/pulls/review');
        this.approvalState = ApprovalUiState.Unconfirmed;
        this.approvalErrorMessage = APPROVAL_READBACK_UNCONFIRMED_MESSAGE;
        this.approvalMessage = APPROVAL_READBACK_UNCONFIRMED_MESSAGE;
        this.approvalError = unconfirmed;
        return false;
      }
      this.approvalReadbackConfirmed = true;
      this.approvalNeedsReview = false;
      this.approvalState = ApprovalUiState.Confirmed;
      this.approvalMessage = 'Approval confirmed by pull request readback.';
      this.approvalErrorMessage = '';
      this.approvalError = undefined;
      try {
        this.approvalSucceededCallback();
      } catch {
        // A host notification callback must not turn a confirmed write into a failure.
      }
      return true;
    } catch (err) {
      if (!this.isApprovalCurrent(revision, token)) {
        return false;
      }
      const apiError = asApiError(err);
      if (apiError instanceof PullRequestHeadMismatchError) {
        this.approvalNeedsReview = true;
        this.approvalState = ApprovalUiState.NeedsReview;
        try {
          const latest = await this.dataSource.pullRequest(ref, token);
          if (this.isApprovalCurrent(revision, token)) {
            this.detail = latest;
            this.approvalReadbackHeadSha = latest.headSha;
          }
        } catch {
          // Preserve the original head-mismatch error when the refresh also fails.
        }
      } else {
        this.approvalState = ApprovalUiState.Idle;
      }
      this.setApprovalFailure(apiError);
      return false;
    } finally {
      if (this.isApprovalCurrent(revision, token)) {
        this.approving = false;
      }
    }
  }

  cancelPending(): void {
    this.cancelToken(this.detailToken);
    this.cancelToken(this.commentsToken);
    this.cancelToken(this.filesToken);
    this.cancelToken(this.commentWriteToken);
    this.cancelToken(this.approvalToken);
    this.detailToken = undefined;
    this.commentsToken = undefined;
    this.filesToken = undefined;
    this.commentWriteToken = undefined;
    this.approvalToken = undefined;
    this.detailRevision++;
    this.commentsRevision++;
    this.filesRevision++;
    this.commentWriteRevision++;
    this.approvalRevision++;
    this.loadingDetail = false;
    this.loadingComments = false;
    this.loadingFiles = false;
    this.loadingMoreComments = false;
    this.refreshing = false;
    this.sendingComment = false;
    this.approving = false;
    if (this.approvalState === ApprovalUiState.Approving) {
      this.approvalState = ApprovalUiState.Unconfirmed;
      this.approvalMessage = 'Approval status must be refreshed before showing success.';
    }
  }

  private resetFor(ref: RepositoryItemRef): void {
    this.ref = ref;
    this.detail = undefined;
    this.comments = [];
    this.files = [];
    this.commentDraft = '';
    this.commentSubmissionConfirmed = false;
    this.commentsHasMore = false;
    this.commentsNextRequest = undefined;
    this.filesAtLimit = false;
    this.approvalNeedsReview = false;
    this.approvalReadbackConfirmed = false;
    this.approvalState = ApprovalUiState.Idle;
    this.approvalMessage = '';
    this.approvalReadbackHeadSha = '';
    this.detailErrorMessage = '';
    this.commentsErrorMessage = '';
    this.filesErrorMessage = '';
    this.commentErrorMessage = '';
    this.approvalErrorMessage = '';
    this.detailError = undefined;
    this.commentsError = undefined;
    this.filesError = undefined;
    this.commentError = undefined;
    this.approvalError = undefined;
    this.reviewedHeadSha = '';
  }

  private invalidateCommentsForMutation(): void {
    this.cancelToken(this.commentsToken);
    this.commentsToken = undefined;
    this.commentsRevision++;
    this.loadingComments = false;
    this.loadingMoreComments = false;
  }

  private containsSubmittedComment(items: CollaborationComment[], body: string,
    previousIds: Set<string>): boolean {
    for (const comment of items) {
      if (previousIds.has(comment.id)) {
        continue;
      }
      if (comment.body !== body || comment.id.length === 0) {
        continue;
      }
      if (this.currentUserLogin.length === 0
        || comment.author.trim().toLowerCase() === this.currentUserLogin.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  private isApprovedByCurrentUser(detail: PullRequestDetail): boolean {
    const login = this.currentUserLogin.trim().toLowerCase();
    if (login.length === 0) {
      return false;
    }
    for (const reviewer of detail.approvalReviewers) {
      if (reviewer.login.trim().toLowerCase() === login
        && isApprovalAccepted(reviewer.acceptStatus)) {
        return true;
      }
    }
    return false;
  }

  private setApprovalFailure(error: ApiError): void {
    this.approvalError = error;
    this.approvalErrorMessage = error.message.length > 0
      && (error instanceof PullRequestHeadMismatchError)
      ? error.message : englishMessage(error);
    this.approvalMessage = this.approvalErrorMessage;
    this.approvalReadbackConfirmed = false;
  }

  private replaceToken(previous: CancelToken | undefined): CancelToken {
    this.cancelToken(previous);
    return new CancelToken();
  }

  private cancelToken(token: CancelToken | undefined): void {
    if (token !== undefined) {
      token.cancel();
    }
  }

  private isDetailCurrent(revision: number, token: CancelToken): boolean {
    return this.detailRevision === revision && this.detailToken === token && !token.isCanceled();
  }

  private isCommentsCurrent(revision: number, token: CancelToken): boolean {
    return this.commentsRevision === revision && this.commentsToken === token && !token.isCanceled();
  }

  private isFilesCurrent(revision: number, token: CancelToken): boolean {
    return this.filesRevision === revision && this.filesToken === token && !token.isCanceled();
  }

  private isCommentWriteCurrent(revision: number, token: CancelToken): boolean {
    return this.commentWriteRevision === revision && this.commentWriteToken === token
      && !token.isCanceled();
  }

  private isApprovalCurrent(revision: number, token: CancelToken): boolean {
    return this.approvalRevision === revision && this.approvalToken === token
      && !token.isCanceled();
  }
}

export class EmptyPullRequestDetailStore extends PullRequestDetailStore {
  constructor() {
    super(new EmptyPullRequestRepository());
  }
}

function sameRef(left: RepositoryItemRef, right: RepositoryItemRef): boolean {
  return left.owner === right.owner && left.repo === right.repo && left.number === right.number;
}

function sameSha(left: string, right: string): boolean {
  return left.trim().toLowerCase() === right.trim().toLowerCase();
}

function commentIds(items: CollaborationComment[]): Set<string> {
  const ids: Set<string> = new Set<string>();
  for (const item of items) {
    ids.add(item.id);
  }
  return ids;
}

function mergeComments(previous: CollaborationComment[],
  incoming: CollaborationComment[]): CollaborationComment[] {
  const result: CollaborationComment[] = [];
  const seen: Set<string> = new Set<string>();
  for (const comment of previous.concat(incoming)) {
    if (comment.id.length === 0 || seen.has(comment.id)) {
      continue;
    }
    seen.add(comment.id);
    result.push(comment);
  }
  return result;
}

function asApiError(err: ESObject): ApiError {
  if (err instanceof ApiError) {
    return err;
  }
  const message = err instanceof Error ? err.message : 'request failed';
  return new ApiError(ApiErrorKind.Unknown, 0, 0, message, '', '');
}

function englishMessage(error: ApiError): string {
  switch (error.kind) {
    case ApiErrorKind.Unauthorized:
      return 'Your session is not authorized. Sign in again and retry.';
    case ApiErrorKind.Forbidden:
      return 'You do not have permission to perform this action.';
    case ApiErrorKind.NotFound:
      return 'This pull request or one of its resources was not found.';
    case ApiErrorKind.MethodNotAllowed:
      return 'This action is not supported.';
    case ApiErrorKind.Conflict:
      return error.message.length > 0 ? error.message : 'The pull request changed. Refresh and retry.';
    case ApiErrorKind.UnsafeRequest:
      return 'The request was blocked by the security policy.';
    case ApiErrorKind.Unprocessable:
      return 'The submitted content was rejected by AtomGit.';
    case ApiErrorKind.RateLimited:
      return 'Too many requests. Wait before retrying.';
    case ApiErrorKind.ServerError:
      return 'AtomGit is temporarily unavailable.';
    case ApiErrorKind.Network:
      return 'The network is unavailable.';
    case ApiErrorKind.Canceled:
      return 'The request was canceled.';
    case ApiErrorKind.Parse:
      return 'AtomGit returned data that could not be displayed.';
    default:
      return error.message.length > 0 ? error.message : 'The request failed.';
  }
}

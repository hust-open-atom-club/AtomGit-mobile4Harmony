import { describe, it, expect } from '@ohos/hypium';

import { ApiError, ApiErrorKind } from '../main/ets/common/ApiError';
import { CancellationSignal } from '../main/ets/common/Cancellation';
import { OffsetPageRequest, Page, PageRequest } from '../main/ets/common/Pager';
import {
  ApprovalReviewer,
  CollaborationComment,
  PullRequestDetail,
  PullRequestFile,
  RepositoryItemRef
} from '../main/ets/model/CollaborationEntities';
import {
  ApprovePullRequestOptions,
  PullRequestFilesOptions,
  PullRequestRepository
} from '../main/ets/repository/Ports';
import { PullRequestHeadMismatchError } from '../main/ets/repository/PullRequestRepository';
import {
  ApprovalUiState,
  PullRequestDetailStore
} from '../main/ets/viewmodel/PullRequestDetailStore';

class DetailDeferred {
  readonly promise: Promise<PullRequestDetail>;
  private resolveFn: (value: PullRequestDetail) => void = () => {};

  constructor() {
    this.promise = new Promise<PullRequestDetail>((resolve) => {
      this.resolveFn = resolve;
    });
  }

  resolve(value: PullRequestDetail): void {
    this.resolveFn(value);
  }
}

class CommentPageDeferred {
  readonly promise: Promise<Page<CollaborationComment>>;
  private resolveFn: (value: Page<CollaborationComment>) => void = () => {};

  constructor() {
    this.promise = new Promise<Page<CollaborationComment>>((resolve) => {
      this.resolveFn = resolve;
    });
  }

  resolve(value: Page<CollaborationComment>): void {
    this.resolveFn(value);
  }
}

class VoidDeferred {
  readonly promise: Promise<void>;
  private resolveFn: () => void = () => {};

  constructor() {
    this.promise = new Promise<void>((resolve) => {
      this.resolveFn = resolve;
    });
  }

  resolve(): void {
    this.resolveFn();
  }
}

type DetailResponse = PullRequestDetail | ApiError | DetailDeferred;
type CommentResponse = Page<CollaborationComment> | ApiError | CommentPageDeferred;

class FakePullRequestRepository implements PullRequestRepository {
  readonly detailResponses: DetailResponse[] = [];
  readonly commentResponses: CommentResponse[] = [];
  readonly fileResponses: Array<PullRequestFile[] | ApiError> = [];
  readonly commentRequests: PageRequest[] = [];
  detailCalls: number = 0;
  commentCalls: number = 0;
  fileCalls: number = 0;
  addCalls: number = 0;
  approveCalls: number = 0;
  addError: ApiError | undefined = undefined;
  approveError: ApiError | undefined = undefined;
  addDeferred: VoidDeferred | undefined = undefined;
  approveDeferred: VoidDeferred | undefined = undefined;

  async pullRequest(ref: RepositoryItemRef, cancel?: CancellationSignal): Promise<PullRequestDetail> {
    this.detailCalls++;
    const value = this.detailResponses.shift();
    if (value === undefined) {
      throw new ApiError(ApiErrorKind.Unknown, 0, 0, 'unexpected detail request', '', '');
    }
    if (value instanceof ApiError) {
      throw value;
    }
    if (value instanceof DetailDeferred) {
      return value.promise;
    }
    return value;
  }

  async pullRequestComments(ref: RepositoryItemRef, request: PageRequest, commentType?: string,
    cancel?: CancellationSignal): Promise<Page<CollaborationComment>> {
    this.commentCalls++;
    this.commentRequests.push(request);
    const value = this.commentResponses.shift();
    if (value === undefined) {
      return Page.empty<CollaborationComment>(request);
    }
    if (value instanceof ApiError) {
      throw value;
    }
    if (value instanceof CommentPageDeferred) {
      return value.promise;
    }
    return value;
  }

  async pullRequestFiles(ref: RepositoryItemRef, options?: PullRequestFilesOptions,
    cancel?: CancellationSignal): Promise<PullRequestFile[]> {
    this.fileCalls++;
    const value = this.fileResponses.shift();
    if (value === undefined) {
      return [];
    }
    if (value instanceof ApiError) {
      throw value;
    }
    return value;
  }

  async addPullRequestComment(ref: RepositoryItemRef, body: string,
    cancel?: CancellationSignal): Promise<void> {
    this.addCalls++;
    if (this.addError !== undefined) {
      throw this.addError;
    }
    if (this.addDeferred !== undefined) {
      await this.addDeferred.promise;
    }
  }

  async approvePullRequest(ref: RepositoryItemRef, options?: ApprovePullRequestOptions,
    cancel?: CancellationSignal): Promise<void> {
    this.approveCalls++;
    if (this.approveError !== undefined) {
      throw this.approveError;
    }
    if (this.approveDeferred !== undefined) {
      await this.approveDeferred.promise;
    }
  }
}

class TodoState {
  completed: boolean = false;
}

const REF: RepositoryItemRef = new RepositoryItemRef('owner', 'repo', 42);

function detail(head: string = 'head-a', reviewerStatus: string = 'optional',
  title: string = 'Pull request'): PullRequestDetail {
  return new PullRequestDetail(REF, title, 'Body', 'open', false, '', true,
    head, 'base-a', 'https://atomgit.com/owner/repo/pulls/42',
    '2026-11-18T09:00:00Z', 'author',
    [new ApprovalReviewer('alice', 'Alice', reviewerStatus)]);
}

function comment(id: string, parentId: string = '', body: string = 'Hello'): CollaborationComment {
  return new CollaborationComment(id, body, 'alice', '', '2026-11-18T09:01:00Z',
    'pr_comment', 'discussion-1', parentId, false);
}

function firstPage(request: PageRequest = new OffsetPageRequest(1, 20)):
  Page<CollaborationComment> {
  return Page.empty<CollaborationComment>(request);
}

export default function pullRequestDetailStoreTest() {
  describe('PullRequestDetailStore', () => {
    it('keeps_successful_sections_when_comments_fail', 0, () => {
      const repository = new FakePullRequestRepository();
      repository.detailResponses.push(detail());
      const commentsError = new ApiError(ApiErrorKind.Forbidden, 403, 403,
        'forbidden', '', '/comments');
      repository.commentResponses.push(commentsError);
      repository.fileResponses.push([new PullRequestFile('a.ts', 'modified', 1, 1, '@@ -1 +1 @@')]);
      const store = new PullRequestDetailStore(repository, 'alice');
      return store.open(REF).then(() => {
        expect(store.detail?.title).assertEqual('Pull request');
        expect(store.files.length).assertEqual(1);
        expect(store.commentsError === commentsError).assertTrue();
        expect(store.commentsErrorMessage.length > 0).assertTrue();
        expect(store.loadingDetail).assertFalse();
        expect(store.loadingComments).assertFalse();
        expect(store.loadingFiles).assertFalse();
      });
    });

    it('keeps_comments_and_files_when_detail_fails', 0, () => {
      const repository = new FakePullRequestRepository();
      const detailError = new ApiError(ApiErrorKind.Network, 0, 0,
        'offline', '', '/pulls/42');
      repository.detailResponses.push(detailError);
      repository.commentResponses.push(new Page<CollaborationComment>([comment('c1')],
        new OffsetPageRequest(1, 20)));
      repository.fileResponses.push([new PullRequestFile('a.ts', 'modified', 1, 0)]);
      const store = new PullRequestDetailStore(repository, 'alice');
      return store.open(REF).then(() => {
        expect(store.detail === undefined).assertTrue();
        expect(store.detailError === detailError).assertTrue();
        expect(store.comments.length).assertEqual(1);
        expect(store.files.length).assertEqual(1);
      });
    });

    it('keeps_detail_and_comments_when_files_fail', 0, () => {
      const repository = new FakePullRequestRepository();
      repository.detailResponses.push(detail());
      repository.commentResponses.push(new Page<CollaborationComment>([comment('c1')],
        new OffsetPageRequest(1, 20)));
      const filesError = new ApiError(ApiErrorKind.ServerError, 500, 500,
        'failed', '', '/files');
      repository.fileResponses.push(filesError);
      const store = new PullRequestDetailStore(repository, 'alice');
      return store.open(REF).then(() => {
        expect(store.detail?.title).assertEqual('Pull request');
        expect(store.comments.length).assertEqual(1);
        expect(store.files.length).assertEqual(0);
        expect(store.filesError === filesError).assertTrue();
      });
    });

    it('loads_more_comments_with_the_next_page_request', 0, () => {
      const repository = new FakePullRequestRepository();
      repository.detailResponses.push(detail());
      repository.commentResponses.push(new Page<CollaborationComment>([comment('c1')],
        new OffsetPageRequest(1, 20), new OffsetPageRequest(2, 20)));
      const store = new PullRequestDetailStore(repository, 'alice');
      return store.open(REF).then(() => {
        expect(store.commentsHasMore).assertTrue();
        repository.commentResponses.push(new Page<CollaborationComment>([comment('c2')],
          new OffsetPageRequest(2, 20)));
        return store.loadMoreComments();
      }).then(() => {
        expect(store.comments.length).assertEqual(2);
        const lastRequest = repository.commentRequests[repository.commentRequests.length - 1];
        expect(lastRequest instanceof OffsetPageRequest).assertTrue();
        const next: OffsetPageRequest = lastRequest instanceof OffsetPageRequest
          ? lastRequest : new OffsetPageRequest();
        expect(next.page).assertEqual(2);
        expect(store.commentsHasMore).assertFalse();
      });
    });

    it('clears_draft_only_after_comment_readback_confirmation', 0, () => {
      const repository = new FakePullRequestRepository();
      repository.detailResponses.push(detail());
      const store = new PullRequestDetailStore(repository, 'alice');
      return store.open(REF).then(() => {
        store.setCommentDraft('Hello');
        const add = new VoidDeferred();
        repository.addDeferred = add;
        const comments = new CommentPageDeferred();
        repository.commentResponses.push(comments);
        const sending = store.sendComment();
        expect(repository.addCalls).assertEqual(1);
        expect(store.commentDraft).assertEqual('Hello');
        add.resolve();
        comments.resolve(new Page<CollaborationComment>([comment('new-comment')],
          new OffsetPageRequest(1, 20)));
        return sending;
      }).then((confirmed: boolean) => {
        expect(confirmed).assertTrue();
        expect(store.commentDraft).assertEqual('');
        expect(store.commentSubmissionConfirmed).assertTrue();
        expect(store.comments[0].id).assertEqual('new-comment');
      });
    });

    it('keeps_draft_and_api_error_when_comment_write_fails', 0, () => {
      const repository = new FakePullRequestRepository();
      repository.detailResponses.push(detail());
      const writeError = new ApiError(ApiErrorKind.Unprocessable, 422, 422,
        'invalid', '', '/comments');
      repository.addError = writeError;
      const store = new PullRequestDetailStore(repository, 'alice');
      return store.open(REF).then(() => {
        store.setCommentDraft('Keep me');
        return store.sendComment();
      }).then((sent: boolean) => {
        expect(sent).assertFalse();
        expect(store.commentDraft).assertEqual('Keep me');
        expect(store.commentError === writeError).assertTrue();
        expect(store.commentSubmissionConfirmed).assertFalse();
      });
    });

    it('suppresses_duplicate_comment_submissions', 0, () => {
      const repository = new FakePullRequestRepository();
      repository.detailResponses.push(detail());
      const store = new PullRequestDetailStore(repository, 'alice');
      return store.open(REF).then(() => {
        store.setCommentDraft('Only once');
        const add = new VoidDeferred();
        repository.addDeferred = add;
        repository.commentResponses.push(new Page<CollaborationComment>(
          [comment('only-once', '', 'Only once')], new OffsetPageRequest(1, 20)));
        const first = store.sendComment();
        const second = store.sendComment();
        expect(repository.addCalls).assertEqual(1);
        add.resolve();
        return Promise.all([first, second]);
      }).then((results) => {
        expect(results[0]).assertTrue();
        expect(results[1]).assertFalse();
        expect(repository.addCalls).assertEqual(1);
      });
    });

    it('blocks_approve_when_preflight_head_changed', 0, () => {
      const repository = new FakePullRequestRepository();
      repository.detailResponses.push(detail('head-a'));
      const store = new PullRequestDetailStore(repository, 'alice');
      return store.open(REF).then(() => {
        repository.detailResponses.push(detail('head-b'));
        return store.approve();
      }).then((approved: boolean) => {
        expect(approved).assertFalse();
        expect(repository.approveCalls).assertEqual(0);
        expect(store.approvalNeedsReview).assertTrue();
        expect(store.approvalState).assertEqual(ApprovalUiState.NeedsReview);
        expect(store.approvalError instanceof PullRequestHeadMismatchError).assertTrue();
        expect(store.canApprove()).assertFalse();
        store.markLatestHeadReviewed();
        expect(store.approvalNeedsReview).assertFalse();
        expect(store.canApprove()).assertTrue();
      });
    });

    it('refreshes_latest_head_when_repository_rejects_a_head_race', 0, () => {
      const repository = new FakePullRequestRepository();
      repository.detailResponses.push(detail('head-a'));
      const store = new PullRequestDetailStore(repository, 'alice');
      return store.open(REF).then(() => {
        repository.detailResponses.push(detail('head-a'));
        repository.detailResponses.push(detail('head-c'));
        repository.approveError = new PullRequestHeadMismatchError('head-a', 'head-c');
        return store.approve();
      }).then((approved: boolean) => {
        expect(approved).assertFalse();
        expect(store.approvalNeedsReview).assertTrue();
        expect(store.detail?.headSha).assertEqual('head-c');
        expect(store.approvalError instanceof PullRequestHeadMismatchError).assertTrue();
      });
    });

    it('shows_success_only_after_approval_readback_and_does_not_touch_todo', 0, () => {
      const repository = new FakePullRequestRepository();
      const todo = new TodoState();
      let callbackCount = 0;
      repository.detailResponses.push(detail('head-a', 'optional'));
      const store = new PullRequestDetailStore(repository, 'alice', 20,
        new PullRequestFilesOptions(), () => {
          callbackCount++;
        });
      return store.open(REF).then(() => {
        repository.detailResponses.push(detail('head-a', 'optional'));
        repository.detailResponses.push(detail('head-a', 'true'));
        return store.approve();
      }).then((approved: boolean) => {
        expect(approved).assertTrue();
        expect(repository.approveCalls).assertEqual(1);
        expect(store.approvalState).assertEqual(ApprovalUiState.Confirmed);
        expect(store.approvalReadbackConfirmed).assertTrue();
        expect(store.approvalReadbackHeadSha).assertEqual('head-a');
        expect(callbackCount).assertEqual(1);
        expect(todo.completed).assertFalse();
      });
    });

    it('suppresses_duplicate_approval_submissions', 0, () => {
      const repository = new FakePullRequestRepository();
      repository.detailResponses.push(detail('head-a'));
      const store = new PullRequestDetailStore(repository, 'alice');
      return store.open(REF).then(() => {
        repository.detailResponses.push(detail('head-a'));
        repository.detailResponses.push(detail('head-a', 'true'));
        const approve = new VoidDeferred();
        repository.approveDeferred = approve;
        const first = store.approve();
        const second = store.approve();
        approve.resolve();
        return Promise.all([first, second]);
      }).then((results) => {
        expect(results[0]).assertTrue();
        expect(results[1]).assertFalse();
        expect(repository.approveCalls).assertEqual(1);
      });
    });

    it('keeps_approval_api_error_unchanged', 0, () => {
      const repository = new FakePullRequestRepository();
      repository.detailResponses.push(detail('head-a'));
      const writeError = new ApiError(ApiErrorKind.RateLimited, 429, 429,
        'slow down', 'trace', '/review');
      const store = new PullRequestDetailStore(repository, 'alice');
      return store.open(REF).then(() => {
        repository.detailResponses.push(detail('head-a'));
        repository.approveError = writeError;
        return store.approve();
      }).then((approved: boolean) => {
        expect(approved).assertFalse();
        expect(store.approvalError === writeError).assertTrue();
        expect(store.approvalReadbackConfirmed).assertFalse();
      });
    });

    it('ignores_stale_detail_response', 0, () => {
      const repository = new FakePullRequestRepository();
      const store = new PullRequestDetailStore(repository, 'alice');
      store.ref = REF;
      const first = new DetailDeferred();
      const second = new DetailDeferred();
      repository.detailResponses.push(first);
      repository.detailResponses.push(second);
      const firstLoad = store.refreshDetail();
      const secondLoad = store.refreshDetail();
      second.resolve(detail('head-b', 'optional', 'New response'));
      return secondLoad.then(() => {
        first.resolve(detail('head-c', 'optional', 'Old response'));
        return firstLoad;
      }).then(() => {
        expect(store.detail?.title).assertEqual('New response');
        expect(store.detail?.headSha).assertEqual('head-b');
      });
    });

    it('cancellation_prevents_late_detail_response_from_updating_store', 0, () => {
      const repository = new FakePullRequestRepository();
      const store = new PullRequestDetailStore(repository, 'alice');
      store.ref = REF;
      const pending = new DetailDeferred();
      repository.detailResponses.push(pending);
      const load = store.refreshDetail();
      store.cancelPending();
      pending.resolve(detail('head-a'));
      return load.then(() => {
        expect(store.detail === undefined).assertTrue();
        expect(store.detailError === undefined).assertTrue();
        expect(store.loadingDetail).assertFalse();
      });
    });
  });
}

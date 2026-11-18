import { describe, it, expect } from '@ohos/hypium';

import { ApiError, ApiErrorKind } from '../main/ets/common/ApiError';
import { CancellationSignal } from '../main/ets/common/Cancellation';
import { OffsetPageRequest, Page, PageRequest } from '../main/ets/common/Pager';
import {
  CollaborationComment,
  IssueDetail,
  RepositoryItemRef
} from '../main/ets/model/CollaborationEntities';
import { IssueRepository } from '../main/ets/repository/Ports';
import { IssueDetailStore } from '../main/ets/viewmodel/IssueDetailStore';
import { LoadState } from '../main/ets/viewmodel/SessionStore';

class Deferred<T> {
  readonly promise: Promise<T>;
  private resolver: (value: T) => void = () => {};

  constructor() {
    this.promise = new Promise<T>((resolve: (value: T) => void) => {
      this.resolver = resolve;
    });
  }

  resolve(value: T): void {
    this.resolver(value);
  }
}

type IssueResult = IssueDetail | ApiError | Deferred<IssueDetail>;
type CommentResult = Page<CollaborationComment> | ApiError | Deferred<Page<CollaborationComment>>;

class FakeIssueRepository implements IssueRepository {
  issueResults: IssueResult[] = [];
  commentResults: CommentResult[] = [];
  addErrors: ApiError[] = [];
  addGate: Deferred<void> | undefined = undefined;
  issueRequests: RepositoryItemRef[] = [];
  commentRequests: PageRequest[] = [];
  addBodies: string[] = [];

  async issue(ref: RepositoryItemRef, cancel?: CancellationSignal): Promise<IssueDetail> {
    this.issueRequests.push(ref);
    if (cancel !== undefined && cancel.isCanceled()) {
      throw new ApiError(ApiErrorKind.Canceled, 0, 0, 'canceled', '', ref.key());
    }
    const result = this.issueResults.shift();
    if (result instanceof Deferred) {
      return result.promise;
    }
    if (result instanceof ApiError) {
      throw result;
    }
    if (result === undefined) {
      throw new Error('missing fake issue');
    }
    return result;
  }

  async issueComments(ref: RepositoryItemRef, request: PageRequest,
    cancel?: CancellationSignal): Promise<Page<CollaborationComment>> {
    this.commentRequests.push(request);
    if (cancel !== undefined && cancel.isCanceled()) {
      throw new ApiError(ApiErrorKind.Canceled, 0, 0, 'canceled', '', ref.key());
    }
    const result = this.commentResults.shift();
    if (result instanceof Deferred) {
      return result.promise;
    }
    if (result instanceof ApiError) {
      throw result;
    }
    return result === undefined ? Page.empty<CollaborationComment>(request) : result;
  }

  async addIssueComment(ref: RepositoryItemRef, body: string,
    cancel?: CancellationSignal): Promise<string> {
    this.addBodies.push(body);
    if (cancel !== undefined && cancel.isCanceled()) {
      throw new ApiError(ApiErrorKind.Canceled, 0, 0, 'canceled', '', ref.key());
    }
    if (this.addGate !== undefined) {
      const gate = this.addGate;
      this.addGate = undefined;
      await gate.promise;
    }
    if (this.addErrors.length > 0) {
      throw this.addErrors.shift() as ApiError;
    }
    return '';
  }
}

function issue(title: string = 'Issue title'): IssueDetail {
  return new IssueDetail(new RepositoryItemRef('owner', 'repo', 7), title, 'Issue body',
    'open', 'https://atomgit.com/owner/repo/issues/7', '2026-11-01T08:00:00Z',
    '2026-11-02T08:00:00Z', 'alice', ['bug']);
}

function comment(id: string, body: string = 'Comment body'): CollaborationComment {
  return new CollaborationComment(id, body, 'bob',
    'https://atomgit.com/owner/repo/issues/7#comment-' + id,
    '2026-11-01T09:00:00Z');
}

function page(items: CollaborationComment[], request: PageRequest,
  next?: PageRequest): Page<CollaborationComment> {
  return new Page<CollaborationComment>(items, request, next);
}

function storeWith(repository: FakeIssueRepository,
  onCommentPosted: (ref: RepositoryItemRef) => void = () => {}): IssueDetailStore {
  const store = new IssueDetailStore(repository, onCommentPosted);
  store.initialize(new RepositoryItemRef('owner', 'repo', 7));
  return store;
}

export default function issueDetailStoreTest() {
  describe('IssueDetailStore', () => {
    it('loads_issue_and_first_comment_page', 0, () => {
      const data = new FakeIssueRepository();
      data.issueResults.push(issue());
      data.commentResults.push(page([comment('1'), comment('2')],
        new OffsetPageRequest(), new OffsetPageRequest(2)));
      const store = storeWith(data);
      return store.load().then(() => {
        expect(store.state).assertEqual(LoadState.Ready);
        expect(store.issue?.title).assertEqual('Issue title');
        expect(store.comments.length).assertEqual(2);
        expect(store.empty).assertFalse();
        expect(store.hasMore).assertTrue();
        expect(data.issueRequests.length).assertEqual(1);
        expect(data.commentRequests.length).assertEqual(1);
        expect((data.commentRequests[0] as OffsetPageRequest).page).assertEqual(1);
      });
    });

    it('retries_after_initial_failure', 0, () => {
      const data = new FakeIssueRepository();
      data.issueResults.push(new ApiError(ApiErrorKind.Network, 0, 0,
        'offline', '', '/issues/7'));
      data.issueResults.push(issue('Recovered'));
      data.commentResults.push(page([], new OffsetPageRequest()));
      const store = storeWith(data);
      return store.load().then(() => {
        expect(store.state).assertEqual(LoadState.Error);
        expect(store.errorMessage.length > 0).assertTrue();
        return store.retry();
      }).then(() => {
        expect(store.state).assertEqual(LoadState.Ready);
        expect(store.issue?.title).assertEqual('Recovered');
        expect(store.errorMessage).assertEqual('');
      });
    });

    it('refresh_replaces_issue_and_comments_from_first_page', 0, () => {
      const data = new FakeIssueRepository();
      data.issueResults.push(issue('Old title'));
      data.commentResults.push(page([comment('old')], new OffsetPageRequest()));
      data.issueResults.push(issue('New title'));
      data.commentResults.push(page([comment('new')], new OffsetPageRequest()));
      const store = storeWith(data);
      return store.load().then(() => store.refresh()).then(() => {
        expect(store.issue?.title).assertEqual('New title');
        expect(store.comments.length).assertEqual(1);
        expect(store.comments[0].id).assertEqual('new');
        expect(data.commentRequests.length).assertEqual(2);
        expect((data.commentRequests[1] as OffsetPageRequest).page).assertEqual(1);
      });
    });

    it('load_more_deduplicates_and_clears_last_page_flag', 0, () => {
      const data = new FakeIssueRepository();
      data.issueResults.push(issue());
      data.commentResults.push(page([comment('same')], new OffsetPageRequest(1, 20),
        new OffsetPageRequest(2, 20)));
      data.commentResults.push(page([comment('same'), comment('new')],
        new OffsetPageRequest(2, 20)));
      const store = storeWith(data);
      return store.load().then(() => store.loadMore()).then(() => {
        expect(store.comments.length).assertEqual(2);
        expect(store.comments[1].id).assertEqual('new');
        expect(store.hasMore).assertFalse();
        expect((data.commentRequests[1] as OffsetPageRequest).page).assertEqual(2);
      });
    });

    it('empty_comment_page_marks_empty_state', 0, () => {
      const data = new FakeIssueRepository();
      data.issueResults.push(issue());
      data.commentResults.push(page([], new OffsetPageRequest()));
      const store = storeWith(data);
      return store.load().then(() => {
        expect(store.comments.length).assertEqual(0);
        expect(store.empty).assertTrue();
        expect(store.hasMore).assertFalse();
      });
    });

    it('submit_success_reads_back_before_clearing_draft', 0, () => {
      const data = new FakeIssueRepository();
      data.issueResults.push(issue());
      data.commentResults.push(page([], new OffsetPageRequest()));
      data.commentResults.push(page([comment('created', 'Looks good')], new OffsetPageRequest()));
      let callbackCount = 0;
      let callbackKey = '';
      const store = storeWith(data, (ref: RepositoryItemRef) => {
        callbackCount++;
        callbackKey = ref.key();
      });
      return store.load().then(() => {
        store.updateDraft('Looks good');
        return store.submitComment();
      }).then((posted: boolean) => {
        expect(posted).assertTrue();
        expect(data.addBodies.length).assertEqual(1);
        expect(data.addBodies[0]).assertEqual('Looks good');
        expect(data.commentRequests.length).assertEqual(2);
        expect(store.comments.length).assertEqual(1);
        expect(store.comments[0].id).assertEqual('created');
        expect(store.draft).assertEqual('');
        expect(store.successMessage).assertEqual('Comment posted');
        expect(store.commentPosted).assertTrue();
        expect(callbackCount).assertEqual(1);
        expect(callbackKey).assertEqual('owner/repo#7');
      });
    });

    it('submit_failure_preserves_draft_and_does_not_read_back', 0, () => {
      const data = new FakeIssueRepository();
      data.issueResults.push(issue());
      data.commentResults.push(page([], new OffsetPageRequest()));
      data.addErrors.push(new ApiError(ApiErrorKind.Network, 0, 0,
        'offline', '', '/comments'));
      const store = storeWith(data);
      return store.load().then(() => {
        store.updateDraft('Keep this draft');
        return store.submitComment();
      }).then((posted: boolean) => {
        expect(posted).assertFalse();
        expect(store.draft).assertEqual('Keep this draft');
        expect(store.sendErrorMessage.length > 0).assertTrue();
        expect(store.commentPosted).assertFalse();
        expect(data.commentRequests.length).assertEqual(1);
      });
    });

    it('readback_failure_preserves_draft_and_does_not_claim_success', 0, () => {
      const data = new FakeIssueRepository();
      data.issueResults.push(issue());
      data.commentResults.push(page([], new OffsetPageRequest()));
      data.commentResults.push(new ApiError(ApiErrorKind.Network, 0, 0,
        'offline', '', '/comments'));
      let callbackCount = 0;
      const store = storeWith(data, () => {
        callbackCount++;
      });
      return store.load().then(() => {
        store.updateDraft('Unconfirmed comment');
        return store.submitComment();
      }).then((posted: boolean) => {
        expect(posted).assertFalse();
        expect(store.draft).assertEqual('Unconfirmed comment');
        expect(store.successMessage).assertEqual('');
        expect(store.commentPosted).assertFalse();
        expect(store.sendErrorMessage.indexOf('confirmation failed') >= 0).assertTrue();
        expect(callbackCount).assertEqual(0);
      });
    });

    it('suppresses_duplicate_submission_while_sending', 0, () => {
      const data = new FakeIssueRepository();
      data.issueResults.push(issue());
      data.commentResults.push(page([], new OffsetPageRequest()));
      data.commentResults.push(page([comment('created', 'Once')], new OffsetPageRequest()));
      const gate = new Deferred<void>();
      data.addGate = gate;
      const store = storeWith(data);
      return store.load().then(() => {
        store.updateDraft('Once');
        const first = store.submitComment();
        const second = store.submitComment();
        return second.then((secondPosted: boolean) => {
          expect(secondPosted).assertFalse();
          expect(data.addBodies.length).assertEqual(1);
          gate.resolve(undefined);
          return first;
        });
      }).then((firstPosted: boolean) => {
        expect(firstPosted).assertTrue();
        expect(data.addBodies.length).assertEqual(1);
      });
    });

    it('cancels_stale_initial_response', 0, () => {
      const data = new FakeIssueRepository();
      const pending = new Deferred<IssueDetail>();
      data.issueResults.push(pending);
      const store = storeWith(data);
      const load = store.load();
      store.cancelPending();
      pending.resolve(issue('Stale'));
      return load.then(() => {
        expect(store.issue).assertEqual(undefined);
        expect(store.state).assertEqual(LoadState.Idle);
      });
    });

    it('load_more_failure_keeps_existing_comments', 0, () => {
      const data = new FakeIssueRepository();
      data.issueResults.push(issue());
      data.commentResults.push(page([comment('first')], new OffsetPageRequest(1, 20),
        new OffsetPageRequest(2, 20)));
      data.commentResults.push(new ApiError(ApiErrorKind.ServerError, 500, 500,
        'server', '', '/comments'));
      const store = storeWith(data);
      return store.load().then(() => store.loadMore()).then(() => {
        expect(store.comments.length).assertEqual(1);
        expect(store.comments[0].id).assertEqual('first');
        expect(store.hasMore).assertTrue();
        expect(store.commentError.length > 0).assertTrue();
      });
    });
  });
}

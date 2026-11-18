import { describe, it, expect } from '@ohos/hypium';

import { ApiError, ApiErrorKind } from '../main/ets/common/ApiError';
import { CancellationSignal } from '../main/ets/common/Cancellation';
import { OffsetPageRequest, Page, PageRequest } from '../main/ets/common/Pager';
import { RepositoryItemKind, RepositoryItemRef, WorkItem } from '../main/ets/model/CollaborationEntities';
import { PullRequestTodoScope, TodoRepository } from '../main/ets/repository/Ports';
import {
  TodoCategory,
  TodoScope,
  TodoStore
} from '../main/ets/viewmodel/TodoStore';

function item(kind: RepositoryItemKind, number: number, updatedAt: string = '2026-11-18T08:00:00Z'):
  WorkItem {
  return new WorkItem(kind, new RepositoryItemRef('owner', 'repo', number),
    'Item ' + number.toString(), 'open', 'https://atomgit.com/owner/repo/' + number.toString(),
    updatedAt);
}

function fullPage(items: WorkItem[], request: PageRequest): Page<WorkItem> {
  const offset = request as OffsetPageRequest;
  return new Page<WorkItem>(items, request, new OffsetPageRequest(offset.page + 1, offset.perPage));
}

function shortPage(items: WorkItem[], request: PageRequest): Page<WorkItem> {
  return new Page<WorkItem>(items, request);
}

class FakeTodoRepository implements TodoRepository {
  assignedResults: Array<Page<WorkItem> | ApiError> = [];
  createdResults: Array<Page<WorkItem> | ApiError> = [];
  assignedPullResults: Array<Page<WorkItem> | ApiError> = [];
  approvalResults: Array<Page<WorkItem> | ApiError> = [];
  reviewResults: Array<Page<WorkItem> | ApiError> = [];
  createdPullResults: Array<Page<WorkItem> | ApiError> = [];

  assignedRequests: PageRequest[] = [];
  createdRequests: PageRequest[] = [];
  assignedPullRequests: PageRequest[] = [];
  approvalRequests: PageRequest[] = [];
  reviewRequests: PageRequest[] = [];
  createdPullRequests: PageRequest[] = [];
  calls: string[] = [];

  async assignedIssues(request: PageRequest): Promise<Page<WorkItem>> {
    this.calls.push('assignedIssues');
    this.assignedRequests.push(request);
    return this.take(this.assignedResults, request);
  }

  async createdIssues(request: PageRequest): Promise<Page<WorkItem>> {
    this.calls.push('createdIssues');
    this.createdRequests.push(request);
    return this.take(this.createdResults, request);
  }

  async pullRequests(scope: PullRequestTodoScope, request: PageRequest): Promise<Page<WorkItem>> {
    this.calls.push('pullRequests:' + scope);
    if (scope === PullRequestTodoScope.AssignedToMe) {
      this.assignedPullRequests.push(request);
      return this.take(this.assignedPullResults, request);
    }
    if (scope === PullRequestTodoScope.NeedsApproval) {
      this.approvalRequests.push(request);
      return this.take(this.approvalResults, request);
    }
    if (scope === PullRequestTodoScope.NeedsReview) {
      this.reviewRequests.push(request);
      return this.take(this.reviewResults, request);
    }
    this.createdPullRequests.push(request);
    return this.take(this.createdPullResults, request);
  }

  private take(results: Array<Page<WorkItem> | ApiError>, request: PageRequest):
    Promise<Page<WorkItem>> {
    const result = results.length > 0
      ? results.shift() as Page<WorkItem> | ApiError : Page.empty<WorkItem>(request);
    if (result instanceof ApiError) {
      throw result;
    }
    return Promise.resolve(result);
  }
}

type ResolvePage = (page: Page<WorkItem>) => void;

class DeferredTodoRepository extends FakeTodoRepository {
  private assignedResolvers: ResolvePage[] = [];
  private assignedCallCount: number = 0;

  async assignedIssues(request: PageRequest): Promise<Page<WorkItem>> {
    this.calls.push('assignedIssues');
    this.assignedRequests.push(request);
    this.assignedCallCount++;
    if (this.assignedCallCount === 1) {
      return new Promise<Page<WorkItem>>((resolve) => {
        this.assignedResolvers.push((page: Page<WorkItem>) => {
          resolve(page);
        });
      });
    }
    const result = this.assignedResults.length > 0
      ? this.assignedResults.shift() as Page<WorkItem> | ApiError
      : Page.empty<WorkItem>(request);
    if (result instanceof ApiError) {
      throw result;
    }
    return result;
  }

  resolveFirst(page: Page<WorkItem>): void {
    const resolver = this.assignedResolvers.shift();
    if (resolver !== undefined) {
      resolver(page);
    }
  }
}

export default function todoStoreTest() {
  describe('TodoStore', () => {
    it('loads_six_independent_scopes', 0, () => {
      const data = new FakeTodoRepository();
      data.assignedResults.push(fullPage([item(RepositoryItemKind.Issue, 1)],
        new OffsetPageRequest()));
      data.createdResults.push(fullPage([item(RepositoryItemKind.Issue, 2)],
        new OffsetPageRequest()));
      data.assignedPullResults.push(fullPage([item(RepositoryItemKind.PullRequest, 3)],
        new OffsetPageRequest()));
      data.approvalResults.push(fullPage([item(RepositoryItemKind.PullRequest, 4)],
        new OffsetPageRequest()));
      data.reviewResults.push(fullPage([item(RepositoryItemKind.PullRequest, 5)],
        new OffsetPageRequest()));
      data.createdPullResults.push(fullPage([item(RepositoryItemKind.PullRequest, 6)],
        new OffsetPageRequest()));
      const store = new TodoStore(data);
      store.initialize('account-a');
      return store.loadAll().then(() => {
        expect(store.loadedCount(TodoScope.AssignedIssues)).assertEqual(1);
        expect(store.loadedCount(TodoScope.CreatedIssues)).assertEqual(1);
        expect(store.loadedCount(TodoScope.AssignedPullRequests)).assertEqual(1);
        expect(store.loadedCount(TodoScope.NeedsApprovalPullRequests)).assertEqual(1);
        expect(store.loadedCount(TodoScope.NeedsReviewPullRequests)).assertEqual(1);
        expect(store.loadedCount(TodoScope.CreatedPullRequests)).assertEqual(1);
        expect(data.calls.length).assertEqual(6);
      });
    });

    it('keeps_each_scope_pagination_independent', 0, () => {
      const data = new FakeTodoRepository();
      data.assignedResults.push(fullPage([item(RepositoryItemKind.Issue, 1)],
        new OffsetPageRequest(1, 1)));
      data.assignedResults.push(shortPage([item(RepositoryItemKind.Issue, 2)],
        new OffsetPageRequest(2, 1)));
      data.createdPullResults.push(fullPage([item(RepositoryItemKind.PullRequest, 3)],
        new OffsetPageRequest(1, 1)));
      data.createdPullResults.push(shortPage([item(RepositoryItemKind.PullRequest, 4)],
        new OffsetPageRequest(2, 1)));
      const store = new TodoStore(data);
      store.initialize('account-a');
      return store.loadAll()
        .then(() => store.loadMore(TodoScope.AssignedIssues))
        .then(() => store.loadMore(TodoScope.CreatedPullRequests))
        .then(() => {
          expect(data.assignedRequests.length).assertEqual(2);
          expect(data.createdPullRequests.length).assertEqual(2);
          expect((data.assignedRequests[1] as OffsetPageRequest).page).assertEqual(2);
          expect((data.createdPullRequests[1] as OffsetPageRequest).page).assertEqual(2);
          expect(store.loadedCount(TodoScope.AssignedIssues)).assertEqual(2);
          expect(store.loadedCount(TodoScope.CreatedPullRequests)).assertEqual(2);
          expect(store.stateFor(TodoScope.AssignedIssues).hasMore).assertFalse();
          expect(store.stateFor(TodoScope.CreatedPullRequests).hasMore).assertFalse();
        });
    });

    it('replaces_stale_scope_results', 0, () => {
      const data = new DeferredTodoRepository();
      data.assignedResults.push(shortPage([item(RepositoryItemKind.Issue, 2)],
        new OffsetPageRequest()));
      const store = new TodoStore(data);
      store.initialize('account-a');
      const first = store.refreshScope(TodoScope.AssignedIssues);
      const second = store.refreshScope(TodoScope.AssignedIssues);
      return second.then(() => {
        expect(store.loadedCount(TodoScope.AssignedIssues)).assertEqual(1);
        expect(store.stateFor(TodoScope.AssignedIssues).items[0].ref.number).assertEqual(2);
        data.resolveFirst(shortPage([item(RepositoryItemKind.Issue, 1)],
          new OffsetPageRequest()));
        return Promise.resolve();
      }).then(() => {
        expect(store.stateFor(TodoScope.AssignedIssues).items[0].ref.number).assertEqual(2);
        return first;
      });
    });

    it('keeps_successful_scopes_when_one_source_fails', 0, () => {
      const data = new FakeTodoRepository();
      data.assignedResults.push(shortPage([item(RepositoryItemKind.Issue, 1)],
        new OffsetPageRequest()));
      data.approvalResults.push(new ApiError(
        ApiErrorKind.Network, 0, 0, 'offline', '', '/user/pulls'));
      const store = new TodoStore(data);
      store.initialize('account-a');
      return store.loadAll().then(() => {
        expect(store.loadedCount(TodoScope.AssignedIssues)).assertEqual(1);
        expect(store.loadedCount(TodoScope.NeedsApprovalPullRequests)).assertEqual(0);
        expect(store.stateFor(TodoScope.NeedsApprovalPullRequests).errorMessage.length > 0)
          .assertTrue();
        expect(store.failedScopeCount(TodoCategory.Pending)).assertEqual(1);
        expect(store.failedScopeCount(TodoCategory.Created)).assertEqual(0);
      });
    });

    it('retries_failed_initial_loads_and_refreshes_from_page_one', 0, () => {
      const data = new FakeTodoRepository();
      data.assignedResults.push(new ApiError(
        ApiErrorKind.ServerError, 500, 0, 'failed', '', '/user/issues'));
      data.assignedResults.push(shortPage([item(RepositoryItemKind.Issue, 1)],
        new OffsetPageRequest()));
      data.assignedResults.push(shortPage([item(RepositoryItemKind.Issue, 2)],
        new OffsetPageRequest()));
      const store = new TodoStore(data);
      store.initialize('account-a');
      return store.loadAll().then(() => {
        expect(store.stateFor(TodoScope.AssignedIssues).errorMessage.length > 0).assertTrue();
        return store.retry(TodoScope.AssignedIssues);
      }).then(() => {
        expect(store.loadedCount(TodoScope.AssignedIssues)).assertEqual(1);
        expect(store.stateFor(TodoScope.AssignedIssues).items[0].ref.number).assertEqual(1);
        return store.refresh();
      }).then(() => {
        expect(store.loadedCount(TodoScope.AssignedIssues)).assertEqual(1);
        expect(store.stateFor(TodoScope.AssignedIssues).items[0].ref.number).assertEqual(2);
        expect((data.assignedRequests[2] as OffsetPageRequest).page).assertEqual(1);
      });
    });

    it('deduplicates_and_reports_only_loaded_counts', 0, () => {
      const data = new FakeTodoRepository();
      const duplicate = item(RepositoryItemKind.Issue, 1);
      data.assignedResults.push(shortPage([
        duplicate,
        duplicate,
        item(RepositoryItemKind.Issue, 2)
      ], new OffsetPageRequest()));
      const store = new TodoStore(data);
      store.initialize('account-a');
      return store.loadAll().then(() => {
        expect(store.loadedCount(TodoScope.AssignedIssues)).assertEqual(2);
        expect(store.categoryLoadedCount(TodoCategory.Pending)).assertEqual(2);
        expect(store.scopeCountText(TodoScope.AssignedIssues)).assertEqual('2 loaded');
        expect(store.scopeCountText(TodoScope.AssignedIssues).indexOf('all') < 0).assertTrue();
      });
    });

    it('clears_results_when_account_or_project_scope_changes', 0, () => {
      const data = new FakeTodoRepository();
      data.assignedResults.push(shortPage([item(RepositoryItemKind.Issue, 1)],
        new OffsetPageRequest()));
      const store = new TodoStore(data);
      store.initialize('account-a');
      return store.loadAll().then(() => {
        expect(store.loadedCount(TodoScope.AssignedIssues)).assertEqual(1);
        store.initialize('account-b');
        expect(store.loadedCount(TodoScope.AssignedIssues)).assertEqual(0);
        expect(store.stateFor(TodoScope.AssignedIssues).request.page).assertEqual(1);
        store.initialize('account-b', 'owner/repo');
        expect(store.loadedCount(TodoScope.AssignedIssues)).assertEqual(0);
      });
    });

    it('retries_load_more_without_restarting_the_scope', 0, () => {
      const data = new FakeTodoRepository();
      data.assignedResults.push(fullPage([item(RepositoryItemKind.Issue, 1)],
        new OffsetPageRequest(1, 1)));
      data.assignedResults.push(new ApiError(
        ApiErrorKind.Network, 0, 0, 'offline', '', '/user/issues'));
      data.assignedResults.push(shortPage([item(RepositoryItemKind.Issue, 2)],
        new OffsetPageRequest(2, 1)));
      const store = new TodoStore(data);
      store.initialize('account-a');
      return store.loadAll()
        .then(() => store.loadMore(TodoScope.AssignedIssues))
        .then(() => {
          expect(store.loadedCount(TodoScope.AssignedIssues)).assertEqual(1);
          expect(store.stateFor(TodoScope.AssignedIssues).errorMessage.length > 0).assertTrue();
          return store.retry(TodoScope.AssignedIssues);
        })
        .then(() => {
          expect(data.assignedRequests.length).assertEqual(3);
          expect((data.assignedRequests[2] as OffsetPageRequest).page).assertEqual(2);
          expect(store.loadedCount(TodoScope.AssignedIssues)).assertEqual(2);
        });
    });
  });
}

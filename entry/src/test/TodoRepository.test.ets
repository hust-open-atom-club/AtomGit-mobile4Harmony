import { describe, it, expect } from '@ohos/hypium';

import { ApiError, ApiErrorKind } from '../main/ets/common/ApiError';
import { CancellationSignal } from '../main/ets/common/Cancellation';
import { CursorPageRequest, OffsetPageRequest, Page } from '../main/ets/common/Pager';
import { RepositoryItemKind, WorkItem } from '../main/ets/model/CollaborationEntities';
import { PullRequestTodoScope } from '../main/ets/repository/Ports';
import { TodoApiRepository } from '../main/ets/repository/TodoRepository';
import { FakeHttp } from './fakes/FakeHttp';

function issuePayload(number: number, repository: boolean = true): string {
  return '{"number":"' + number.toString() + '","title":"Issue ' + number.toString()
    + '","state":"open","updated_at":"2026-11-18T08:00:00Z"'
    + (repository ? ',"repository":{"full_name":"owner/repo"}' : '')
    + '}';
}

function pullRequestPayload(number: number): string {
  return '{"number":' + number.toString() + ',"title":"Pull request ' + number.toString()
    + '","state":"open","updated_at":"2026-11-18T09:00:00Z",'
    + '"repository":{"full_name":"owner/repo"}}';
}

function pageUrl(http: FakeHttp, index: number): string {
  return http.requestedUrls[index];
}

class CanceledSignal implements CancellationSignal {
  isCanceled(): boolean {
    return true;
  }

  cancel(): void {
  }

  wait(): Promise<void> {
    return Promise.resolve();
  }
}

export default function todoRepositoryTest() {
  describe('TodoRepository', () => {
    it('maps_all_six_scopes_to_verified_paths_and_queries', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/user/issues', '[' + issuePayload(1) + ']');
      http.onJson('/api/v5/user/pulls', '[' + pullRequestPayload(2) + ']');
      const repo = new TodoApiRepository(http);
      return repo.assignedIssues(new OffsetPageRequest(2, 10))
        .then((page: Page<WorkItem>) => {
          expect(page.items.length).assertEqual(1);
          expect(page.items[0].kind).assertEqual(RepositoryItemKind.Issue);
          expect(page.items[0].ref.key()).assertEqual('owner/repo#1');
          expect(pageUrl(http, 0).indexOf('/api/v5/user/issues?') >= 0).assertTrue();
          expect(pageUrl(http, 0).indexOf('filter=assigned') >= 0).assertTrue();
          expect(pageUrl(http, 0).indexOf('state=open') >= 0).assertTrue();
          expect(pageUrl(http, 0).indexOf('page=2') >= 0).assertTrue();
          expect(pageUrl(http, 0).indexOf('per_page=10') >= 0).assertTrue();
          return repo.createdIssues(new OffsetPageRequest(1, 20));
        })
        .then(() => {
          expect(pageUrl(http, 1).indexOf('/api/v5/user/issues?') >= 0).assertTrue();
          expect(pageUrl(http, 1).indexOf('filter=created') >= 0).assertTrue();
          expect(pageUrl(http, 1).indexOf('state=open') >= 0).assertTrue();
          expect(pageUrl(http, 1).indexOf('page=1') >= 0).assertTrue();
          expect(pageUrl(http, 1).indexOf('per_page=20') >= 0).assertTrue();
          return repo.pullRequests(PullRequestTodoScope.NeedsApproval, new OffsetPageRequest());
        })
        .then(() => {
          expect(pageUrl(http, 2).indexOf('/api/v5/user/pulls?') >= 0).assertTrue();
          expect(pageUrl(http, 2).indexOf('scope=need_my_approve') >= 0).assertTrue();
          expect(pageUrl(http, 2).indexOf('state=open') >= 0).assertTrue();
          expect(pageUrl(http, 2).indexOf('page=1') >= 0).assertTrue();
          expect(pageUrl(http, 2).indexOf('per_page=20') >= 0).assertTrue();
          return repo.pullRequests(PullRequestTodoScope.NeedsReview, new OffsetPageRequest());
        })
        .then(() => {
          expect(pageUrl(http, 3).indexOf('/api/v5/user/pulls?') >= 0).assertTrue();
          expect(pageUrl(http, 3).indexOf('scope=need_my_review') >= 0).assertTrue();
          expect(pageUrl(http, 3).indexOf('state=open') >= 0).assertTrue();
          expect(pageUrl(http, 3).indexOf('page=1') >= 0).assertTrue();
          expect(pageUrl(http, 3).indexOf('per_page=20') >= 0).assertTrue();
          return repo.pullRequests(PullRequestTodoScope.AssignedToMe, new OffsetPageRequest());
        })
        .then(() => {
          expect(pageUrl(http, 4).indexOf('/api/v5/user/pulls?') >= 0).assertTrue();
          expect(pageUrl(http, 4).indexOf('scope=assigned_to_me') >= 0).assertTrue();
          expect(pageUrl(http, 4).indexOf('state=open') >= 0).assertTrue();
          expect(pageUrl(http, 4).indexOf('page=1') >= 0).assertTrue();
          expect(pageUrl(http, 4).indexOf('per_page=20') >= 0).assertTrue();
          return repo.pullRequests(PullRequestTodoScope.CreatedByMe, new OffsetPageRequest());
        })
        .then((page: Page<WorkItem>) => {
          expect(pageUrl(http, 5).indexOf('/api/v5/user/pulls?') >= 0).assertTrue();
          expect(pageUrl(http, 5).indexOf('scope=created_by_me') >= 0).assertTrue();
          expect(pageUrl(http, 5).indexOf('state=open') >= 0).assertTrue();
          expect(pageUrl(http, 5).indexOf('page=1') >= 0).assertTrue();
          expect(pageUrl(http, 5).indexOf('per_page=20') >= 0).assertTrue();
          expect(page.items[0].kind).assertEqual(RepositoryItemKind.PullRequest);
        });
    });

    it('falls_back_to_web_url_identity_and_optional_fields', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/user/issues',
        '[{"number":"4","state":"open","html_url":"https://atomgit.com/acme/demo/issues/4"}]');
      const repo = new TodoApiRepository(http);
      return repo.assignedIssues(new OffsetPageRequest()).then((page: Page<WorkItem>) => {
        expect(page.items.length).assertEqual(1);
        expect(page.items[0].ref.owner).assertEqual('acme');
        expect(page.items[0].ref.repo).assertEqual('demo');
        expect(page.items[0].ref.number).assertEqual(4);
        expect(page.items[0].title).assertEqual('Issue #4');
        expect(page.items[0].state).assertEqual('open');
        expect(page.items[0].updatedAt).assertEqual('');
      });
    });

    it('deduplicates_items_within_one_page', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/user/issues', '[' + issuePayload(8) + ',' + issuePayload(8) + ']');
      const repo = new TodoApiRepository(http);
      return repo.assignedIssues(new OffsetPageRequest()).then((page: Page<WorkItem>) => {
        expect(page.items.length).assertEqual(1);
      });
    });

    it('uses_short_pages_as_the_last_page_and_full_pages_as_continuable', 0, () => {
      const shortHttp = new FakeHttp();
      shortHttp.onJson('/api/v5/user/issues', '[' + issuePayload(1) + ']');
      const shortRepo = new TodoApiRepository(shortHttp);
      return shortRepo.assignedIssues(new OffsetPageRequest(1, 2)).then((shortPage: Page<WorkItem>) => {
        expect(shortPage.hasMore).assertFalse();
        const fullHttp = new FakeHttp();
        fullHttp.onJson('/api/v5/user/issues', '[' + issuePayload(1) + ',' + issuePayload(2) + ']');
        const fullRepo = new TodoApiRepository(fullHttp);
        return fullRepo.assignedIssues(new OffsetPageRequest(1, 2));
      }).then((fullPage: Page<WorkItem>) => {
        expect(fullPage.hasMore).assertTrue();
        expect(fullPage.nextRequest instanceof OffsetPageRequest).assertTrue();
        expect((fullPage.nextRequest as OffsetPageRequest).page).assertEqual(2);
      });
    });

    it('returns_empty_page_without_fabricating_more', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/user/pulls', '[]');
      const repo = new TodoApiRepository(http);
      return repo.pullRequests(PullRequestTodoScope.NeedsReview, new OffsetPageRequest())
        .then((page: Page<WorkItem>) => {
          expect(page.items.length).assertEqual(0);
          expect(page.hasMore).assertFalse();
          expect(page.nextRequest === undefined).assertTrue();
        });
    });

    it('rejects_malformed_payload_without_identity', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/user/issues', '[{"number":"4","title":"Orphan"}]');
      const repo = new TodoApiRepository(http);
      return repo.assignedIssues(new OffsetPageRequest()).then(() => {
        expect(false).assertTrue();
      }).catch((error: ESObject) => {
        expect(error instanceof ApiError).assertTrue();
        expect((error as ApiError).kind).assertEqual(ApiErrorKind.Parse);
      });
    });

    it('rejects_non_array_and_invalid_json_payloads', 0, () => {
      const objectHttp = new FakeHttp();
      objectHttp.onJson('/api/v5/user/issues', '{"items":[]}');
      const objectRepo = new TodoApiRepository(objectHttp);
      return objectRepo.createdIssues(new OffsetPageRequest()).then(() => {
        expect(false).assertTrue();
      }).catch((error: ESObject) => {
        expect((error as ApiError).kind).assertEqual(ApiErrorKind.Parse);
        const invalidHttp = new FakeHttp();
        invalidHttp.onJson('/api/v5/user/pulls', '{not-json');
        const invalidRepo = new TodoApiRepository(invalidHttp);
        return invalidRepo.pullRequests(PullRequestTodoScope.CreatedByMe, new OffsetPageRequest());
      }).then(() => {
        expect(false).assertTrue();
      }).catch((error: ESObject) => {
        expect((error as ApiError).kind).assertEqual(ApiErrorKind.Parse);
      });
    });

    it('preserves_api_errors', 0, () => {
      const http = new FakeHttp();
      http.onError('/api/v5/user/issues',
        new ApiError(ApiErrorKind.Forbidden, 403, 403, 'forbidden', 'trace', '/user/issues'));
      const repo = new TodoApiRepository(http);
      return repo.assignedIssues(new OffsetPageRequest()).then(() => {
        expect(false).assertTrue();
      }).catch((error: ESObject) => {
        expect((error as ApiError).kind).assertEqual(ApiErrorKind.Forbidden);
      });
    });

    it('rejects_cursor_paging_and_honors_cancellation', 0, () => {
      const http = new FakeHttp();
      const repo = new TodoApiRepository(http);
      return repo.assignedIssues(new CursorPageRequest('next')).then(() => {
        expect(false).assertTrue();
      }).catch((error: ESObject) => {
        expect((error as ApiError).kind).assertEqual(ApiErrorKind.Parse);
        return repo.assignedIssues(new OffsetPageRequest(), new CanceledSignal());
      }).then(() => {
        expect(false).assertTrue();
      }).catch((error: ESObject) => {
        expect((error as ApiError).kind).assertEqual(ApiErrorKind.Canceled);
        expect(http.requestedUrls.length).assertEqual(0);
      });
    });
  });
}

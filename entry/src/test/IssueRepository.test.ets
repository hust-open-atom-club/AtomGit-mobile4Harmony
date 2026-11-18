import { describe, it, expect } from '@ohos/hypium';

import { ApiError, ApiErrorKind } from '../main/ets/common/ApiError';
import { CancellationSignal } from '../main/ets/common/Cancellation';
import { OffsetPageRequest } from '../main/ets/common/Pager';
import { HttpResult } from '../main/ets/network/HttpClient';
import { HttpPort } from '../main/ets/network/HttpPort';
import { HttpMethod } from '../main/ets/network/NetworkPolicy';
import { RequestSpec } from '../main/ets/network/RequestSpec';
import { RepositoryItemRef } from '../main/ets/model/CollaborationEntities';
import { IssueApiRepository } from '../main/ets/repository/IssueRepository';

class RecordingHttp implements HttpPort {
  responses: HttpResult[] = [];
  errors: ApiError[] = [];
  requests: RequestSpec[] = [];

  async request(spec: RequestSpec, cancel?: CancellationSignal): Promise<HttpResult> {
    this.requests.push(spec);
    if (cancel !== undefined && cancel.isCanceled()) {
      throw new ApiError(ApiErrorKind.Canceled, 0, 0, 'canceled', '', spec.path);
    }
    if (this.errors.length > 0) {
      throw this.errors.shift() as ApiError;
    }
    const response = this.responses.shift();
    if (response === undefined) {
      throw new Error('missing fake response');
    }
    return response;
  }
}

function response(body: string, status: number = 200): HttpResult {
  return new HttpResult(body, status, undefined, false);
}

function issueJson(): string {
  return '{"id":7,"number":"7","title":"Fix issue detail",' +
    '"body":"Line one\\nLine two","state":"open",' +
    '"html_url":"https://atomgit.com/owner/repo/issues/7",' +
    '"created_at":"2026-11-01T08:00:00Z","updated_at":"2026-11-02T09:30:00Z",' +
    '"user":{"id":1,"login":"alice","name":"Alice"},' +
    '"labels":[{"id":1,"name":"bug"},{"id":2,"name":"priority"}]}';
}

function commentsJson(): string {
  return '[{"id":11,"body":"First comment",' +
    '"html_url":"https://atomgit.com/owner/repo/issues/7#comment-11",' +
    '"created_at":"2026-11-01T09:00:00Z","user":{"login":"bob"},' +
    '"comment_type":"pr_comment","discussion_id":"discussion-1",' +
    '"parent_id":"10","resolved":true},' +
    '{"id":"12","body":"","created_at":"2026-11-01T10:00:00Z",' +
    '"user":{"login":"carol"}}]';
}

export default function issueRepositoryTest() {
  describe('IssueRepository', () => {
    it('maps_issue_detail_and_stable_ref', 0, () => {
      const http = new RecordingHttp();
      http.responses.push(response(issueJson()));
      const ref = new RepositoryItemRef('owner', 'repo', 7);
      const repository = new IssueApiRepository(http);
      return repository.issue(ref).then((issue) => {
        expect(issue.ref.key()).assertEqual('owner/repo#7');
        expect(issue.title).assertEqual('Fix issue detail');
        expect(issue.body).assertEqual('Line one\nLine two');
        expect(issue.state).assertEqual('open');
        expect(issue.author).assertEqual('alice');
        expect(issue.createdAt).assertEqual('2026-11-01T08:00:00Z');
        expect(issue.updatedAt).assertEqual('2026-11-02T09:30:00Z');
        expect(issue.htmlUrl).assertEqual('https://atomgit.com/owner/repo/issues/7');
        expect(issue.labels.length).assertEqual(2);
        expect(issue.labels[1]).assertEqual('priority');
        const spec = http.requests[0];
        expect(spec.method).assertEqual(HttpMethod.GET);
        expect(spec.path).assertEqual('/repos/owner/repo/issues/7');
        expect(spec.query.length).assertEqual(0);
        expect(spec.withAuth).assertTrue();
      });
    });

    it('maps_empty_issue_body_and_omitted_labels', 0, () => {
      const http = new RecordingHttp();
      http.responses.push(response('{"title":"Empty body","body":"","state":"closed",' +
        '"html_url":"https://atomgit.com/owner/repo/issues/8",' +
        '"created_at":"2026-11-01T08:00:00Z","updated_at":"2026-11-01T08:00:00Z",' +
        '"user":{"login":"alice"}}'));
      const repository = new IssueApiRepository(http);
      return repository.issue(new RepositoryItemRef('owner', 'repo', 8)).then((issue) => {
        expect(issue.body).assertEqual('');
        expect(issue.labels.length).assertEqual(0);
        expect(issue.state).assertEqual('closed');
      });
    });

    it('rejects_malformed_issue_payload', 0, () => {
      const http = new RecordingHttp();
      http.responses.push(response('{"title":"Missing fields"}'));
      const repository = new IssueApiRepository(http);
      return repository.issue(new RepositoryItemRef('owner', 'repo', 7)).then(() => {
        expect(false).assertTrue();
      }).catch((err: ESObject) => {
        expect(err instanceof ApiError).assertTrue();
        expect((err as ApiError).kind).assertEqual(ApiErrorKind.Parse);
      });
    });

    it('preserves_issue_api_errors', 0, () => {
      const http = new RecordingHttp();
      http.errors.push(new ApiError(ApiErrorKind.Forbidden, 403, 403,
        'forbidden', 'trace', '/issues/7'));
      const repository = new IssueApiRepository(http);
      return repository.issue(new RepositoryItemRef('owner', 'repo', 7)).then(() => {
        expect(false).assertTrue();
      }).catch((err: ESObject) => {
        expect((err as ApiError).kind).assertEqual(ApiErrorKind.Forbidden);
      });
    });

    it('maps_comment_page_and_advances_offset', 0, () => {
      const http = new RecordingHttp();
      http.responses.push(response(commentsJson()));
      const repository = new IssueApiRepository(http);
      const request = new OffsetPageRequest(2, 2);
      return repository.issueComments(new RepositoryItemRef('owner', 'repo', 7), request)
        .then((page) => {
          expect(page.items.length).assertEqual(2);
          expect(page.items[0].id).assertEqual('11');
          expect(page.items[0].author).assertEqual('bob');
          expect(page.items[0].commentType).assertEqual('pr_comment');
          expect(page.items[0].discussionId).assertEqual('discussion-1');
          expect(page.items[0].parentId).assertEqual('10');
          expect(page.items[0].resolved).assertTrue();
          expect(page.items[1].id).assertEqual('12');
          expect(page.items[1].body).assertEqual('');
          expect(page.hasMore).assertTrue();
          expect(page.nextRequest instanceof OffsetPageRequest).assertTrue();
          expect((page.nextRequest as OffsetPageRequest).page).assertEqual(3);
          const spec = http.requests[0];
          expect(spec.path).assertEqual('/repos/owner/repo/issues/7/comments');
          expect(spec.query[0]).assertEqual('page=2');
          expect(spec.query[1]).assertEqual('per_page=2');
        });
    });

    it('maps_empty_and_last_comment_pages', 0, () => {
      const http = new RecordingHttp();
      http.responses.push(response('[]'));
      http.responses.push(response('[{"id":1,"body":"Only","created_at":"2026-11-01T09:00:00Z",' +
        '"user":{"login":"bob"}}]'));
      const repository = new IssueApiRepository(http);
      return repository.issueComments(new RepositoryItemRef('owner', 'repo', 7),
        new OffsetPageRequest(1, 20)).then((emptyPage) => {
        expect(emptyPage.items.length).assertEqual(0);
        expect(emptyPage.hasMore).assertFalse();
        expect(emptyPage.nextRequest).assertEqual(undefined);
        return repository.issueComments(new RepositoryItemRef('owner', 'repo', 7),
          new OffsetPageRequest(2, 2));
      }).then((lastPage) => {
        expect(lastPage.items.length).assertEqual(1);
        expect(lastPage.hasMore).assertFalse();
        expect(lastPage.nextRequest).assertEqual(undefined);
      });
    });

    it('preserves_duplicate_comment_entries_for_store_deduplication', 0, () => {
      const http = new RecordingHttp();
      http.responses.push(response('[{"id":5,"body":"Same","created_at":"2026-11-01T09:00:00Z",' +
        '"user":{"login":"bob"}},{"id":5,"body":"Same","created_at":"2026-11-01T09:00:00Z",' +
        '"user":{"login":"bob"}}]'));
      const repository = new IssueApiRepository(http);
      return repository.issueComments(new RepositoryItemRef('owner', 'repo', 7),
        new OffsetPageRequest(1, 2)).then((page) => {
        expect(page.items.length).assertEqual(2);
      });
    });

    it('rejects_malformed_comment_payloads', 0, () => {
      const http = new RecordingHttp();
      http.responses.push(response('{}'));
      http.responses.push(response('[null]'));
      const repository = new IssueApiRepository(http);
      return repository.issueComments(new RepositoryItemRef('owner', 'repo', 7),
        new OffsetPageRequest()).then(() => {
        expect(false).assertTrue();
      }).catch((err: ESObject) => {
        expect((err as ApiError).kind).assertEqual(ApiErrorKind.Parse);
        return repository.issueComments(new RepositoryItemRef('owner', 'repo', 7),
          new OffsetPageRequest());
      }).then(() => {
        expect(false).assertTrue();
      }).catch((err: ESObject) => {
        expect((err as ApiError).kind).assertEqual(ApiErrorKind.Parse);
      });
    });

    it('encodes_comment_body_and_accepts_created_response', 0, () => {
      const http = new RecordingHttp();
      http.responses.push(response('{"id":180041703}', 201));
      const repository = new IssueApiRepository(http);
      const body = 'Line one\nLine "two"';
      return repository.addIssueComment(new RepositoryItemRef('owner', 'repo', 7), body)
        .then((createdId: string) => {
          expect(createdId).assertEqual('180041703');
          const spec = http.requests[0];
          expect(spec.method).assertEqual(HttpMethod.POST);
          expect(spec.path).assertEqual('/repos/owner/repo/issues/7/comments');
          expect(spec.body).assertEqual('{"body":"Line one\\nLine \\"two\\""}');
          expect(spec.withAuth).assertTrue();
        });
    });

    it('accepts_no_content_comment_response', 0, () => {
      const http = new RecordingHttp();
      http.responses.push(response('', 204));
      const repository = new IssueApiRepository(http);
      return repository.addIssueComment(new RepositoryItemRef('owner', 'repo', 7), 'Looks good')
        .then((createdId: string) => {
          expect(createdId).assertEqual('');
          expect(http.requests.length).assertEqual(1);
        });
    });

    it('rejects_empty_comment_without_request', 0, () => {
      const http = new RecordingHttp();
      const repository = new IssueApiRepository(http);
      return repository.addIssueComment(new RepositoryItemRef('owner', 'repo', 7), '   ')
        .then(() => {
          expect(false).assertTrue();
        }).catch((err: ESObject) => {
          expect((err as ApiError).kind).assertEqual(ApiErrorKind.Unprocessable);
          expect(http.requests.length).assertEqual(0);
        });
    });

    it('preserves_comment_api_errors_and_unexpected_success_status', 0, () => {
      const http = new RecordingHttp();
      http.errors.push(new ApiError(ApiErrorKind.Unprocessable, 422, 422,
        'invalid comment', 'trace', '/comments'));
      http.responses.push(response('{}', 202));
      const repository = new IssueApiRepository(http);
      return repository.addIssueComment(new RepositoryItemRef('owner', 'repo', 7), 'Body')
        .then(() => {
          expect(false).assertTrue();
        }).catch((err: ESObject) => {
          expect((err as ApiError).kind).assertEqual(ApiErrorKind.Unprocessable);
          return repository.addIssueComment(new RepositoryItemRef('owner', 'repo', 7), 'Body');
        }).then(() => {
          expect(false).assertTrue();
        }).catch((err: ESObject) => {
          expect((err as ApiError).kind).assertEqual(ApiErrorKind.Unknown);
        });
    });

    it('preserves_cancellation', 0, () => {
      const http = new RecordingHttp();
      http.errors.push(new ApiError(ApiErrorKind.Canceled, 0, 0, 'canceled', '', '/issues/7'));
      const repository = new IssueApiRepository(http);
      return repository.issue(new RepositoryItemRef('owner', 'repo', 7)).then(() => {
        expect(false).assertTrue();
      }).catch((err: ESObject) => {
        expect((err as ApiError).kind).assertEqual(ApiErrorKind.Canceled);
      });
    });
  });
}

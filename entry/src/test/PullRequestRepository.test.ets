import { describe, it, expect } from '@ohos/hypium';

import { ApiError, ApiErrorKind } from '../main/ets/common/ApiError';
import { CancellationSignal } from '../main/ets/common/Cancellation';
import { OffsetPageRequest } from '../main/ets/common/Pager';
import {
  PullRequestDetail,
  PullRequestFile,
  RepositoryItemRef
} from '../main/ets/model/CollaborationEntities';
import { HttpResult } from '../main/ets/network/HttpClient';
import { HttpPort } from '../main/ets/network/HttpPort';
import { HttpMethod } from '../main/ets/network/NetworkPolicy';
import { RequestSpec } from '../main/ets/network/RequestSpec';
import {
  ApprovePullRequestOptions,
  PullRequestFilesOptions
} from '../main/ets/repository/Ports';
import {
  PR_HEAD_MISMATCH_MESSAGE,
  PullRequestApiRepository,
  PullRequestHeadMismatchError
} from '../main/ets/repository/PullRequestRepository';

class RecordedRequest {
  readonly method: HttpMethod;
  readonly path: string;
  readonly query: string[];
  readonly body: string | undefined;

  constructor(spec: RequestSpec) {
    this.method = spec.method;
    this.path = spec.path;
    this.query = spec.query.slice();
    this.body = spec.body;
  }
}

class HttpStep {
  readonly body: string;
  readonly error: ApiError | undefined;

  constructor(body: string = '{}', error?: ApiError) {
    this.body = body;
    this.error = error;
  }
}

class SequenceHttp implements HttpPort {
  readonly steps: HttpStep[] = [];
  readonly requests: RecordedRequest[] = [];
  private cursor: number = 0;

  respond(body: string): SequenceHttp {
    this.steps.push(new HttpStep(body));
    return this;
  }

  fail(error: ApiError): SequenceHttp {
    this.steps.push(new HttpStep('{}', error));
    return this;
  }

  async request(spec: RequestSpec, cancel?: CancellationSignal): Promise<HttpResult> {
    this.requests.push(new RecordedRequest(spec));
    const step = this.steps[this.cursor];
    this.cursor++;
    if (step === undefined) {
      throw new ApiError(ApiErrorKind.Unknown, 0, 0, 'unexpected request', '', spec.path);
    }
    if (step.error !== undefined) {
      throw step.error;
    }
    return new HttpResult(step.body, 200, undefined, false);
  }
}

const REF: RepositoryItemRef = new RepositoryItemRef('owner', 'repo', 42);

export default function pullRequestRepositoryTest() {
  describe('PullRequestRepository', () => {
    it('maps_pull_request_detail_and_uses_verified_endpoint', 0, () => {
      const http = new SequenceHttp();
      http.respond('{"number":42,"title":"Review module","body":"Details",' +
        '"state":"open","html_url":"https://atomgit.com/owner/repo/pulls/42",' +
        '"updated_at":"2026-11-18T09:00:00Z","user":{"login":"author"},' +
        '"merged":false,"merged_at":"","mergeable":true,' +
        '"head":{"ref":"feature","sha":"head-a"},"base":{"ref":"main","sha":"base-a"},' +
        '"approval_reviewers":[{"login":"alice","name":"Alice","accept_status":"true"}]}');
      const repository = new PullRequestApiRepository(http, 'alice');
      return repository.pullRequest(REF).then((detail: PullRequestDetail) => {
        expect(http.requests[0].method).assertEqual(HttpMethod.GET);
        expect(http.requests[0].path).assertEqual('/repos/owner/repo/pulls/42');
        expect(detail.title).assertEqual('Review module');
        expect(detail.body).assertEqual('Details');
        expect(detail.state).assertEqual('open');
        expect(detail.headSha).assertEqual('head-a');
        expect(detail.baseSha).assertEqual('base-a');
        expect(detail.author).assertEqual('author');
        expect(detail.mergeable).assertTrue();
        expect(detail.approvalReviewers[0].acceptStatus).assertEqual('true');
      });
    });

    it('maps_comment_pages_including_nested_replies', 0, () => {
      const http = new SequenceHttp();
      http.respond('[{"id":1,"discussion_id":"d1","body":"Top","created_at":"2026-11-18T08:00:00Z",' +
        '"user":{"login":"bob"},"comment_type":"pr_comment","resolved":false,' +
        '"reply":[{"id":2,"body":"Reply","created_at":"2026-11-18T08:01:00Z","user":{"login":"alice"}}]},' +
        '{"id":3,"body":"Second","created_at":"2026-11-18T08:02:00Z","user":{"login":"carol"},' +
        '"comment_type":"diff_comment","resolved":true}]');
      const repository = new PullRequestApiRepository(http, 'alice');
      return repository.pullRequestComments(REF, new OffsetPageRequest(2, 2), 'pr_comment')
        .then((page) => {
          expect(http.requests[0].path).assertEqual('/repos/owner/repo/pulls/42/comments');
          expect(http.requests[0].query.indexOf('page=2') >= 0).assertTrue();
          expect(http.requests[0].query.indexOf('per_page=2') >= 0).assertTrue();
          expect(http.requests[0].query.indexOf('comment_type=pr_comment') >= 0).assertTrue();
          expect(page.items.length).assertEqual(3);
          expect(page.items[1].parentId).assertEqual('1');
          expect(page.items[1].author).assertEqual('alice');
          expect(page.items[2].resolved).assertTrue();
          expect(page.hasMore).assertTrue();
        });
    });

    it('posts_only_body_for_a_regular_comment', 0, () => {
      const http = new SequenceHttp();
      http.respond('{"id":"c1","body":"Looks good"}');
      const repository = new PullRequestApiRepository(http, 'alice');
      return repository.addPullRequestComment(REF, 'Looks good').then(() => {
        expect(http.requests[0].method).assertEqual(HttpMethod.POST);
        expect(http.requests[0].path).assertEqual('/repos/owner/repo/pulls/42/comments');
        expect(http.requests[0].body).assertEqual('{"body":"Looks good"}');
      });
    });

    it('maps_file_states_and_enforces_max_files', 0, () => {
      const http = new SequenceHttp();
      http.respond('[{"sha":"a","filename":"src/a.ts","status":"modified","additions":3,"deletions":1,' +
        '"patch":{"diff":"@@ -1 +1 @@\\n-old\\n+new","old_path":"src/a.ts","new_path":"src/a.ts"}},' +
        '{"sha":"b","filename":"empty.txt","status":"modified","additions":0,"deletions":0},' +
        '{"sha":"c","filename":"logo.png","status":"binary","additions":0,"deletions":0},' +
        '{"sha":"d","filename":"new.go","status":"renamed","additions":0,"deletions":0,' +
        '"patch":{"old_path":"old.go","new_path":"new.go","renamed_file":true,' +
        '"added_lines":5,"removed_lines":3}},' +
        '{"sha":"e","filename":"large.bin","status":"added","too_large":true},' +
        '{"sha":"f","filename":"ignored.txt","status":"added"}]');
      const repository = new PullRequestApiRepository(http, 'alice');
      return repository.pullRequestFiles(REF, new PullRequestFilesOptions(5, 1000))
        .then((files: PullRequestFile[]) => {
          expect(files.length).assertEqual(5);
          expect(files[0].patch).assertEqual('@@ -1 +1 @@\n-old\n+new');
          expect(files[1].patch === undefined).assertTrue();
          expect(files[2].status).assertEqual('binary');
          expect(files[3].status).assertEqual('renamed');
          expect(files[3].oldPath).assertEqual('old.go');
          expect(files[3].additions).assertEqual(5);
          expect(files[3].deletions).assertEqual(3);
          expect(files[4].status).assertEqual('too_large');
          expect(files[4].tooLarge).assertTrue();
        });
    });

    it('clips_patch_to_max_patch_chars', 0, () => {
      const http = new SequenceHttp();
      http.respond('[{"filename":"a.ts","status":"modified","patch":{"diff":"@@ -1 +1 @@\\n-old-line\\n+new-line"}}]');
      const repository = new PullRequestApiRepository(http, 'alice');
      return repository.pullRequestFiles(REF, new PullRequestFilesOptions(1, 10)).then((files) => {
        expect(files[0].patch === undefined ? '' : files[0].patch).assertEqual('@@ -1 +1 @');
        expect(files[0].truncated).assertTrue();
      });
    });

    it('drops_non_unified_patch_text_instead_of_faking_diff', 0, () => {
      const http = new SequenceHttp();
      http.respond('[{"filename":"a.ts","status":"modified","patch":{"diff":"plain text, not a diff"}}]');
      const repository = new PullRequestApiRepository(http, 'alice');
      return repository.pullRequestFiles(REF).then((files) => {
        expect(files[0].patch === undefined).assertTrue();
      });
    });

    it('approves_verified_head_payload_and_confirms_readback', 0, () => {
      const http = new SequenceHttp();
      http.respond('{"title":"PR","state":"open","head":{"sha":"head-a"},' +
        '"approval_reviewers":[{"login":"alice","accept_status":"optional"}]}');
      http.respond('{}');
      http.respond('{"login":"alice","name":"Alice"}');
      http.respond('{"title":"PR","state":"open","head":{"sha":"head-a"},' +
        '"approval_reviewers":[{"login":"alice","accept_status":"true"}]}');
      const repository = new PullRequestApiRepository(http);
      return repository.approvePullRequest(REF,
        new ApprovePullRequestOptions(false, 'head-a')).then(() => {
        expect(http.requests.length).assertEqual(4);
        expect(http.requests[0].method).assertEqual(HttpMethod.GET);
        expect(http.requests[1].method).assertEqual(HttpMethod.POST);
        expect(http.requests[1].path).assertEqual('/repos/owner/repo/pulls/42/review');
        expect(http.requests[1].body).assertEqual('{"force":false}');
        expect(http.requests[2].path).assertEqual('/user');
        expect(http.requests[3].path).assertEqual('/repos/owner/repo/pulls/42');
      });
    });

    it('rejects_expected_head_mismatch_before_write', 0, () => {
      const http = new SequenceHttp();
      http.respond('{"title":"PR","state":"open","head":{"sha":"head-b"}}');
      const repository = new PullRequestApiRepository(http, 'alice');
      return repository.approvePullRequest(REF,
        new ApprovePullRequestOptions(false, 'head-a')).then(() => {
        expect(false).assertTrue();
      }).catch((err: ESObject) => {
        expect(err instanceof PullRequestHeadMismatchError).assertTrue();
        expect((err as PullRequestHeadMismatchError).message).assertEqual(PR_HEAD_MISMATCH_MESSAGE);
        expect(http.requests.length).assertEqual(1);
        expect(http.requests[0].method).assertEqual(HttpMethod.GET);
      });
    });

    it('propagates_approval_write_api_error_unchanged', 0, () => {
      const http = new SequenceHttp();
      http.respond('{"title":"PR","state":"open","head":{"sha":"head-a"}}');
      const writeError = new ApiError(ApiErrorKind.Forbidden, 403, 403,
        'forbidden', 'trace-1', '/review');
      http.fail(writeError);
      const repository = new PullRequestApiRepository(http, 'alice');
      return repository.approvePullRequest(REF,
        new ApprovePullRequestOptions(false, 'head-a')).then(() => {
        expect(false).assertTrue();
      }).catch((err: ESObject) => {
        expect(err === writeError).assertTrue();
        expect((err as ApiError).kind).assertEqual(ApiErrorKind.Forbidden);
      });
    });

    it('fails_when_approval_readback_does_not_confirm_current_user', 0, () => {
      const http = new SequenceHttp();
      http.respond('{"title":"PR","state":"open","head":{"sha":"head-a"}}');
      http.respond('{}');
      http.respond('{"login":"alice"}');
      http.respond('{"title":"PR","state":"open","head":{"sha":"head-a"},' +
        '"approval_reviewers":[{"login":"alice","accept_status":"optional"}]}');
      const repository = new PullRequestApiRepository(http);
      return repository.approvePullRequest(REF,
        new ApprovePullRequestOptions(false, 'head-a')).then(() => {
        expect(false).assertTrue();
      }).catch((err: ESObject) => {
        expect(err instanceof ApiError).assertTrue();
        expect((err as ApiError).kind).assertEqual(ApiErrorKind.Conflict);
      });
    });
  });
}

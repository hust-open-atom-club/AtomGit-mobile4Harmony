import { describe, it, expect } from '@ohos/hypium';

import { ApiError, ApiErrorKind } from '../main/ets/common/ApiError';
import { OffsetPageRequest } from '../main/ets/common/Pager';
import { CheckStatus } from '../main/ets/model/Entities';
import { AtomGitRepository } from '../main/ets/repository/AtomGitRepository';
import { FakeHttp } from './fakes/FakeHttp';

export default function repositoryTest() {
  describe('AtomGitRepositoryParsingContract', () => {
    it('currentUser_maps_object_payload', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/user',
        '{"id":"u1","login":"alice","name":"Alice"}');
      const repo = new AtomGitRepository(http);
      return repo.currentUser().then((u) => {
        expect(u.accountId).assertEqual('u1');
        expect(u.login).assertEqual('alice');
        expect(u.displayName()).assertEqual('Alice');
      });
    });

    it('myRepos_maps_bare_array_and_paginates', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/user/repos',
        '[{"id":1,"full_name":"a/b","name":"b","namespace":{"path":"a"}}]');
      const repo = new AtomGitRepository(http);
      return repo.myRepos(new OffsetPageRequest(1, 20)).then((page) => {
        expect(page.items.length).assertEqual(1);
        expect(page.items[0].owner).assertEqual('a');
        expect(page.items[0].name).assertEqual('b');
        expect(page.hasMore).assertTrue();
        expect(page.nextRequest instanceof OffsetPageRequest).assertTrue();
      });
    });

    it('myRepos_flags_hasMore_on_full_page', 0, () => {
      const one = '{"id":1,"full_name":"a/b","name":"b"}';
      const http = new FakeHttp();
      http.onJson('/api/v5/user/repos', '[' + one + ',' + one + ',' + one + ']');
      const repo = new AtomGitRepository(http);
      return repo.myRepos(new OffsetPageRequest(1, 3)).then((page) => {
        expect(page.hasMore).assertTrue();
        expect(page.nextRequest instanceof OffsetPageRequest).assertTrue();
        expect((page.nextRequest as OffsetPageRequest).page).assertEqual(2);
      });
    });

    it('listDir_maps_directory_array', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/repos/o/r/contents/common',
        '[{"type":"dir","name":"src","path":"common/src"}]');
      const repo = new AtomGitRepository(http);
      return repo.listDir('o', 'r', 'common').then((entries) => {
        expect(entries.length).assertEqual(1);
        expect(entries[0].isDir()).assertTrue();
        expect(entries[0].path).assertEqual('common/src');
      });
    });

    it('fileContent_decodes_base64_text', 0, () => {
      // 'Hello' 的 base64
      const http = new FakeHttp();
      http.onJson('/api/v5/repos/o/r/contents/README.md',
        '{"type":"file","encoding":"base64","size":5,"name":"README.md",' + '"path":"README.md","content":"SGVsbG8="}');
      const repo = new AtomGitRepository(http);
      return repo.fileContent('o', 'r', 'README.md').then((file) => {
        expect(file.decodable).assertTrue();
        expect(file.text).assertEqual('Hello');
        expect(file.size).assertEqual(5);
      });
    });

    it('fileContent_marks_binary_as_not_decodable', 0, () => {
      // 大量 NUL 字节视为二进制
      const http = new FakeHttp();
      http.onJson('/api/v5/repos/o/r/contents/a.png',
        '{"type":"file","encoding":"base64","size":9,"name":"a.png",' + '"path":"a.png","content":"AAAAAAAAAAAA"}');
      const repo = new AtomGitRepository(http);
      return repo.fileContent('o', 'r', 'a.png').then((file) => {
        expect(file.decodable).assertFalse();
        expect(file.text).assertEqual('');
      });
    });

    it('checkRuns_unwraps_total_count_envelope', 0, () => {
      // { total_count, workflow_runs } 包裹
      const http = new FakeHttp();
      http.onJson('/api/v8/repos/o/r/actions/runs',
        '{"total_count":2,"workflow_runs":[' +
        '{"workflow_run_id":"run-a","id":7,"status":"COMPLETED","title":"build",' +
        '"workflow_name":"build","head_branch":"main","start_time":"2026-01-01T00:00:00Z"},' +
        '{"workflow_run_id":"run-b","id":7,"status":"COMPLETED","title":"test",' +
        '"workflow_name":"test","head_branch":"main","start_time":"2026-01-02T00:00:00Z"}]}');
      const repo = new AtomGitRepository(http);
      return repo.checkRuns('o', 'r', 'master', new OffsetPageRequest(1, 20)).then((page) => {
        expect(page.items.length).assertEqual(2);
        expect(page.items[0].id).assertEqual('run-a');
        expect(page.items[1].id).assertEqual('run-b');
        expect(page.items[0].id === page.items[1].id).assertFalse();
        expect(page.items[0].name).assertEqual('build');
        expect(page.items[0].status).assertEqual(CheckStatus.Success);
        expect(page.items[0].createdAt).assertEqual('2026-01-01T00:00:00Z');
      });
    });

    it('checkRuns_tolerates_empty_envelope', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v8/repos/o/r/actions/runs', '{"total_count":0,"workflow_runs":[]}');
      const repo = new AtomGitRepository(http);
      return repo.checkRuns('o', 'r', undefined, new OffsetPageRequest(1, 20)).then((page) => {
        expect(page.items.length).assertEqual(0);
      });
    });

    it('rejects_unexpected_shape_instead_of_silent_empty', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/user/repos', '{"message":"not an array"}');
      const repo = new AtomGitRepository(http);
      return repo.myRepos(new OffsetPageRequest(1, 20)).then(() => {
        expect(false).assertTrue();
      }).catch((err: ESObject) => {
        expect(err instanceof ApiError).assertTrue();
        expect((err as ApiError).kind).assertEqual(ApiErrorKind.Parse);
      });
    });

    it('rejects_malformed_json_as_parse_error', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/user', '{not json');
      const repo = new AtomGitRepository(http);
      return repo.currentUser().then(() => {
        expect(false).assertTrue();
      }).catch((err: ESObject) => {
        expect((err as ApiError).kind).assertEqual(ApiErrorKind.Parse);
      });
    });

    it('propagates_api_error_unchanged', 0, () => {
      const http = new FakeHttp();
      http.onError('/api/v5/user',
        new ApiError(ApiErrorKind.Unauthorized, 401, 401, 'nope', 'tr', '/user'));
      const repo = new AtomGitRepository(http);
      return repo.currentUser().then(() => {
        expect(false).assertTrue();
      }).catch((err: ESObject) => {
        const e = err as ApiError;
        expect(e.kind).assertEqual(ApiErrorKind.Unauthorized);
        expect(e.requiresReLogin()).assertTrue();
      });
    });

    it('sends_bearer_token_on_api_calls', 0, () => {
      const http = new FakeHttp();
      http.token = 'SECRET-TOKEN';
      http.onJson('/api/v5/user', '{"id":"u","login":"a"}');
      const repo = new AtomGitRepository(http);
      return repo.currentUser().then(() => {
        expect(http.lastHeaders.get('Authorization')).assertEqual('Bearer SECRET-TOKEN');
      });
    });

    it('clamps_page_and_per_page', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/user/repos', '[]');
      const repo = new AtomGitRepository(http);
      return repo.myRepos(new OffsetPageRequest(0, 9999)).then(() => {
        const url = http.requestedUrls[http.requestedUrls.length - 1];
        expect(url.indexOf('page=1') >= 0).assertTrue();
        expect(url.indexOf('per_page=100') >= 0).assertTrue();
      });
    });

    it('escapes_path_segments', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/repos/a%20b/c%2Fd/contents/x', '[]');
      const repo = new AtomGitRepository(http);
      return repo.listDir('a b', 'c/d', 'x').then(() => {
        const url = http.requestedUrls[http.requestedUrls.length - 1];
        expect(url.indexOf('a%20b') >= 0).assertTrue();
        expect(url.indexOf('c%2Fd') >= 0).assertTrue();
      });
    });
  });
}

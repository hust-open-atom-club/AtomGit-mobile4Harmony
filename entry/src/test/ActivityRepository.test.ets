import { describe, it, expect } from '@ohos/hypium';

import { ApiError, ApiErrorKind } from '../main/ets/common/ApiError';
import { CursorPageRequest, OffsetPageRequest } from '../main/ets/common/Pager';
import { RepositoryItemKind } from '../main/ets/model/CollaborationEntities';
import { ActivityApiRepository } from '../main/ets/repository/ActivityRepository';
import { FakeHttp } from './fakes/FakeHttp';

export default function activityRepositoryTest() {
  describe('ActivityRepository', () => {
    it('maps_personal_date_buckets_and_cursor', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/users/alice/events', '{"events":{"2026-11-04":[' +
        '{"action":6,"action_name":"commented on",' +
        '"author":{"id":1,"username":"alice","name":"Alice","avatar_url":"https://cdn.example/a.jpg"},' +
        '"author_username":"alice","created_at":"2026-11-04T09:19:27.519Z",' +
        '"project_name":"owner/repo","target_iid":198263492,' +
        '"target_title":"Stabilize activity feed","target_type":"Note",' +
        '"target_type_format":"note","note":{"id":198263492,"noteable_iid":349,' +
        '"noteable_type":"MergeRequest","body":"Looks good"},' +
        '"_links":{"project":"https://atomgit.com/owner/repo",' +
        '"action_type":"https://atomgit.com/owner/repo/merge_requests/349#note_198263492"}}]},' +
        '"next":"2026-11-01T00:00:00.000Z"}');
      const repo = new ActivityApiRepository(http);
      return repo.personalActivity('alice', 2026, new CursorPageRequest()).then((page) => {
        expect(page.items.length).assertEqual(1);
        expect(page.items[0].actor).assertEqual('alice');
        expect(page.items[0].title).assertEqual('Stabilize activity feed');
        expect(page.items[0].kind).assertEqual('pull_request');
        expect(page.items[0].target?.number).assertEqual(349);
        expect(page.items[0].targetKind).assertEqual(RepositoryItemKind.PullRequest);
        expect(page.nextRequest instanceof CursorPageRequest).assertTrue();
        const next = page.nextRequest as CursorPageRequest;
        expect(next.cursor).assertEqual('2026-11-01T00:00:00.000Z');
        const url = http.requestedUrls[http.requestedUrls.length - 1];
        expect(url.indexOf('year=2026') >= 0).assertTrue();
      });
    });

    it('maps_repository_array_and_boolean_has_next_page', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/repos/owner/repo/events', '{"events":[' +
        '{"action":22,"action_name":"opened","author":{"username":"bob"},' +
        '"created_at":"2026-11-04T08:00:00Z","project_name":"owner/repo",' +
        '"target_iid":12,"target_title":"Fix permissions","target_type":"Issue"},' +
        '{"action":5,"action_name":"pushed to","author_username":"bob",' +
        '"created_at":"2026-11-04T07:00:00Z","project_name":"owner/repo",' +
        '"push_data":{"commit_title":"Update docs","commit_to":"abc123"}}],' +
        '"has_next_page":true}');
      const repo = new ActivityApiRepository(http);
      return repo.repositoryActivity('owner', 'repo', new OffsetPageRequest(1, 20)).then((page) => {
        expect(page.items.length).assertEqual(2);
        expect(page.items[0].target?.number).assertEqual(12);
        expect(page.items[0].targetKind).assertEqual(RepositoryItemKind.Issue);
        expect(page.items[1].kind).assertEqual('push');
        expect(page.items[1].title).assertEqual('Update docs');
        expect(page.hasMore).assertTrue();
        expect(page.nextRequest instanceof OffsetPageRequest).assertTrue();
        expect((page.nextRequest as OffsetPageRequest).page).assertEqual(2);
        const url = http.requestedUrls[http.requestedUrls.length - 1];
        expect(url.indexOf('page=1') >= 0).assertTrue();
        expect(url.indexOf('per_page=20') >= 0).assertTrue();
      });
    });

    it('stops_when_server_repeats_cursor', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/users/alice/events',
        '{"events":{"2026-11-04":[{"action":1,"action_name":"opened",' +
        '"author_username":"alice","created_at":"2026-11-04T08:00:00Z",' +
        '"project_name":"owner/repo","target_title":"Item"}]},"next":"same-cursor"}');
      const repo = new ActivityApiRepository(http);
      return repo.personalActivity('alice', 2026, new CursorPageRequest('same-cursor')).then((page) => {
        expect(page.items.length).assertEqual(1);
        expect(page.hasMore).assertFalse();
      });
    });

    it('rejects_malformed_json_as_parse_error', 0, () => {
      const http = new FakeHttp();
      http.onJson('/api/v5/repos/owner/repo/events', '{not-json');
      const repo = new ActivityApiRepository(http);
      return repo.repositoryActivity('owner', 'repo', new OffsetPageRequest()).then(() => {
        expect(false).assertTrue();
      }).catch((err: ESObject) => {
        expect(err instanceof ApiError).assertTrue();
        expect((err as ApiError).kind).assertEqual(ApiErrorKind.Parse);
      });
    });

    it('preserves_api_error', 0, () => {
      const http = new FakeHttp();
      http.onError('/api/v5/repos/owner/private/events',
        new ApiError(ApiErrorKind.Forbidden, 403, 403, 'forbidden', 'trace', '/events'));
      const repo = new ActivityApiRepository(http);
      return repo.repositoryActivity('owner', 'private', new OffsetPageRequest()).then(() => {
        expect(false).assertTrue();
      }).catch((err: ESObject) => {
        expect((err as ApiError).kind).assertEqual(ApiErrorKind.Forbidden);
      });
    });
  });
}

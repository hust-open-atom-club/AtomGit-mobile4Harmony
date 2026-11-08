import { describe, it, expect } from '@ohos/hypium';

import { ApiError, ApiErrorKind } from '../main/ets/common/ApiError';
import {
  CursorPageRequest,
  OffsetPageRequest,
  Page,
  PageRequest
} from '../main/ets/common/Pager';
import { ActivityItem } from '../main/ets/model/CollaborationEntities';
import { RepoSummary } from '../main/ets/model/Entities';
import { ActivityRepository } from '../main/ets/repository/Ports';
import {
  ActivitySource,
  ActivityStore
} from '../main/ets/viewmodel/ActivityStore';
import { LoadState } from '../main/ets/viewmodel/SessionStore';

function item(id: string, createdAt: string, title: string = 'Item'): ActivityItem {
  return new ActivityItem(id, 'issue', title, 'alice', 'owner/repo', createdAt);
}

function project(): RepoSummary {
  return new RepoSummary(1, 'owner', 'repo', 'repo', 'owner/repo', '',
    'https://atomgit.com/owner/repo', 'main', false, false, 0, 0, 0);
}

class FakeActivityRepository implements ActivityRepository {
  personalResults: Array<Page<ActivityItem> | ApiError> = [];
  projectResults: Array<Page<ActivityItem> | ApiError> = [];
  personalRequests: PageRequest[] = [];
  projectRequests: PageRequest[] = [];

  async personalActivity(username: string, year: number, request: PageRequest):
    Promise<Page<ActivityItem>> {
    this.personalRequests.push(request);
    const result = this.personalResults.length > 0
      ? this.personalResults.shift() as Page<ActivityItem> | ApiError
      : Page.empty<ActivityItem>(request);
    if (result instanceof ApiError) {
      throw result;
    }
    return result;
  }

  async repositoryActivity(owner: string, repo: string, request: PageRequest):
    Promise<Page<ActivityItem>> {
    this.projectRequests.push(request);
    const result = this.projectResults.length > 0
      ? this.projectResults.shift() as Page<ActivityItem> | ApiError
      : Page.empty<ActivityItem>(request);
    if (result instanceof ApiError) {
      throw result;
    }
    return result;
  }
}

export default function activityStoreTest() {
  describe('ActivityStore', () => {
    it('loads_personal_feed_and_groups_dates', 0, () => {
      const data = new FakeActivityRepository();
      const request = new CursorPageRequest();
      data.personalResults.push(new Page<ActivityItem>([
        item('1', '2026-11-04T08:00:00Z'),
        item('2', '2026-11-03T08:00:00Z')
      ], request, new CursorPageRequest('next')));
      const store = new ActivityStore(data);
      store.initialize('account', 'alice', [project()]);
      return store.openPersonal().then(() => {
        expect(store.state).assertEqual(LoadState.Ready);
        expect(store.items.length).assertEqual(2);
        expect(store.days.length).assertEqual(2);
        expect(store.hasMore).assertTrue();
        expect(store.source).assertEqual(ActivitySource.Personal);
      });
    });

    it('refreshing_restarts_from_first_cursor_and_keeps_data_on_failure', 0, () => {
      const data = new FakeActivityRepository();
      data.personalResults.push(new Page<ActivityItem>(
        [item('1', '2026-11-04T08:00:00Z')],
        new CursorPageRequest(),
        new CursorPageRequest('next')));
      data.personalResults.push(new ApiError(
        ApiErrorKind.Network, 0, 0, 'offline', '', '/events'));
      const store = new ActivityStore(data);
      store.initialize('account', 'alice', [project()]);
      return store.openPersonal().then(() => store.loadMore()).then(() => {
        expect(store.items.length).assertEqual(1);
        expect(store.errorMessage.length > 0).assertTrue();
        expect(store.state).assertEqual(LoadState.Ready);
        expect(data.personalRequests.length).assertEqual(2);
        const request = data.personalRequests[1] as CursorPageRequest;
        expect(request.cursor).assertEqual('next');
      });
    });

    it('refresh_resets_to_first_page', 0, () => {
      const data = new FakeActivityRepository();
      data.personalResults.push(new Page<ActivityItem>(
        [item('1', '2026-11-04T08:00:00Z')],
        new CursorPageRequest(),
        new CursorPageRequest('next')));
      data.personalResults.push(new Page<ActivityItem>(
        [item('2', '2026-11-05T08:00:00Z')],
        new CursorPageRequest()));
      const store = new ActivityStore(data);
      store.initialize('account', 'alice', [project()]);
      return store.openPersonal().then(() => store.refresh()).then(() => {
        expect(data.personalRequests.length).assertEqual(2);
        const initial = data.personalRequests[0] as CursorPageRequest;
        const refreshed = data.personalRequests[1] as CursorPageRequest;
        expect(initial.cursor).assertEqual(undefined);
        expect(refreshed.cursor).assertEqual(undefined);
        expect(store.items.length).assertEqual(1);
        expect(store.items[0].id).assertEqual('2');
      });
    });

    it('load_more_removes_overlapping_events', 0, () => {
      const data = new FakeActivityRepository();
      data.personalResults.push(new Page<ActivityItem>(
        [item('same', '2026-11-04T08:00:00Z')],
        new CursorPageRequest(),
        new CursorPageRequest('next')));
      data.personalResults.push(new Page<ActivityItem>([
        item('same', '2026-11-04T08:00:00Z'),
        item('older', '2026-11-02T08:00:00Z')
      ], new CursorPageRequest('next')));
      const store = new ActivityStore(data);
      store.initialize('account', 'alice', [project()]);
      return store.openPersonal().then(() => store.loadMore()).then(() => {
        expect(store.items.length).assertEqual(2);
        expect(store.items[0].id).assertEqual('same');
        expect(store.items[1].id).assertEqual('older');
      });
    });

    it('project_feed_has_independent_paging_state', 0, () => {
      const data = new FakeActivityRepository();
      data.personalResults.push(new Page<ActivityItem>(
        [item('personal', '2026-11-04T08:00:00Z')],
        new CursorPageRequest()));
      data.projectResults.push(new Page<ActivityItem>(
        [item('project', '2026-11-03T08:00:00Z')],
        new OffsetPageRequest()));
      const store = new ActivityStore(data);
      store.initialize('account', 'alice', [project()]);
      return store.openPersonal()
        .then(() => store.openProject('owner', 'repo'))
        .then(() => {
          expect(store.source).assertEqual(ActivitySource.Project);
          expect(store.items.length).assertEqual(1);
          expect(store.items[0].id).assertEqual('project');
          return store.openPersonal();
        })
        .then(() => {
          expect(store.items[0].id).assertEqual('personal');
          expect(data.personalRequests.length).assertEqual(1);
          expect(data.projectRequests.length).assertEqual(1);
        });
    });

    it('account_change_clears_previous_feed', 0, () => {
      const data = new FakeActivityRepository();
      data.personalResults.push(new Page<ActivityItem>(
        [item('old', '2026-11-04T08:00:00Z')],
        new CursorPageRequest()));
      const store = new ActivityStore(data);
      store.initialize('account-a', 'alice', [project()]);
      return store.openPersonal().then(() => {
        store.initialize('account-b', 'bob', [project()]);
        expect(store.items.length).assertEqual(0);
        expect(store.days.length).assertEqual(0);
        expect(store.state).assertEqual(LoadState.Idle);
      });
    });
  });
}

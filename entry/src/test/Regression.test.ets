import { describe, it, expect } from '@ohos/hypium';

import { ApiError, ApiErrorKind } from '../main/ets/common/ApiError';
import { Page, PagingState, PagingType } from '../main/ets/common/Pager';
import { WorkflowRunDto } from '../main/ets/model/Dtos';
import { RepoEntry, RepoSummary } from '../main/ets/model/Entities';
import { toCheckRun } from '../main/ets/model/Mappers';
import { toTransportApiError } from '../main/ets/network/HttpClient';
import { AccountGuard } from '../main/ets/security/TokenEnvelope';
import { CacheCleaner } from '../main/ets/storage/StoragePorts';
import { LoadState, SessionStore } from '../main/ets/viewmodel/SessionStore';
import { RepoBrowseStore } from '../main/ets/viewmodel/RepoBrowseStore';
import {
  FakeCacheCleaner,
  FakeCredentialStore,
  FakeRepository,
  FakeSettingsCleaner,
  fakeRepo,
  unauthorized
} from './fakes/Fakes';

class PagedRepository extends FakeRepository {
  async myRepos(page: number, perPage: number): Promise<Page<RepoSummary>> {
    this.requestedPages.push(page);
    await Promise.resolve();
    const items: RepoSummary[] = page === 1
      ? [fakeRepo('o/a'), fakeRepo('o/b')]
      : [fakeRepo('o/c')];
    return new Page<RepoSummary>(items, page < 2, PagingState.first(PagingType.Offset));
  }
}

class DetailFailureRepository extends FakeRepository {
  failDetail: boolean = false;

  async repoDetail(owner: string, repo: string): Promise<RepoSummary> {
    this.calls.push('repoDetail');
    if (this.failDetail) {
      throw unauthorized();
    }
    return fakeRepo(owner + '/' + repo);
  }
}

class GuardAwareCleaner implements CacheCleaner {
  guard: AccountGuard;
  cleared: number = 0;
  seenLoggedIn: boolean = false;

  constructor(guard: AccountGuard) {
    this.guard = guard;
  }

  async clearCurrentAccount(): Promise<void> {
    this.cleared++;
    this.seenLoggedIn = this.guard.isLoggedIn();
  }
}

function makeSession(repo: FakeRepository, cred: FakeCredentialStore,
  cache: CacheCleaner, guard: AccountGuard): SessionStore {
  return new SessionStore(repo, cred, cache, new FakeSettingsCleaner(), guard);
}

export default function regressionTest() {
  describe('Regression', () => {
    it('transport_error_keeps_the_api_error_kind', 0, () => {
      const classified = new ApiError(ApiErrorKind.Unauthorized, 401, 0, 'unauthorized', '', '/user');
      const wrapped = toTransportApiError(classified, 'https://api.atomgit.com/api/v5/user');
      expect(wrapped.kind).assertEqual(ApiErrorKind.Unauthorized);
      expect(wrapped.status).assertEqual(401);
      expect(wrapped.requiresReLogin()).assertTrue();
    });

    it('restore_keeps_the_token_on_a_transient_failure', 0, () => {
      const repo = new FakeRepository();
      repo.userResult = new ApiError(ApiErrorKind.Network, 0, 0, 'offline', '', '/user');
      const cred = new FakeCredentialStore();
      cred.value = 'token-1';
      const session = makeSession(repo, cred, new FakeCacheCleaner(), new AccountGuard());
      return session.restore().then((ok: boolean) => {
        expect(ok).assertFalse();
        expect(cred.value).assertEqual('token-1');
        expect(cred.removedCount).assertEqual(0);
        expect(session.state).assertEqual(LoadState.Error);
        expect(session.needReLogin).assertFalse();
      });
    });

    it('restore_drops_the_token_when_unauthorized', 0, () => {
      const repo = new FakeRepository();
      repo.userResult = unauthorized();
      const cred = new FakeCredentialStore();
      cred.value = 'token-1';
      const session = makeSession(repo, cred, new FakeCacheCleaner(), new AccountGuard());
      return session.restore().then((ok: boolean) => {
        expect(ok).assertFalse();
        expect(cred.value === undefined).assertTrue();
        expect(cred.removedCount).assertEqual(1);
        expect(session.needReLogin).assertTrue();
      });
    });

    it('logout_clears_the_cache_while_the_account_is_set', 0, () => {
      const guard = new AccountGuard();
      guard.setAccount('acc-1');
      const cache = new GuardAwareCleaner(guard);
      const cred = new FakeCredentialStore();
      cred.value = 'token-1';
      const session = makeSession(new FakeRepository(), cred, cache, guard);
      return session.logout().then(() => {
        expect(cache.cleared).assertEqual(1);
        expect(cache.seenLoggedIn).assertTrue();
        expect(guard.isLoggedIn()).assertFalse();
      });
    });

    it('workflow_runs_get_distinct_identities', 0, () => {
      const first: WorkflowRunDto = { workflow_run_id: 'run-a', status: 'COMPLETED', title: 'build' };
      const second: WorkflowRunDto = { workflow_run_id: 'run-b', status: 'COMPLETED', title: 'test' };
      const a = toCheckRun(first);
      const b = toCheckRun(second);
      expect(a.id).assertEqual('run-a');
      expect(b.id).assertEqual('run-b');
      expect(a.id === b.id).assertFalse();
    });

    it('concurrent_page_loads_append_once', 0, () => {
      const repo = new PagedRepository();
      const cred = new FakeCredentialStore();
      cred.value = 'token-1';
      const session = makeSession(repo, cred, new FakeCacheCleaner(), new AccountGuard());
      return session.restore().then(() => {
        expect(session.repos.length).assertEqual(2);
        const first = session.loadRepos();
        const second = session.loadRepos();
        return Promise.all([first, second]);
      }).then(() => {
        expect(repo.requestedPages.length).assertEqual(2);
        expect(session.repos.length).assertEqual(3);
        const seen = new Set<string>();
        session.repos.forEach((r: RepoSummary) => {
          seen.add(r.fullName);
        });
        expect(seen.size).assertEqual(3);
      });
    });

    it('opening_another_repo_clears_the_previous_one', 0, () => {
      const repo = new DetailFailureRepository();
      repo.dirResult = [new RepoEntry('file', 'README.md', 'README.md', 10)];
      const store = new RepoBrowseStore(repo);
      return store.open('o', 'a').then(() => {
        expect(store.repo === undefined).assertFalse();
        repo.failDetail = true;
        return store.open('o', 'b');
      }).then(() => {
        expect(store.repo === undefined).assertTrue();
        expect(store.entries.length).assertEqual(0);
        expect(store.checks.length).assertEqual(0);
        expect(store.errorMessage.length > 0).assertTrue();
      });
    });

    it('successful_navigation_clears_the_previous_error', 0, () => {
      const repo = new FakeRepository();
      repo.dirResult = unauthorized();
      const store = new RepoBrowseStore(repo);
      return store.open('o', 'a').then(() => {
        expect(store.errorMessage.length > 0).assertTrue();
        repo.dirResult = [new RepoEntry('file', 'README.md', 'README.md', 10)];
        return store.enterDir('');
      }).then(() => {
        expect(store.errorMessage).assertEqual('');
        expect(store.state).assertEqual(LoadState.Ready);
      });
    });
  });
}

import { describe, it, expect } from '@ohos/hypium';

import { ApiError } from '../main/ets/common/ApiError';
import { Page, PagingState, PagingType } from '../main/ets/common/Pager';
import {
  CheckRun,
  CheckStatus,
  RepoEntry,
  RepoFileContent,
  RepoSummary
} from '../main/ets/model/Entities';
import { AccountGuard } from '../main/ets/security/TokenEnvelope';
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

function makeSession(): SessionStore {
  return new SessionStore(new FakeRepository(), new FakeCredentialStore(),
    new FakeCacheCleaner(), new FakeSettingsCleaner(), new AccountGuard());
}

export default function viewModelTest() {
  describe('ViewModel', () => {
    it('login_rejects_blank_token_without_network', 0, () => {
      const s = makeSession();
      return s.login('   ').then((ok: boolean) => {
        expect(ok).assertFalse();
        expect(s.state).assertEqual(LoadState.Error);
        expect(s.errorMessage.length > 0).assertTrue();
        expect(s.loggedIn).assertFalse();
      });
    });

    it('login_success_sets_reactive_flag_and_saves_token', 0, () => {
      const repo = new FakeRepository();
      const cred = new FakeCredentialStore();
      const guard = new AccountGuard();
      const s = new SessionStore(repo, cred, new FakeCacheCleaner(),
        new FakeSettingsCleaner(), guard);
      return s.login('  PAT-123  ').then((ok: boolean) => {
        expect(ok).assertTrue();
        expect(s.loggedIn).assertTrue();
        expect(s.user?.login).assertEqual('tester');
        expect(guard.isLoggedIn()).assertTrue();
        expect(cred.value).assertEqual('PAT-123');
        expect(s.state).assertEqual(LoadState.Ready);
      });
    });

    it('login_failure_does_not_persist_token', 0, () => {
      const repo = new FakeRepository();
      repo.userResult = unauthorized();
      const cred = new FakeCredentialStore();
      const guard = new AccountGuard();
      const s = new SessionStore(repo, cred, new FakeCacheCleaner(),
        new FakeSettingsCleaner(), guard);
      return s.login('BAD').then((ok: boolean) => {
        expect(ok).assertFalse();
        expect(cred.savedCount).assertEqual(0);
        expect(cred.value).assertEqual(undefined);
        expect(s.loggedIn).assertFalse();
        expect(guard.isLoggedIn()).assertFalse();
        expect(s.state).assertEqual(LoadState.Error);
      });
    });

    it('login_marks_relogin_on_401', 0, () => {
      const repo = new FakeRepository();
      repo.userResult = unauthorized();
      const s = new SessionStore(repo, new FakeCredentialStore(), new FakeCacheCleaner(),
        new FakeSettingsCleaner(), new AccountGuard());
      return s.login('BAD').then(() => {
        expect(s.needReLogin).assertTrue();
      });
    });

    it('restore_without_saved_token_stays_logged_out', 0, () => {
      const s = makeSession();
      return s.restore().then((ok: boolean) => {
        expect(ok).assertFalse();
        expect(s.loggedIn).assertFalse();
        expect(s.state).assertEqual(LoadState.Idle);
      });
    });

    it('restore_with_valid_token_logs_in', 0, () => {
      const cred = new FakeCredentialStore();
      cred.value = 'SAVED';
      const s = new SessionStore(new FakeRepository(), cred, new FakeCacheCleaner(),
        new FakeSettingsCleaner(), new AccountGuard());
      return s.restore().then((ok: boolean) => {
        expect(ok).assertTrue();
        expect(s.loggedIn).assertTrue();
      });
    });

    it('restore_with_expired_token_clears_credentials', 0, () => {
      const repo = new FakeRepository();
      repo.userResult = unauthorized();
      const cred = new FakeCredentialStore();
      cred.value = 'EXPIRED';
      const s = new SessionStore(repo, cred, new FakeCacheCleaner(),
        new FakeSettingsCleaner(), new AccountGuard());
      return s.restore().then((ok: boolean) => {
        expect(ok).assertFalse();
        expect(cred.removedCount).assertEqual(1);
        expect(cred.value).assertEqual(undefined);
        expect(s.needReLogin).assertTrue();
        expect(s.loggedIn).assertFalse();
      });
    });

    it('logout_clears_everything_in_order', 0, () => {
      const guard = new AccountGuard();
      const cred = new FakeCredentialStore();
      cred.value = 'T';
      const cache = new FakeCacheCleaner();
      const settings = new FakeSettingsCleaner();
      const repo = new FakeRepository();
      const s = new SessionStore(repo, cred, cache, settings, guard);
      return s.login('T').then(() => s.logout()).then(() => {
        expect(s.loggedIn).assertFalse();
        expect(s.user === undefined).assertTrue();
        expect(s.repos.length).assertEqual(0);
        expect(guard.isLoggedIn()).assertFalse();
        expect(cred.removedCount).assertEqual(1);
        expect(cache.cleared).assertEqual(1);
        expect(settings.cleared).assertEqual(1);
        expect(s.state).assertEqual(LoadState.Idle);
      });
    });

    it('refresh_resets_to_first_page', 0, () => {
      const repo = new FakeRepository();
      const s = new SessionStore(repo, new FakeCredentialStore(), new FakeCacheCleaner(),
        new FakeSettingsCleaner(), new AccountGuard());
      return s.login('T').then(() => s.loadRepos()).then(() => s.refresh()).then(() => {
        expect(repo.requestedPages.length >= 3).assertTrue();
        expect(repo.requestedPages[repo.requestedPages.length - 1]).assertEqual(1);
        expect(s.state).assertEqual(LoadState.Ready);
      });
    });

    it('repos_accumulate_across_pages', 0, () => {
      const repo = new FakeRepository();
      repo.reposResult = new Page<RepoSummary>([fakeRepo('a/b')], true,
        PagingState.first(PagingType.Offset));
      const s = new SessionStore(repo, new FakeCredentialStore(), new FakeCacheCleaner(),
        new FakeSettingsCleaner(), new AccountGuard());
      return s.login('T').then(() => s.loadRepos()).then(() => {
        expect(s.repos.length).assertEqual(2);
      });
    });

    it('orgs_failure_does_not_wipe_repos', 0, () => {
      const repo = new FakeRepository();
      repo.orgsResult = unauthorized();
      const s = new SessionStore(repo, new FakeCredentialStore(), new FakeCacheCleaner(),
        new FakeSettingsCleaner(), new AccountGuard());
      return s.login('T').then(() => {
        expect(s.repos.length > 0).assertTrue();
        expect(s.errorMessage.length > 0).assertTrue();
      });
    });
  });

  describe('RepoBrowseStore', () => {
    it('open_loads_detail_dir_and_checks', 0, () => {
      const repo = new FakeRepository();
      repo.dirResult = [new RepoEntry('dir', 'src', 'src', 0)];
      const b = new RepoBrowseStore(repo);
      return b.open('o', 'r').then(() => {
        expect(b.repo?.fullName).assertEqual('o/r');
        expect(b.entries.length).assertEqual(1);
        expect(b.state).assertEqual(LoadState.Ready);
        expect(b.currentPath).assertEqual('');
        expect(b.rootLabel()).assertEqual('o/r');
        expect(repo.calls.indexOf('checkRuns') >= 0).assertTrue();
      });
    });

    it('enter_dir_updates_path_and_go_up_walks_back', 0, () => {
      const repo = new FakeRepository();
      const b = new RepoBrowseStore(repo);
      return b.open('o', 'r')
        .then(() => b.enterDir('a/b'))
        .then(() => {
          expect(b.currentPath).assertEqual('a/b');
          expect(b.rootLabel()).assertEqual('a/b');
          return b.goUp();
        })
        .then((moved: boolean) => {
          expect(moved).assertTrue();
          expect(b.currentPath).assertEqual('a');
          return b.goUp();
        })
        .then((moved: boolean) => {
          expect(moved).assertTrue();
          expect(b.currentPath).assertEqual('');
          return b.goUp();
        })
        .then((moved: boolean) => {
          expect(moved).assertFalse();
        });
    });

    it('open_file_then_close_returns_to_dir_view', 0, () => {
      const repo = new FakeRepository();
      repo.dirResult = [new RepoEntry('file', 'README.md', 'README.md', 10)];
      repo.fileResult = new RepoFileContent('README.md', 'README.md', 10, '', '# Title', true);
      const b = new RepoBrowseStore(repo);
      return b.open('o', 'r')
        .then(() => b.openFile('README.md'))
        .then(() => {
          expect(b.file === undefined).assertFalse();
          b.closeFile();
          expect(b.file === undefined).assertTrue();
        });
    });

    it('dir_failure_sets_error_state', 0, () => {
      const repo = new FakeRepository();
      repo.dirResult = unauthorized();
      const b = new RepoBrowseStore(repo);
      return b.open('o', 'r').then(() => {
        expect(b.state).assertEqual(LoadState.Error);
        expect(b.errorMessage.length > 0).assertTrue();
      });
    });

    it('ci_failure_does_not_block_repo_open', 0, () => {
      const repo = new FakeRepository();
      repo.checksResult = unauthorized();
      const b = new RepoBrowseStore(repo);
      return b.open('o', 'r').then(() => {
        expect(b.repo === undefined).assertFalse();
        expect(b.entries !== undefined).assertTrue();
        expect(b.errorMessage.length > 0).assertTrue();
      });
    });

    it('checks_accumulate_across_pages', 0, () => {
      const repo = new FakeRepository();
      const run = new CheckRun(1, 'build', 'main', CheckStatus.Success, 'COMPLETED',
        'SUCCESS', 'Push', '', '');
      repo.checksResult = new Page<CheckRun>([run], true, PagingState.first(PagingType.Offset));
      const b = new RepoBrowseStore(repo);
      return b.open('o', 'r').then(() => {
        expect(b.checks.length).assertEqual(1);
        return b.loadChecks();
      }).then(() => {
        expect(b.checks.length).assertEqual(2);
      });
    });
  });
}

import { ApiError, ApiErrorKind } from '../../main/ets/common/ApiError';
import { nextOffsetRequest, OffsetPageRequest, Page } from '../../main/ets/common/Pager';
import { CheckRun, CurrentUser, NamespaceItem, OrgSummary, RepoEntry, RepoFileContent, RepoSummary }
  from '../../main/ets/model/Entities';
import { RepoReadRepository, SessionReadRepository } from '../../main/ets/repository/Ports';
import { CredentialStore } from '../../main/ets/security/CredentialStore';
import { CacheCleaner, SettingsCleaner } from '../../main/ets/storage/StoragePorts';

export function fakeUser(login: string = 'tester'): CurrentUser {
  return new CurrentUser('acc-1', login, 'Tester', '', '', '', '', '');
}

export function fakeRepo(fullName: string): RepoSummary {
  const parts = fullName.split('/');
  const short = parts.length > 1 ? parts[1] : parts[0];
  return new RepoSummary(1, parts[0], short, short, fullName, '',
    'https://atomgit.com/' + fullName, 'master', false, false, 0, 0, 0);
}

export class FakeRepository implements SessionReadRepository, RepoReadRepository {
  userResult: CurrentUser | ApiError | null = fakeUser();
  reposResult: Page<RepoSummary> | ApiError | null = null;
  orgsResult: OrgSummary[] | ApiError | null = [];
  namespacesResult: NamespaceItem[] | ApiError | null = [];
  dirResult: RepoEntry[] | ApiError | null = [];
  fileResult: RepoFileContent | ApiError | null = null;
  checksResult: Page<CheckRun> | ApiError | null = null;
  calls: string[] = [];
  requestedPages: number[] = [];

  private pick<T>(v: T | ApiError | null, name: string): T {
    this.calls.push(name);
    if (v instanceof ApiError) {
      throw v;
    }
    if (v === null) {
      throw new Error('unexpected call: ' + name);
    }
    return v;
  }

  async currentUser(): Promise<CurrentUser> {
    return this.pick(this.userResult, 'currentUser');
  }

  async myRepos(request: OffsetPageRequest): Promise<Page<RepoSummary>> {
    this.requestedPages.push(request.page);
    const result = this.pick(this.reposResult ?? this.defaultRepos(request), 'myRepos');
    return new Page<RepoSummary>(result.items, request,
      nextOffsetRequest(request, result.hasMore));
  }

  private defaultRepos(request: OffsetPageRequest): Page<RepoSummary> {
    return new Page<RepoSummary>([fakeRepo('a/b')], request,
      nextOffsetRequest(request, request.page < 2));
  }

  async myNamespaces(): Promise<NamespaceItem[]> {
    return this.pick(this.namespacesResult, 'myNamespaces');
  }

  async orgsOf(username: string): Promise<OrgSummary[]> {
    return this.pick(this.orgsResult, 'orgsOf:' + username);
  }

  async repoDetail(owner: string, repo: string): Promise<RepoSummary> {
    return this.pick(fakeRepo(owner + '/' + repo), 'repoDetail');
  }

  async listDir(owner: string, repo: string, path: string): Promise<RepoEntry[]> {
    return this.pick(this.dirResult, 'listDir:' + path);
  }

  async fileContent(owner: string, repo: string, path: string): Promise<RepoFileContent> {
    return this.pick(this.fileResult, 'fileContent:' + path);
  }

  async checkRuns(owner: string, repo: string, branch: string | undefined, request: OffsetPageRequest):
    Promise<Page<CheckRun>> {
    const result = this.pick(this.checksResult ?? Page.empty<CheckRun>(request), 'checkRuns');
    return new Page<CheckRun>(result.items, request,
      nextOffsetRequest(request, result.hasMore));
  }
}

export class FakeCredentialStore implements CredentialStore {
  value: string | undefined = undefined;
  savedCount: number = 0;
  removedCount: number = 0;

  async save(token: string): Promise<void> {
    this.value = token;
    this.savedCount++;
  }

  async load(): Promise<string | undefined> {
    return this.value;
  }

  async remove(): Promise<void> {
    this.value = undefined;
    this.removedCount++;
  }
}

export class FakeCacheCleaner implements CacheCleaner {
  cleared: number = 0;
  async clearCurrentAccount(): Promise<void> {
    this.cleared++;
  }
}

export class FakeSettingsCleaner implements SettingsCleaner {
  cleared: number = 0;
  async clear(): Promise<void> {
    this.cleared++;
  }
}

export function unauthorized(): ApiError {
  return new ApiError(ApiErrorKind.Unauthorized, 401, 401, 'unauthorized', 't1', '/user');
}

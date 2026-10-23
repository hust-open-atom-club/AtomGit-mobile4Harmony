import { Page } from '../common/Pager';
import { CheckRun, CurrentUser, NamespaceItem, OrgSummary, RepoEntry, RepoFileContent, RepoSummary }
  from '../model/Entities';

export interface UserRepository {
  currentUser(): Promise<CurrentUser>;
}

export interface MineRepository {
  myRepos(page: number, perPage: number): Promise<Page<RepoSummary>>;
  myNamespaces(): Promise<NamespaceItem[]>;
  orgsOf(username: string): Promise<OrgSummary[]>;
}

export interface RepoReadRepository {
  repoDetail(owner: string, repo: string): Promise<RepoSummary>;
  listDir(owner: string, repo: string, path: string): Promise<RepoEntry[]>;
  fileContent(owner: string, repo: string, path: string): Promise<RepoFileContent>;
  checkRuns(owner: string, repo: string, branch: string | undefined, page: number, perPage: number):
    Promise<Page<CheckRun>>;
}

export interface SessionReadRepository extends UserRepository, MineRepository {
}

import { OffsetPageRequest, Page, PageRequest } from '../../../main/ets/common/Pager';
import {
  ActivityItem,
  RepositoryItemKind,
  RepositoryItemRef
} from '../../../main/ets/model/CollaborationEntities';
import {
  CurrentUser,
  NamespaceItem,
  OrgSummary,
  RepoSummary
} from '../../../main/ets/model/Entities';
import {
  ActivityRepository,
  SessionReadRepository
} from '../../../main/ets/repository/Ports';
import { CredentialStore } from '../../../main/ets/security/CredentialStore';
import { CacheCleaner, SettingsCleaner } from '../../../main/ets/storage/StoragePorts';

export const E2E_TOKEN: string = 'E2E-TEST-TOKEN';
export const E2E_PERSONAL_TITLE: string = 'E2E personal activity';
export const E2E_PROJECT_TITLE: string = 'E2E project activity';

export class E2ESessionRepository implements SessionReadRepository {
  async currentUser(): Promise<CurrentUser> {
    return new CurrentUser('e2e-account', 'e2e-user', 'E2E User', '',
      'https://atomgit.com/e2e-user', '', '', '');
  }

  async myRepos(request: OffsetPageRequest): Promise<Page<RepoSummary>> {
    return new Page<RepoSummary>([e2eRepo()], request);
  }

  async myNamespaces(): Promise<NamespaceItem[]> {
    return [];
  }

  async orgsOf(username: string): Promise<OrgSummary[]> {
    return [];
  }
}

export class E2EActivityRepository implements ActivityRepository {
  async personalActivity(username: string, year: number,
    request: PageRequest): Promise<Page<ActivityItem>> {
    return new Page<ActivityItem>([e2eItem(E2E_PERSONAL_TITLE)], request);
  }

  async repositoryActivity(owner: string, repo: string,
    request: PageRequest): Promise<Page<ActivityItem>> {
    return new Page<ActivityItem>([e2eItem(E2E_PROJECT_TITLE)], request);
  }
}

export class E2ECredentialStore implements CredentialStore {
  private value: string | undefined = undefined;

  async save(token: string): Promise<void> {
    this.value = token;
  }

  async load(): Promise<string | undefined> {
    return this.value;
  }

  async remove(): Promise<void> {
    this.value = undefined;
  }
}

export class E2ECacheCleaner implements CacheCleaner {
  async clearCurrentAccount(): Promise<void> {
  }
}

export class E2ESettingsCleaner implements SettingsCleaner {
  async clear(): Promise<void> {
  }
}

export function e2eRepo(): RepoSummary {
  return new RepoSummary(1, 'e2e-owner', 'e2e-repo', 'e2e-repo',
    'e2e-owner/e2e-repo', 'E2E repository',
    'https://atomgit.com/e2e-owner/e2e-repo', 'main', false, false, 0, 0, 0);
}

function e2eItem(title: string): ActivityItem {
  return new ActivityItem('e2e-' + title, 'issue', title, 'e2e-user',
    'e2e-owner/e2e-repo', new Date().toISOString(),
    new RepositoryItemRef('e2e-owner', 'e2e-repo', 1),
    RepositoryItemKind.Issue, '', 'opened');
}

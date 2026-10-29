import {
  ContentsDirEntryDto,
  ContentsFileDto,
  NamespaceListItemDto,
  OrgDto,
  OwnerDto,
  RepoDto,
  UserDto,
  WorkflowRunDto
} from './Dtos';
import {
  CheckRun,
  CheckStatus,
  CurrentUser,
  NamespaceItem,
  OrgSummary,
  RepoEntry,
  RepoSummary
} from './Entities';

export function str(v: string | undefined, fallback: string = ''): string {
  if (v === undefined || v === null) {
    return fallback;
  }
  const t = v.trim();
  return t.length === 0 ? fallback : t;
}

export function count(v: number | undefined): number {
  if (v === undefined || v === null || !Number.isFinite(v) || v < 0) {
    return 0;
  }
  return Math.floor(v);
}

function ownerName(o: OwnerDto | undefined): string {
  if (o === undefined) {
    return '';
  }
  return str(o.name, str(o.login));
}

export function toCurrentUser(d: UserDto): CurrentUser {
  const login = str(d.login);
  // accountId 优先稳定 id，退化 login；缓存分区键必须稳定
  return new CurrentUser(str(d.id, login), login, str(d.name, login), str(d.avatar_url),
    str(d.html_url), str(d.bio), str(d.company), str(d.email));
}

export function toRepoSummary(d: RepoDto): RepoSummary {
  const nsPath = d.namespace === undefined ? '' : str(d.namespace.path);
  const nsName = d.namespace === undefined ? '' : str(d.namespace.name);
  const ownerFromNs = str(nsPath, str(nsName));
  const ownerFromCreator = d.creator === undefined ? '' : str(d.creator.login);
  const full = str(d.full_name);
  let owner = str(ownerFromNs, str(ownerFromCreator));
  let name = str(d.name);
  if (full.includes('/')) {
    const parts = full.split('/');
    if (owner.length === 0) {
      owner = parts[0];
    }
    if (name.length === 0) {
      name = parts[1];
    }
  }
  return new RepoSummary(count(d.id), owner, name,
    str(d.human_name, str(d.name)),
    full,
    str(d.description),
    // 实测无 html_url：web_url → http_url_to_repo
    str(d.web_url, str(d.http_url_to_repo)),
    str(d.default_branch, 'master'),
    // private 为主，internal 兜底
    d.private === true || d.internal === true,
    d.fork === true,
    count(d.stargazers_count),
    count(d.forks_count),
    count(d.open_issues_count));
}

export function toOrgSummary(d: OrgDto): OrgSummary {
  const login = str(d.login);
  return new OrgSummary(login, str(d.name, login), str(d.path, login),
    str(d.avatar_url), str(d.html_url));
}

export function toNamespaceItem(d: NamespaceListItemDto): NamespaceItem {
  const path = str(d.path, str(d.name));
  return new NamespaceItem(path, str(d.name, path), str(d.type, 'user'));
}

export function toRepoEntry(d: ContentsDirEntryDto): RepoEntry {
  const name = str(d.name);
  return new RepoEntry(str(d.type, 'file'), name, str(d.path, name), 0);
}

export function toRepoFileEntry(d: ContentsFileDto): RepoEntry {
  const name = str(d.name);
  return new RepoEntry(str(d.type, 'file'), name, str(d.path, name), count(d.size));
}

// file_list 只返回路径字符串，无 type/size
export function buildEntryFromPath(path: string, parentPath: string): RepoEntry {
  const full = path.trim();
  const name = full.includes('/') ? full.substring(full.lastIndexOf('/') + 1) : full;
  const isDir = !name.includes('.');
  return new RepoEntry(isDir ? 'dir' : 'file', name, full, 0);
}

// status 与 conclusion 需一起看，FAILED 可能落在任一字段
export function normalizeCheckStatus(status: string, conclusion: string): CheckStatus {
  const s = status.toUpperCase();
  const c = conclusion.toUpperCase();
  if (s === 'RUNNING' || s === 'PENDING' || s === 'QUEUED' || s === 'WAITING'
    || s === 'IN_PROGRESS') {
    return CheckStatus.Running;
  }
  if (s === 'FAILED' || c === 'FAILURE' || c === 'FAILED' || c === 'TIMED_OUT') {
    return CheckStatus.Failure;
  }
  if (s === 'COMPLETED' && (c === 'SUCCESS' || c.length === 0)) {
    return CheckStatus.Success;
  }
  if (s === 'CANCELED' || s === 'CANCELLED' || s === 'IGNORED'
    || s === 'PAUSED' || s === 'SUSPEND' || s === 'SKIPPED') {
    return CheckStatus.Other;
  }
  if (s.length === 0) {
    return CheckStatus.Unknown;
  }
  return CheckStatus.Unknown;
}

function runIdentity(d: WorkflowRunDto): string {
  const explicit = str(d.workflow_run_id);
  if (explicit.length > 0) {
    return explicit;
  }
  const numeric = d.id;
  if (numeric !== undefined && numeric !== null) {
    return numeric.toString();
  }
  return str(d.title, str(d.workflow_name, 'run'));
}

export function toCheckRun(d: WorkflowRunDto): CheckRun {
  const rawStatus = str(d.status);
  const rawConclusion = str(d.conclusion);
  return new CheckRun(runIdentity(d),
    str(d.title, str(d.display_title, str(d.workflow_name, str(d.name, 'workflow')))),
    str(d.head_branch),
    normalizeCheckStatus(rawStatus, rawConclusion),
    rawStatus, rawConclusion, str(d.event), str(d.html_url),
    str(d.start_time, str(d.created_at)));
}

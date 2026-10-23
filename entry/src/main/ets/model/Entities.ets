export class CurrentUser {
  // 账号标识，用于缓存分区
  readonly accountId: string;
  readonly login: string;
  readonly name: string;
  readonly avatarUrl: string;
  readonly htmlUrl: string;
  readonly bio: string;
  readonly company: string;
  readonly email: string;

  constructor(accountId: string, login: string, name: string, avatarUrl: string,
    htmlUrl: string, bio: string, company: string, email: string) {
    this.accountId = accountId;
    this.login = login;
    this.name = name;
    this.avatarUrl = avatarUrl;
    this.htmlUrl = htmlUrl;
    this.bio = bio;
    this.company = company;
    this.email = email;
  }

  displayName(): string {
    return this.name.length > 0 ? this.name : this.login;
  }
}

export class RepoSummary {
  readonly id: number;
  // URL 中的 {owner} 段
  readonly owner: string;
  // URL 中的 {repo} 段
  readonly name: string;
  // 人类可读名，平台字段 human_name
  readonly displayName: string;
  readonly fullName: string;
  readonly description: string;
  // 平台无 html_url，映射自 web_url
  readonly htmlUrl: string;
  readonly defaultBranch: string;
  // 平台无 private 字段，由 internal 兜底
  readonly isPrivate: boolean;
  readonly isFork: boolean;
  readonly stars: number;
  readonly forks: number;
  readonly openIssues: number;

  constructor(id: number, owner: string, name: string, displayName: string, fullName: string,
    description: string, htmlUrl: string, defaultBranch: string,
    isPrivate: boolean, isFork: boolean, stars: number, forks: number, openIssues: number) {
    this.id = id;
    this.owner = owner;
    this.name = name;
    this.displayName = displayName;
    this.fullName = fullName;
    this.description = description;
    this.htmlUrl = htmlUrl;
    this.defaultBranch = defaultBranch;
    this.isPrivate = isPrivate;
    this.isFork = isFork;
    this.stars = stars;
    this.forks = forks;
    this.openIssues = openIssues;
  }
}

export class OrgSummary {
  readonly login: string;
  readonly name: string;
  readonly path: string;
  readonly avatarUrl: string;
  readonly htmlUrl: string;

  constructor(login: string, name: string, path: string, avatarUrl: string, htmlUrl: string) {
    this.login = login;
    this.name = name;
    this.path = path;
    this.avatarUrl = avatarUrl;
    this.htmlUrl = htmlUrl;
  }

  displayName(): string {
    return this.name.length > 0 ? this.name : this.login;
  }
}

// 实测 type 为 user / group
export class NamespaceItem {
  readonly path: string;
  readonly name: string;
  readonly type: string;

  constructor(path: string, name: string, type: string) {
    this.path = path;
    this.name = name;
    this.type = type;
  }

  isGroup(): boolean {
    return this.type === 'group';
  }
}

export class RepoEntry {
  // 平台 type 字段：file / dir
  readonly kind: string;
  readonly name: string;
  // 相对仓库根路径，可作 contents 的 path 参数
  readonly path: string;
  readonly size: number;

  constructor(kind: string, name: string, path: string, size: number) {
    this.kind = kind;
    this.name = name;
    this.path = path;
    this.size = size;
  }

  isDir(): boolean {
    return this.kind === 'dir';
  }
}

export class RepoFileContent {
  readonly name: string;
  readonly path: string;
  readonly size: number;
  readonly htmlUrl: string;
  readonly text: string;
  readonly decodable: boolean;

  constructor(name: string, path: string, size: number, htmlUrl: string,
    text: string, decodable: boolean) {
    this.name = name;
    this.path = path;
    this.size = size;
    this.htmlUrl = htmlUrl;
    this.text = text;
    this.decodable = decodable;
  }
}

export enum CheckStatus {
  Running = 'Running',
  Success = 'Success',
  Failure = 'Failure',
  Other = 'Other',
  Unknown = 'Unknown',
}

export class CheckRun {
  readonly id: number;
  readonly name: string;
  readonly branch: string;
  readonly status: CheckStatus;
  readonly rawStatus: string;
  readonly rawConclusion: string;
  readonly event: string;
  readonly htmlUrl: string;
  readonly createdAt: string;

  constructor(id: number, name: string, branch: string, status: CheckStatus,
    rawStatus: string, rawConclusion: string, event: string,
    htmlUrl: string, createdAt: string) {
    this.id = id;
    this.name = name;
    this.branch = branch;
    this.status = status;
    this.rawStatus = rawStatus;
    this.rawConclusion = rawConclusion;
    this.event = event;
    this.htmlUrl = htmlUrl;
    this.createdAt = createdAt;
  }
}

/** Stable app-facing identity for an Issue or pull request. */
export class RepositoryItemRef {
  readonly owner: string;
  readonly repo: string;
  readonly number: number;

  constructor(owner: string, repo: string, number: number) {
    this.owner = owner;
    this.repo = repo;
    this.number = number;
  }

  key(): string { return this.owner + '/' + this.repo + '#' + this.number; }
}

export enum RepositoryItemKind { Issue = 'issue', PullRequest = 'pull_request' }

export class ActivityItem {
  readonly id: string;
  readonly kind: string;
  readonly title: string;
  readonly actor: string;
  readonly repository: string;
  readonly createdAt: string;
  readonly target: RepositoryItemRef | undefined;

  constructor(id: string, kind: string, title: string, actor: string, repository: string,
    createdAt: string, target?: RepositoryItemRef) {
    this.id = id;
    this.kind = kind;
    this.title = title;
    this.actor = actor;
    this.repository = repository;
    this.createdAt = createdAt;
    this.target = target;
  }
}

export class WorkItem {
  readonly kind: RepositoryItemKind;
  readonly ref: RepositoryItemRef;
  readonly title: string;
  readonly state: string;
  readonly htmlUrl: string;
  readonly updatedAt: string;

  constructor(kind: RepositoryItemKind, ref: RepositoryItemRef, title: string, state: string,
    htmlUrl: string, updatedAt: string) {
    this.kind = kind;
    this.ref = ref;
    this.title = title;
    this.state = state;
    this.htmlUrl = htmlUrl;
    this.updatedAt = updatedAt;
  }
}

export class NotificationItem {
  readonly id: string;
  readonly repository: string;
  readonly subjectType: string;
  readonly title: string;
  readonly unread: boolean;
  readonly target: RepositoryItemRef | undefined;

  constructor(id: string, repository: string, subjectType: string, title: string,
    unread: boolean, target?: RepositoryItemRef) {
    this.id = id;
    this.repository = repository;
    this.subjectType = subjectType;
    this.title = title;
    this.unread = unread;
    this.target = target;
  }
}

export class CollaborationComment {
  readonly id: string;
  readonly body: string;
  readonly author: string;
  readonly htmlUrl: string;
  readonly createdAt: string;

  constructor(id: string, body: string, author: string, htmlUrl: string, createdAt: string) {
    this.id = id;
    this.body = body;
    this.author = author;
    this.htmlUrl = htmlUrl;
    this.createdAt = createdAt;
  }
}

export class PullRequestFile {
  readonly path: string;
  readonly status: string;
  readonly additions: number;
  readonly deletions: number;
  readonly patch: string;

  constructor(path: string, status: string, additions: number, deletions: number, patch: string) {
    this.path = path;
    this.status = status;
    this.additions = additions;
    this.deletions = deletions;
    this.patch = patch;
  }
}

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
  /** Distinguishes an Issue target from a pull request target; undefined when unknown. */
  readonly targetKind: RepositoryItemKind | undefined;

  constructor(id: string, kind: string, title: string, actor: string, repository: string,
    createdAt: string, target?: RepositoryItemRef, targetKind?: RepositoryItemKind) {
    this.id = id;
    this.kind = kind;
    this.title = title;
    this.actor = actor;
    this.repository = repository;
    this.createdAt = createdAt;
    this.target = target;
    this.targetKind = targetKind;
  }
}

/** Lightweight row model for todo and project issue/pull request lists. */
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

/** Issue detail; the body and author are required by the processing page. */
export class IssueDetail {
  readonly ref: RepositoryItemRef;
  readonly title: string;
  readonly body: string;
  readonly state: string;
  readonly htmlUrl: string;
  readonly createdAt: string;
  readonly updatedAt: string;
  readonly author: string;
  readonly labels: string[];

  constructor(ref: RepositoryItemRef, title: string, body: string, state: string,
    htmlUrl: string, createdAt: string, updatedAt: string, author: string,
    labels: string[] = []) {
    this.ref = ref;
    this.title = title;
    this.body = body;
    this.state = state;
    this.htmlUrl = htmlUrl;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
    this.author = author;
    this.labels = labels;
  }
}

export class ApprovalReviewer {
  readonly login: string;
  readonly name: string;
  readonly acceptStatus: string;

  constructor(login: string, name: string, acceptStatus: string) {
    this.login = login;
    this.name = name;
    this.acceptStatus = acceptStatus;
  }
}

/** Pull request detail; carries the head SHA and approval readback fields. */
export class PullRequestDetail {
  readonly ref: RepositoryItemRef;
  readonly title: string;
  readonly body: string;
  readonly state: string;
  readonly merged: boolean;
  readonly mergedAt: string;
  readonly mergeable: boolean;
  readonly headSha: string;
  readonly baseSha: string;
  readonly htmlUrl: string;
  readonly updatedAt: string;
  readonly author: string;
  readonly approvalReviewers: ApprovalReviewer[];

  constructor(ref: RepositoryItemRef, title: string, body: string, state: string,
    merged: boolean, mergedAt: string, mergeable: boolean, headSha: string, baseSha: string,
    htmlUrl: string, updatedAt: string, author: string,
    approvalReviewers: ApprovalReviewer[] = []) {
    this.ref = ref;
    this.title = title;
    this.body = body;
    this.state = state;
    this.merged = merged;
    this.mergedAt = mergedAt;
    this.mergeable = mergeable;
    this.headSha = headSha;
    this.baseSha = baseSha;
    this.htmlUrl = htmlUrl;
    this.updatedAt = updatedAt;
    this.author = author;
    this.approvalReviewers = approvalReviewers;
  }
}

export class NotificationItem {
  readonly id: string;
  readonly repository: string;
  readonly subjectType: string;
  readonly title: string;
  readonly unread: boolean;
  readonly updatedAt: string;
  readonly target: RepositoryItemRef | undefined;
  readonly targetKind: RepositoryItemKind | undefined;

  constructor(id: string, repository: string, subjectType: string, title: string,
    unread: boolean, updatedAt: string, target?: RepositoryItemRef,
    targetKind?: RepositoryItemKind) {
    this.id = id;
    this.repository = repository;
    this.subjectType = subjectType;
    this.title = title;
    this.unread = unread;
    this.updatedAt = updatedAt;
    this.target = target;
    this.targetKind = targetKind;
  }
}

export class CollaborationComment {
  readonly id: string;
  readonly body: string;
  readonly author: string;
  readonly htmlUrl: string;
  readonly createdAt: string;
  readonly commentType: string;
  readonly discussionId: string;
  readonly parentId: string;
  readonly resolved: boolean;

  constructor(id: string, body: string, author: string, htmlUrl: string, createdAt: string,
    commentType: string = '', discussionId: string = '', parentId: string = '',
    resolved: boolean = false) {
    this.id = id;
    this.body = body;
    this.author = author;
    this.htmlUrl = htmlUrl;
    this.createdAt = createdAt;
    this.commentType = commentType;
    this.discussionId = discussionId;
    this.parentId = parentId;
    this.resolved = resolved;
  }
}

/**
 * Changed file of a pull request. `patch` is absent for binary, too-large, or
 * truncated files; `truncated` marks a patch the client clipped to its cap.
 */
export class PullRequestFile {
  readonly path: string;
  readonly status: string;
  readonly additions: number;
  readonly deletions: number;
  readonly patch: string | undefined;
  readonly oldPath: string;
  readonly tooLarge: boolean;
  readonly truncated: boolean;
  readonly sha: string;

  constructor(path: string, status: string, additions: number, deletions: number,
    patch?: string, oldPath: string = '', tooLarge: boolean = false,
    truncated: boolean = false, sha: string = '') {
    this.path = path;
    this.status = status;
    this.additions = additions;
    this.deletions = deletions;
    this.patch = patch;
    this.oldPath = oldPath;
    this.tooLarge = tooLarge;
    this.truncated = truncated;
    this.sha = sha;
  }
}

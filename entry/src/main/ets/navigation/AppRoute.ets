import { RepositoryItemRef } from '../model/CollaborationEntities';

export enum AppRouteName {
  IssueDetail = 'issueDetail',
  PullRequestDetail = 'pullRequestDetail',
  RepositoryDetail = 'repoDetail'
}

export class RepositoryDetailParams {
  readonly owner: string;
  readonly repo: string;
  constructor(owner: string, repo: string) { this.owner = owner; this.repo = repo; }
}

export class IssueDetailParams {
  readonly ref: RepositoryItemRef;
  constructor(ref: RepositoryItemRef) { this.ref = ref; }
}

export class PullRequestDetailParams {
  readonly ref: RepositoryItemRef;
  constructor(ref: RepositoryItemRef) { this.ref = ref; }
}

/** NavPathStack still receives a name and object; this helper centralizes route spelling. */
export class AppRoute {
  readonly name: AppRouteName;
  readonly params: RepositoryDetailParams | IssueDetailParams | PullRequestDetailParams;
  private constructor(name: AppRouteName,
    params: RepositoryDetailParams | IssueDetailParams | PullRequestDetailParams) {
    this.name = name;
    this.params = params;
  }

  static issue(ref: RepositoryItemRef): AppRoute {
    return new AppRoute(AppRouteName.IssueDetail, new IssueDetailParams(ref));
  }

  static pullRequest(ref: RepositoryItemRef): AppRoute {
    return new AppRoute(AppRouteName.PullRequestDetail, new PullRequestDetailParams(ref));
  }

  static repository(owner: string, repo: string): AppRoute {
    return new AppRoute(AppRouteName.RepositoryDetail, new RepositoryDetailParams(owner, repo));
  }
}

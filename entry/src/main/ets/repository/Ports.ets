import { CancellationSignal } from '../common/Cancellation';
import { Page, PageRequest } from '../common/Pager';
import { CheckRun, CurrentUser, NamespaceItem, OrgSummary, RepoEntry, RepoFileContent, RepoSummary }
  from '../model/Entities';
import { ActivityItem, CollaborationComment, NotificationItem, PullRequestFile, WorkItem, RepositoryItemRef }
  from '../model/CollaborationEntities';

export interface UserRepository {
  currentUser(cancel?: CancellationSignal): Promise<CurrentUser>;
}

export interface MineRepository {
  myRepos(page: number, perPage: number, cancel?: CancellationSignal): Promise<Page<RepoSummary>>;
  myNamespaces(cancel?: CancellationSignal): Promise<NamespaceItem[]>;
  orgsOf(username: string, cancel?: CancellationSignal): Promise<OrgSummary[]>;
}

export interface RepoReadRepository {
  repoDetail(owner: string, repo: string, cancel?: CancellationSignal): Promise<RepoSummary>;
  listDir(owner: string, repo: string, path: string, cancel?: CancellationSignal): Promise<RepoEntry[]>;
  fileContent(owner: string, repo: string, path: string, cancel?: CancellationSignal): Promise<RepoFileContent>;
  checkRuns(owner: string, repo: string, branch: string | undefined, page: number, perPage: number,
    cancel?: CancellationSignal):
    Promise<Page<CheckRun>>;
}

export enum PullRequestTodoScope {
  NeedsApproval = 'need_my_approve',
  NeedsReview = 'need_my_review',
  AssignedToMe = 'assigned_to_me',
  CreatedByMe = 'created_by_me'
}

export interface ActivityRepository {
  personalActivity(year: number, request: PageRequest, cancel?: CancellationSignal): Promise<Page<ActivityItem>>;
  repositoryActivity(owner: string, repo: string, request: PageRequest,
    cancel?: CancellationSignal): Promise<Page<ActivityItem>>;
}

export interface TodoRepository {
  assignedIssues(request: PageRequest, cancel?: CancellationSignal): Promise<Page<WorkItem>>;
  createdIssues(request: PageRequest, cancel?: CancellationSignal): Promise<Page<WorkItem>>;
  pullRequests(scope: PullRequestTodoScope, request: PageRequest, cancel?: CancellationSignal): Promise<Page<WorkItem>>;
}

export interface IssueRepository {
  issue(ref: RepositoryItemRef, cancel?: CancellationSignal): Promise<WorkItem>;
  issueComments(ref: RepositoryItemRef, request: PageRequest, cancel?: CancellationSignal): Promise<Page<CollaborationComment>>;
  addIssueComment(ref: RepositoryItemRef, body: string, cancel?: CancellationSignal): Promise<void>;
}

export interface PullRequestRepository {
  pullRequest(ref: RepositoryItemRef, cancel?: CancellationSignal): Promise<WorkItem>;
  pullRequestComments(ref: RepositoryItemRef, request: PageRequest,
    cancel?: CancellationSignal): Promise<Page<CollaborationComment>>;
  pullRequestFiles(ref: RepositoryItemRef, cancel?: CancellationSignal): Promise<PullRequestFile[]>;
  approvePullRequest(ref: RepositoryItemRef, cancel?: CancellationSignal): Promise<void>;
}

export interface NotificationRepository {
  notifications(owner: string, repo: string, request: PageRequest,
    cancel?: CancellationSignal): Promise<Page<NotificationItem>>;
  markNotificationsRead(owner: string, repo: string, ids: string[], cancel?: CancellationSignal): Promise<void>;
}

/** Aggregate target contract for feature repositories as their adapters are implemented. */
export interface AppRepository extends SessionReadRepository, RepoReadRepository,
  ActivityRepository, TodoRepository, IssueRepository, PullRequestRepository, NotificationRepository {
}

export interface SessionReadRepository extends UserRepository, MineRepository {
}

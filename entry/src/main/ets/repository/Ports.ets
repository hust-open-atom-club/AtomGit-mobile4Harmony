import { CancellationSignal } from '../common/Cancellation';
import { Page, PageRequest } from '../common/Pager';
import { CheckRun, CurrentUser, NamespaceItem, OrgSummary, RepoEntry, RepoFileContent, RepoSummary }
  from '../model/Entities';
import {
  ActivityItem,
  CollaborationComment,
  IssueDetail,
  NotificationItem,
  PullRequestDetail,
  PullRequestFile,
  RepositoryItemRef,
  WorkItem
} from '../model/CollaborationEntities';

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

/** Client caps applied while loading pull request files. */
export const DEFAULT_MAX_PR_FILES: number = 100;
export const DEFAULT_MAX_PATCH_CHARS: number = 200000;

export class PullRequestFilesOptions {
  readonly maxFiles: number;
  readonly maxPatchChars: number;

  constructor(maxFiles: number = DEFAULT_MAX_PR_FILES,
    maxPatchChars: number = DEFAULT_MAX_PATCH_CHARS) {
    this.maxFiles = Number.isFinite(maxFiles) && maxFiles >= 1
      ? Math.floor(maxFiles) : DEFAULT_MAX_PR_FILES;
    this.maxPatchChars = Number.isFinite(maxPatchChars) && maxPatchChars >= 1
      ? Math.floor(maxPatchChars) : DEFAULT_MAX_PATCH_CHARS;
  }
}

/**
 * Formal approval options. An empty `expectedHeadSha` skips the check; otherwise
 * the adapter must reject the request when the current head SHA differs, so the
 * user cannot approve a version they did not review.
 */
export class ApprovePullRequestOptions {
  readonly force: boolean;
  readonly expectedHeadSha: string;

  constructor(force: boolean = false, expectedHeadSha: string = '') {
    this.force = force;
    this.expectedHeadSha = expectedHeadSha;
  }
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
  issue(ref: RepositoryItemRef, cancel?: CancellationSignal): Promise<IssueDetail>;
  issueComments(ref: RepositoryItemRef, request: PageRequest, cancel?: CancellationSignal): Promise<Page<CollaborationComment>>;
  addIssueComment(ref: RepositoryItemRef, body: string, cancel?: CancellationSignal): Promise<void>;
}

export interface PullRequestRepository {
  pullRequest(ref: RepositoryItemRef, cancel?: CancellationSignal): Promise<PullRequestDetail>;
  /** `commentType` filters plain comments from review/diff comments when the endpoint supports it. */
  pullRequestComments(ref: RepositoryItemRef, request: PageRequest, commentType?: string,
    cancel?: CancellationSignal): Promise<Page<CollaborationComment>>;
  pullRequestFiles(ref: RepositoryItemRef, options?: PullRequestFilesOptions,
    cancel?: CancellationSignal): Promise<PullRequestFile[]>;
  addPullRequestComment(ref: RepositoryItemRef, body: string,
    cancel?: CancellationSignal): Promise<void>;
  /** The caller is expected to read the PR detail back before showing success. */
  approvePullRequest(ref: RepositoryItemRef, options?: ApprovePullRequestOptions,
    cancel?: CancellationSignal): Promise<void>;
}

export interface NotificationRepository {
  notifications(owner: string, repo: string, request: PageRequest,
    cancel?: CancellationSignal): Promise<Page<NotificationItem>>;
  markNotificationsRead(owner: string, repo: string, ids: string[], cancel?: CancellationSignal): Promise<void>;
}

export interface SessionReadRepository extends UserRepository, MineRepository {
}

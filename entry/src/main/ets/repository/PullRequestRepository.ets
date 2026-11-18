import { JSON as ArkJSON } from '@kit.ArkTS';

import { ApiError, ApiErrorKind } from '../common/ApiError';
import { CancellationSignal } from '../common/Cancellation';
import { OffsetPageRequest, Page, PageRequest, nextOffsetRequest, offsetHasMore } from '../common/Pager';
import { HttpResult } from '../network/HttpClient';
import { HttpPort } from '../network/HttpPort';
import { HttpMethod } from '../network/NetworkPolicy';
import { RequestSpec, kv } from '../network/RequestSpec';
import {
  ApprovalReviewer,
  CollaborationComment,
  PullRequestDetail,
  PullRequestFile,
  RepositoryItemRef
} from '../model/CollaborationEntities';
import {
  ApprovePullRequestOptions,
  PullRequestFilesOptions,
  PullRequestRepository
} from './Ports';

interface UserApiDto {
  id?: string | number;
  login?: string;
  name?: string;
  html_url?: string;
}

interface BranchApiDto {
  ref?: string;
  sha?: string;
}

interface ApprovalReviewerApiDto {
  id?: string | number;
  login?: string;
  name?: string;
  accept?: boolean;
  accept_status?: string | boolean;
}

interface PullRequestApiDto {
  id?: string | number;
  number?: string | number;
  title?: string;
  body?: string;
  state?: string;
  html_url?: string;
  web_url?: string;
  updated_at?: string;
  user?: UserApiDto;
  merged?: boolean;
  merged_at?: string;
  mergeable?: boolean;
  head?: BranchApiDto;
  base?: BranchApiDto;
  approval_reviewers?: ApprovalReviewerApiDto[];
}

interface CommentApiDto {
  id?: string | number;
  body?: string;
  html_url?: string;
  created_at?: string;
  user?: UserApiDto;
  comment_type?: string;
  discussion_id?: string;
  parent_id?: string;
  resolved?: boolean;
  reply?: CommentApiDto[];
}

interface PullRequestFilePatchApiDto {
  diff?: string;
  old_path?: string;
  new_path?: string;
  added_lines?: number;
  removed_lines?: number;
  too_large?: boolean;
  new_file?: boolean;
  renamed_file?: boolean;
  deleted_file?: boolean;
}

interface PullRequestFileApiDto {
  sha?: string;
  filename?: string;
  status?: string;
  additions?: number;
  deletions?: number;
  too_large?: boolean;
  patch?: PullRequestFilePatchApiDto;
}

interface CurrentUserApiDto {
  login?: string;
  name?: string;
}

export const PR_HEAD_MISMATCH_MESSAGE: string =
  'The pull request head changed. Review the latest head before approving.';
export const APPROVAL_READBACK_UNCONFIRMED_MESSAGE: string =
  'Approval was submitted, but the approval status could not be confirmed.';

/** A recognizable ApiError for the expected-head guard. */
export class PullRequestHeadMismatchError extends ApiError {
  readonly expectedHeadSha: string;
  readonly currentHeadSha: string;

  constructor(expectedHeadSha: string, currentHeadSha: string) {
    super(ApiErrorKind.Conflict, 409, 409, PR_HEAD_MISMATCH_MESSAGE, '', '');
    this.expectedHeadSha = expectedHeadSha;
    this.currentHeadSha = currentHeadSha;
  }
}

/**
 * AtomGit v5 pull request adapter.
 *
 * Evidence:
 * - GET/POST /repos/{owner}/{repo}/pulls[/{number}]
 * - GET /repos/{owner}/{repo}/pulls/{number}/comments?page&per_page&comment_type
 * - GET /repos/{owner}/{repo}/pulls/{number}/files (patch.diff)
 * - POST /repos/{owner}/{repo}/pulls/{number}/review with {"force": boolean}
 */
export class PullRequestApiRepository implements PullRequestRepository {
  private readonly http: HttpPort;
  private readonly knownCurrentUserLogin: string;

  constructor(http: HttpPort, currentUserLogin: string = '') {
    this.http = http;
    this.knownCurrentUserLogin = currentUserLogin.trim();
  }

  async pullRequest(ref: RepositoryItemRef, cancel?: CancellationSignal): Promise<PullRequestDetail> {
    return this.fetchPullRequest(ref, cancel);
  }

  async pullRequestComments(ref: RepositoryItemRef, request: PageRequest, commentType?: string,
    cancel?: CancellationSignal): Promise<Page<CollaborationComment>> {
    const offset = request instanceof OffsetPageRequest
      ? request : new OffsetPageRequest(1, 20);
    const query: string[] = [
      kv('page', offset.page),
      kv('per_page', offset.perPage),
      kv('direction', 'desc')
    ];
    if (commentType !== undefined && commentType.trim().length > 0) {
      query.push(kv('comment_type', commentType.trim()));
    }
    const path = this.commentsPath(ref);
    const spec = new RequestSpec(HttpMethod.GET, path, query, false, true);
    const res = await this.http.request(spec, cancel);
    const list = this.parseArray(res, path);
    const comments: CollaborationComment[] = [];
    for (const item of list) {
      this.appendComment(comments, item as CommentApiDto, '');
    }
    const hasMore = offsetHasMore(list.length, offset.perPage);
    return new Page<CollaborationComment>(comments, offset,
      nextOffsetRequest(offset, hasMore));
  }

  async pullRequestFiles(ref: RepositoryItemRef, options?: PullRequestFilesOptions,
    cancel?: CancellationSignal): Promise<PullRequestFile[]> {
    const safe = options === undefined ? new PullRequestFilesOptions() : options;
    const path = this.filesPath(ref);
    const spec = new RequestSpec(HttpMethod.GET, path, [], false, true);
    const res = await this.http.request(spec, cancel);
    const list = this.parseArray(res, path);
    const files: PullRequestFile[] = [];
    const limit = Math.min(list.length, safe.maxFiles);
    for (let i = 0; i < limit; i++) {
      files.push(this.toPullRequestFile(list[i] as PullRequestFileApiDto, safe.maxPatchChars));
    }
    return files;
  }

  async addPullRequestComment(ref: RepositoryItemRef, body: string,
    cancel?: CancellationSignal): Promise<void> {
    const path = this.commentsPath(ref);
    const payload = JSON.stringify({ body: body });
    const spec = new RequestSpec(HttpMethod.POST, path, [], false, true, payload);
    await this.http.request(spec, cancel);
  }

  async approvePullRequest(ref: RepositoryItemRef, options?: ApprovePullRequestOptions,
    cancel?: CancellationSignal): Promise<void> {
    const safe = options === undefined ? new ApprovePullRequestOptions() : options;
    const expected = safe.expectedHeadSha.trim();
    const preflight = await this.fetchPullRequest(ref, cancel);
    if (expected.length > 0 && !sameSha(expected, preflight.headSha)) {
      throw new PullRequestHeadMismatchError(expected, preflight.headSha);
    }

    const path = this.reviewPath(ref);
    const payload = JSON.stringify({ force: safe.force });
    const spec = new RequestSpec(HttpMethod.POST, path, [], false, true, payload);
    // Write failures deliberately propagate as the original ApiError.
    await this.http.request(spec, cancel);

    // A 200 only means the request was accepted. Confirm both the reviewed
    // head and the authenticated user's reviewer status before returning.
    const login = await this.currentUserLogin(cancel);
    const readback = await this.fetchPullRequest(ref, cancel);
    if (expected.length > 0 && !sameSha(expected, readback.headSha)) {
      throw new PullRequestHeadMismatchError(expected, readback.headSha);
    }
    if (!this.isApprovedBy(readback, login)) {
      throw new ApiError(ApiErrorKind.Conflict, 200, 0,
        APPROVAL_READBACK_UNCONFIRMED_MESSAGE, '', path);
    }
  }

  private async fetchPullRequest(ref: RepositoryItemRef, cancel?: CancellationSignal):
    Promise<PullRequestDetail> {
    const path = this.pullRequestPath(ref);
    const spec = new RequestSpec(HttpMethod.GET, path, [], false, true);
    const res = await this.http.request(spec, cancel);
    const dto = this.parseObject(res, path) as PullRequestApiDto;
    return this.toPullRequestDetail(ref, dto);
  }

  private async currentUserLogin(cancel?: CancellationSignal): Promise<string> {
    if (this.knownCurrentUserLogin.length > 0) {
      return this.knownCurrentUserLogin;
    }
    const spec = new RequestSpec(HttpMethod.GET, '/user', [], false, true);
    const res = await this.http.request(spec, cancel);
    const dto = this.parseObject(res, '/user') as CurrentUserApiDto;
    const login = stringValue(dto.login, stringValue(dto.name, '')).trim();
    if (login.length === 0) {
      throw new ApiError(ApiErrorKind.Parse, res.status, 0,
        'current user response did not include a login', '', '/user');
    }
    return login;
  }

  private toPullRequestDetail(ref: RepositoryItemRef, dto: PullRequestApiDto): PullRequestDetail {
    const state = stringValue(dto.state, '').toLowerCase();
    const reviewers: ApprovalReviewer[] = [];
    const sourceReviewers = dto.approval_reviewers ?? [];
    for (const reviewer of sourceReviewers) {
      const login = stringValue(reviewer.login, '');
      const name = stringValue(reviewer.name, login);
      const status = reviewer.accept_status === undefined
        ? (reviewer.accept === true ? 'true' : '')
        : statusValue(reviewer.accept_status);
      reviewers.push(new ApprovalReviewer(login, name, status));
    }
    const htmlUrl = stringValue(dto.html_url, stringValue(dto.web_url, ''));
    return new PullRequestDetail(
      ref,
      stringValue(dto.title, ''),
      stringValue(dto.body, ''),
      state,
      dto.merged === true || state === 'merged',
      stringValue(dto.merged_at, ''),
      dto.mergeable === true,
      stringValue(dto.head === undefined ? undefined : dto.head.sha, ''),
      stringValue(dto.base === undefined ? undefined : dto.base.sha, ''),
      htmlUrl,
      stringValue(dto.updated_at, ''),
      stringValue(dto.user === undefined ? undefined : dto.user.login,
        stringValue(dto.user === undefined ? undefined : dto.user.name, '')),
      reviewers
    );
  }

  private toPullRequestFile(dto: PullRequestFileApiDto, maxPatchChars: number): PullRequestFile {
    const patchDto = dto.patch;
    const filename = stringValue(dto.filename, '');
    const oldPath = stringValue(patchDto === undefined ? undefined : patchDto.old_path, filename);
    const newPath = stringValue(patchDto === undefined ? undefined : patchDto.new_path, filename);
    const tooLarge = dto.too_large === true || (patchDto !== undefined && patchDto.too_large === true);
    const rawPatch = patchDto === undefined ? undefined : normalizeUnifiedPatch(patchDto.diff);
    let patch: string | undefined = rawPatch;
    let truncated = false;
    if (rawPatch !== undefined && rawPatch.length > maxPatchChars) {
      patch = rawPatch.substring(0, maxPatchChars);
      truncated = true;
    }
    const nestedAdditions = numberValue(patchDto === undefined ? undefined : patchDto.added_lines);
    const nestedDeletions = numberValue(patchDto === undefined ? undefined : patchDto.removed_lines);
    const additions = dto.additions === undefined || dto.additions === 0
      ? nestedAdditions : numberValue(dto.additions);
    const deletions = dto.deletions === undefined || dto.deletions === 0
      ? nestedDeletions : numberValue(dto.deletions);
    const status = changeStatus(dto.status, patchDto, tooLarge);
    return new PullRequestFile(newPath, status, additions, deletions, patch, oldPath,
      tooLarge, truncated, stringValue(dto.sha, ''));
  }

  private appendComment(out: CollaborationComment[], dto: CommentApiDto, parentId: string): void {
    const id = stringValue(dto.id, '');
    const parent = parentId.length > 0
      ? parentId : stringValue(dto.parent_id, '');
    const author = stringValue(dto.user === undefined ? undefined : dto.user.login,
      stringValue(dto.user === undefined ? undefined : dto.user.name, ''));
    out.push(new CollaborationComment(
      id,
      stringValue(dto.body, ''),
      author,
      stringValue(dto.html_url, ''),
      stringValue(dto.created_at, ''),
      stringValue(dto.comment_type, ''),
      stringValue(dto.discussion_id, ''),
      parent,
      dto.resolved === true
    ));
    const replies = dto.reply ?? [];
    for (const reply of replies) {
      this.appendComment(out, reply, id);
    }
  }

  private isApprovedBy(detail: PullRequestDetail, login: string): boolean {
    const target = login.trim().toLowerCase();
    if (target.length === 0) {
      return false;
    }
    for (const reviewer of detail.approvalReviewers) {
      if (reviewer.login.trim().toLowerCase() === target
        && isApprovalAccepted(reviewer.acceptStatus)) {
        return true;
      }
    }
    return false;
  }

  private parseArray(res: HttpResult, endpoint: string): Object[] {
    const parsed = this.parseOrThrow(res, endpoint);
    if (Array.isArray(parsed)) {
      return parsed as Object[];
    }
    throw new ApiError(ApiErrorKind.Parse, res.status, 0,
      'expected array response', '', endpoint);
  }

  private parseObject(res: HttpResult, endpoint: string): Object {
    const parsed = this.parseOrThrow(res, endpoint);
    if (Array.isArray(parsed) || parsed === null) {
      throw new ApiError(ApiErrorKind.Parse, res.status, 0,
        'expected object response', '', endpoint);
    }
    return parsed as Object;
  }

  private parseOrThrow(res: HttpResult, endpoint: string): Object | Object[] {
    if (res.body.trim().length === 0) {
      throw new ApiError(ApiErrorKind.Parse, res.status, 0,
        'empty json body', '', endpoint);
    }
    let parsed: Object | Object[] | undefined = undefined;
    try {
      parsed = ArkJSON.parse(res.body) as Object | Object[];
    } catch {
      parsed = undefined;
    }
    if (parsed === undefined || parsed === null) {
      throw new ApiError(ApiErrorKind.Parse, res.status, 0,
        'malformed json body', '', endpoint);
    }
    return parsed;
  }

  private pullRequestPath(ref: RepositoryItemRef): string {
    return '/repos/' + seg(ref.owner) + '/' + seg(ref.repo) + '/pulls/' + ref.number.toString();
  }

  private commentsPath(ref: RepositoryItemRef): string {
    return this.pullRequestPath(ref) + '/comments';
  }

  private filesPath(ref: RepositoryItemRef): string {
    return this.pullRequestPath(ref) + '/files';
  }

  private reviewPath(ref: RepositoryItemRef): string {
    return this.pullRequestPath(ref) + '/review';
  }
}

export function isApprovalAccepted(status: string): boolean {
  const normalized = status.trim().toLowerCase();
  return normalized === 'true' || normalized === 'accept' || normalized === 'accepted'
    || normalized === 'approved';
}

function seg(value: string): string {
  return encodeURIComponent(value);
}

function stringValue(value: string | number | undefined, fallback: string): string {
  if (value === undefined || value === null) {
    return fallback;
  }
  return String(value);
}

function statusValue(value: string | boolean): string {
  return typeof value === 'boolean' ? (value ? 'true' : '') : value;
}

function numberValue(value: number | undefined): number {
  return value === undefined || !Number.isFinite(value) ? 0 : value;
}

function sameSha(left: string, right: string): boolean {
  return left.trim().toLowerCase() === right.trim().toLowerCase();
}

function normalizeUnifiedPatch(raw: string | undefined): string | undefined {
  if (raw === undefined || raw.length === 0) {
    return undefined;
  }
  const text = raw.replace(/\r\n/g, '\n');
  // The files endpoint documents patch.diff as unified diff. Do not present
  // arbitrary text as a diff when an incompatible payload arrives.
  if (text.indexOf('@@') < 0 && text.indexOf('diff --git ') !== 0) {
    return undefined;
  }
  return text;
}

function changeStatus(status: string | undefined,
  patch: PullRequestFilePatchApiDto | undefined, tooLarge: boolean): string {
  const normalized = stringValue(status, '').trim().toLowerCase();
  if (tooLarge) {
    return 'too_large';
  }
  if (normalized === 'binary') {
    return 'binary';
  }
  if (normalized === 'added' || normalized === 'new') {
    return 'added';
  }
  if (normalized === 'deleted' || normalized === 'removed') {
    return 'deleted';
  }
  if (normalized === 'renamed') {
    return 'renamed';
  }
  if (normalized.length > 0) {
    return normalized;
  }
  if (patch !== undefined) {
    if (patch.deleted_file === true) {
      return 'deleted';
    }
    if (patch.renamed_file === true) {
      return 'renamed';
    }
    if (patch.new_file === true) {
      return 'added';
    }
  }
  return 'modified';
}

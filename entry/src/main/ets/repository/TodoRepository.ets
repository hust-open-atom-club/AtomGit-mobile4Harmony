import { JSON as ArkJSON } from '@kit.ArkTS';

import { ApiError, ApiErrorKind, buildApiError } from '../common/ApiError';
import { CancellationSignal } from '../common/Cancellation';
import { OffsetPageRequest, Page, PageRequest, nextOffsetRequest, offsetHasMore } from '../common/Pager';
import { HttpResult } from '../network/HttpClient';
import { HttpPort } from '../network/HttpPort';
import { HttpMethod } from '../network/NetworkPolicy';
import { RequestSpec, kv } from '../network/RequestSpec';
import { IssueDto, PullRequestDto, RepositoryIdentityDto } from '../model/CollaborationDtos';
import { RepositoryItemKind, RepositoryItemRef, WorkItem } from '../model/CollaborationEntities';
import { PullRequestTodoScope, TodoRepository } from './Ports';

function nonEmpty(value: string | undefined): boolean {
  return value !== undefined && value.trim().length > 0;
}

function text(value: string | undefined): string {
  return value === undefined ? '' : value.trim();
}

function positiveInteger(value: string | number | undefined): number {
  if (value === undefined) {
    return 0;
  }
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : 0;
}

function repositoryParts(value: string | undefined): string[] {
  const full = text(value).replace(/^\/+|\/+$/g, '');
  const slash = full.indexOf('/');
  if (slash <= 0 || slash >= full.length - 1 || full.indexOf('/', slash + 1) >= 0) {
    return [];
  }
  return [full.substring(0, slash), full.substring(slash + 1)];
}

function repositoryPartsFromApiUrl(value: string | undefined): string[] {
  const raw = text(value);
  const marker = '/repos/';
  const start = raw.indexOf(marker);
  if (start < 0) {
    return [];
  }
  const remaining = raw.substring(start + marker.length).split('?')[0].split('#')[0];
  const parts = remaining.split('/');
  if (parts.length < 2 || parts[0].length === 0 || parts[1].length === 0) {
    return [];
  }
  return [parts[0], parts[1]];
}

function repositoryPartsFromDto(repository: RepositoryIdentityDto | undefined): string[] {
  if (repository === undefined) {
    return [];
  }
  let parts = repositoryParts(repository.full_name);
  if (parts.length === 0) {
    parts = repositoryParts(repository.human_name);
  }
  if (parts.length > 0) {
    return parts;
  }
  const name = text(repository.name);
  const namespace = repository.namespace;
  let owner = '';
  if (namespace !== undefined) {
    owner = nonEmpty(namespace.path) ? text(namespace.path) : text(namespace.name);
  }
  if (name.length > 0 && owner.length > 0) {
    return [owner, name];
  }
  return repositoryPartsFromApiUrl(repository.url);
}

function webTarget(value: string | undefined, kind: RepositoryItemKind): string[] {
  const raw = text(value).split('?')[0].split('#')[0];
  if (raw.length === 0) {
    return [];
  }
  const parts = raw.split('/');
  const markers: string[] = kind === RepositoryItemKind.Issue
    ? ['issues', 'issue'] : ['pulls', 'pull', 'merge_requests'];
  for (let index = 0; index < parts.length; index++) {
    if (markers.indexOf(parts[index]) < 0 || index < 2 || index + 1 >= parts.length) {
      continue;
    }
    const owner = parts[index - 2];
    const repo = parts[index - 1];
    const number = positiveInteger(parts[index + 1]);
    if (owner.length > 0 && repo.length > 0 && number > 0) {
      return [owner, repo, number.toString()];
    }
  }
  return [];
}

function resolveRef(dto: IssueDto, kind: RepositoryItemKind): RepositoryItemRef | undefined {
  let parts = repositoryPartsFromDto(dto.repository);
  let number = positiveInteger(dto.number);
  const target = webTarget(dto.html_url, kind);
  if (target.length === 3) {
    if (number === 0) {
      number = Number(target[2]);
    }
    if (parts.length === 0) {
      parts = [target[0], target[1]];
    }
  }
  if (parts.length !== 2 || number <= 0) {
    return undefined;
  }
  return new RepositoryItemRef(parts[0], parts[1], number);
}

function fallbackWebUrl(ref: RepositoryItemRef, kind: RepositoryItemKind): string {
  const target = kind === RepositoryItemKind.Issue ? 'issues' : 'pull';
  return 'https://atomgit.com/' + ref.owner + '/' + ref.repo + '/' + target + '/'
    + ref.number.toString();
}

function mapIssue(dto: IssueDto, endpoint: string): WorkItem {
  const ref = resolveRef(dto, RepositoryItemKind.Issue);
  if (ref === undefined) {
    throw new ApiError(ApiErrorKind.Parse, 200, 0,
      'issue payload is missing a stable repository identity', '', endpoint);
  }
  const title = nonEmpty(dto.title) ? text(dto.title) : 'Issue #' + ref.number.toString();
  return new WorkItem(
    RepositoryItemKind.Issue,
    ref,
    title,
    nonEmpty(dto.state) ? text(dto.state) : 'unknown',
    nonEmpty(dto.html_url) ? text(dto.html_url) : fallbackWebUrl(ref, RepositoryItemKind.Issue),
    text(dto.updated_at)
  );
}

function mapPullRequest(dto: PullRequestDto, endpoint: string): WorkItem {
  const ref = resolveRef(dto, RepositoryItemKind.PullRequest);
  if (ref === undefined) {
    throw new ApiError(ApiErrorKind.Parse, 200, 0,
      'pull request payload is missing a stable repository identity', '', endpoint);
  }
  const title = nonEmpty(dto.title)
    ? text(dto.title) : 'Pull request #' + ref.number.toString();
  return new WorkItem(
    RepositoryItemKind.PullRequest,
    ref,
    title,
    nonEmpty(dto.state) ? text(dto.state) : 'unknown',
    nonEmpty(dto.html_url) ? text(dto.html_url) : fallbackWebUrl(ref, RepositoryItemKind.PullRequest),
    text(dto.updated_at)
  );
}

function parseRows(res: HttpResult, endpoint: string): Object[] {
  if (res.status < 200 || res.status >= 300) {
    throw buildApiError(res.status, res.body, endpoint);
  }
  if (res.truncated) {
    throw new ApiError(ApiErrorKind.Parse, res.status, 0,
      'todo response was truncated', '', endpoint);
  }
  let parsed: Object | Object[] | undefined = undefined;
  try {
    parsed = ArkJSON.parse(res.body) as Object | Object[];
  } catch {
    parsed = undefined;
  }
  if (parsed === undefined || parsed === null || !Array.isArray(parsed)) {
    throw new ApiError(ApiErrorKind.Parse, res.status, 0,
      'expected an array response', '', endpoint);
  }
  const rows = parsed as Object[];
  for (const row of rows) {
    if (row === null || typeof row !== 'object' || Array.isArray(row)) {
      throw new ApiError(ApiErrorKind.Parse, res.status, 0,
        'todo response contains a non-object item', '', endpoint);
    }
  }
  return rows;
}

function uniqueItems(items: WorkItem[]): WorkItem[] {
  const result: WorkItem[] = [];
  const seen: Set<string> = new Set<string>();
  for (const item of items) {
    const key = item.kind + '|' + item.ref.key();
    if (!seen.has(key)) {
      seen.add(key);
      result.push(item);
    }
  }
  return result;
}

function offsetRequest(request: PageRequest, endpoint: string): OffsetPageRequest {
  if (!(request instanceof OffsetPageRequest)) {
    throw new ApiError(ApiErrorKind.Parse, 0, 0,
      'todo requests require offset paging', '', endpoint);
  }
  return request;
}

function throwIfCanceled(cancel: CancellationSignal | undefined, endpoint: string): void {
  if (cancel !== undefined && cancel.isCanceled()) {
    throw new ApiError(ApiErrorKind.Canceled, 0, 0, 'canceled', '', endpoint);
  }
}

export class TodoApiRepository implements TodoRepository {
  private readonly http: HttpPort;

  constructor(http: HttpPort) {
    this.http = http;
  }

  async assignedIssues(request: PageRequest, cancel?: CancellationSignal): Promise<Page<WorkItem>> {
    return this.issues('assigned', request, cancel);
  }

  async createdIssues(request: PageRequest, cancel?: CancellationSignal): Promise<Page<WorkItem>> {
    return this.issues('created', request, cancel);
  }

  async pullRequests(scope: PullRequestTodoScope, request: PageRequest,
    cancel?: CancellationSignal): Promise<Page<WorkItem>> {
    const endpoint = '/user/pulls';
    const page = offsetRequest(request, endpoint);
    const scopeValue = this.scopeValue(scope, endpoint);
    throwIfCanceled(cancel, endpoint);
    const spec = new RequestSpec(HttpMethod.GET, endpoint, [
      kv('scope', scopeValue),
      kv('state', 'open'),
      kv('page', page.page),
      kv('per_page', page.perPage)
    ], false, true);
    const res = await this.http.request(spec, cancel);
    throwIfCanceled(cancel, endpoint);
    const rows = parseRows(res, endpoint);
    const items: WorkItem[] = [];
    for (const row of rows) {
      items.push(mapPullRequest(row as PullRequestDto, endpoint));
    }
    return new Page<WorkItem>(uniqueItems(items), page,
      nextOffsetRequest(page, offsetHasMore(rows.length, page.perPage)));
  }

  private async issues(filter: string, request: PageRequest,
    cancel?: CancellationSignal): Promise<Page<WorkItem>> {
    const endpoint = '/user/issues';
    const page = offsetRequest(request, endpoint);
    throwIfCanceled(cancel, endpoint);
    const spec = new RequestSpec(HttpMethod.GET, endpoint, [
      kv('filter', filter),
      kv('state', 'open'),
      kv('page', page.page),
      kv('per_page', page.perPage)
    ], false, true);
    const res = await this.http.request(spec, cancel);
    throwIfCanceled(cancel, endpoint);
    const rows = parseRows(res, endpoint);
    const items: WorkItem[] = [];
    for (const row of rows) {
      items.push(mapIssue(row as IssueDto, endpoint));
    }
    return new Page<WorkItem>(uniqueItems(items), page,
      nextOffsetRequest(page, offsetHasMore(rows.length, page.perPage)));
  }

  private scopeValue(scope: PullRequestTodoScope, endpoint: string): string {
    if (scope === PullRequestTodoScope.NeedsApproval
      || scope === PullRequestTodoScope.NeedsReview
      || scope === PullRequestTodoScope.AssignedToMe
      || scope === PullRequestTodoScope.CreatedByMe) {
      return scope;
    }
    throw new ApiError(ApiErrorKind.Parse, 0, 0,
      'unsupported pull request todo scope', '', endpoint);
  }
}

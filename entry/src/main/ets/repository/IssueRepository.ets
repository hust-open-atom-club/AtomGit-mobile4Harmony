import { JSON as ArkJSON } from '@kit.ArkTS';

import { ApiError, ApiErrorKind } from '../common/ApiError';
import { CancellationSignal } from '../common/Cancellation';
import { OffsetPageRequest, Page, PageRequest, nextOffsetRequest } from '../common/Pager';
import { HttpResult } from '../network/HttpClient';
import { HttpPort } from '../network/HttpPort';
import { HttpMethod } from '../network/NetworkPolicy';
import { RequestSpec, kv } from '../network/RequestSpec';
import {
  CommentDto,
  IssueDto,
  LabelIdentityDto,
  UserIdentityDto
} from '../model/CollaborationDtos';
import {
  CollaborationComment,
  IssueDetail,
  RepositoryItemRef
} from '../model/CollaborationEntities';
import { IssueRepository } from './Ports';

interface IssueCommentBody {
  body: string;
}

function segment(value: string): string {
  return encodeURIComponent(value);
}

function parseError(res: HttpResult, endpoint: string, message: string): ApiError {
  return new ApiError(ApiErrorKind.Parse, res.status, 0, message, '', endpoint);
}

function parseObject(res: HttpResult, endpoint: string): Object {
  let parsed: Object | undefined = undefined;
  try {
    parsed = ArkJSON.parse(res.body) as Object;
  } catch {
    parsed = undefined;
  }
  if (parsed === undefined || parsed === null || Array.isArray(parsed)) {
    throw parseError(res, endpoint, 'expected an issue object');
  }
  return parsed;
}

function parseCommentArray(res: HttpResult, endpoint: string): Object[] {
  let parsed: Object | undefined = undefined;
  try {
    parsed = ArkJSON.parse(res.body) as Object;
  } catch {
    parsed = undefined;
  }
  if (parsed === undefined || parsed === null || !Array.isArray(parsed)) {
    throw parseError(res, endpoint, 'expected a comment array');
  }
  return parsed as Object[];
}

function requiredText(value: string | undefined, res: HttpResult, endpoint: string,
  field: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw parseError(res, endpoint, 'missing required issue field: ' + field);
  }
  return value;
}

function optionalText(value: string | undefined, res: HttpResult, endpoint: string,
  field: string): string {
  if (value === undefined) {
    return '';
  }
  if (typeof value !== 'string') {
    throw parseError(res, endpoint, 'invalid issue field: ' + field);
  }
  return value;
}

function identifier(value: string | number | undefined): string {
  if (typeof value === 'string') {
    return value.trim();
  }
  if (typeof value === 'number' && Number.isFinite(value) && value > 0) {
    return Math.floor(value).toString();
  }
  return '';
}

function userLogin(value: UserIdentityDto | undefined, res: HttpResult, endpoint: string,
  field: string): string {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw parseError(res, endpoint, 'missing required issue author: ' + field);
  }
  return requiredText(value.login, res, endpoint, field);
}

function mapIssue(ref: RepositoryItemRef, res: HttpResult, endpoint: string): IssueDetail {
  const dto = parseObject(res, endpoint) as IssueDto;
  const title = requiredText(dto.title, res, endpoint, 'title');
  const body = optionalText(dto.body, res, endpoint, 'body');
  const state = requiredText(dto.state, res, endpoint, 'state');
  const htmlUrl = requiredText(dto.html_url, res, endpoint, 'html_url');
  const createdAt = requiredText(dto.created_at, res, endpoint, 'created_at');
  const updatedAt = requiredText(dto.updated_at, res, endpoint, 'updated_at');
  const author = userLogin(dto.user, res, endpoint, 'user.login');
  const labels: string[] = [];
  if (dto.labels !== undefined) {
    if (!Array.isArray(dto.labels)) {
      throw parseError(res, endpoint, 'issue labels must be an array');
    }
    for (const rawLabel of dto.labels) {
      if (rawLabel === undefined || rawLabel === null || typeof rawLabel !== 'object'
        || Array.isArray(rawLabel)) {
        throw parseError(res, endpoint, 'invalid issue label');
      }
      const label = rawLabel as LabelIdentityDto;
      if (label.name !== undefined && typeof label.name !== 'string') {
        throw parseError(res, endpoint, 'invalid issue label name');
      }
      if (label.name !== undefined && label.name.trim().length > 0) {
        labels.push(label.name);
      }
    }
  }
  return new IssueDetail(ref, title, body, state, htmlUrl, createdAt, updatedAt, author, labels);
}

function mapComment(value: Object, res: HttpResult, endpoint: string): CollaborationComment {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw parseError(res, endpoint, 'invalid issue comment');
  }
  const dto = value as CommentDto;
  const id = identifier(dto.id);
  if (id.length === 0) {
    throw parseError(res, endpoint, 'missing issue comment id');
  }
  const body = optionalText(dto.body, res, endpoint, 'comment.body');
  const author = userLogin(dto.user, res, endpoint, 'comment.user.login');
  const createdAt = requiredText(dto.created_at, res, endpoint, 'comment.created_at');
  const htmlUrl = optionalText(dto.html_url, res, endpoint, 'comment.html_url');
  const commentType = optionalText(dto.comment_type, res, endpoint, 'comment.comment_type');
  const discussionId = optionalText(dto.discussion_id, res, endpoint, 'comment.discussion_id');
  const parentId = optionalText(dto.parent_id, res, endpoint, 'comment.parent_id');
  let resolved: boolean = false;
  if (dto.resolved !== undefined) {
    if (typeof dto.resolved !== 'boolean') {
      throw parseError(res, endpoint, 'invalid issue comment resolved flag');
    }
    resolved = dto.resolved;
  }
  return new CollaborationComment(id, body, author, htmlUrl, createdAt, commentType,
    discussionId, parentId, resolved);
}

function issueEndpoint(ref: RepositoryItemRef): string {
  return '/repos/' + segment(ref.owner) + '/' + segment(ref.repo) + '/issues/' + ref.number.toString();
}

function validateRef(ref: RepositoryItemRef, endpoint: string): void {
  if (ref.owner.trim().length === 0 || ref.repo.trim().length === 0 || ref.number <= 0) {
    throw new ApiError(ApiErrorKind.Parse, 0, 0, 'invalid issue reference', '', endpoint);
  }
}

export class IssueApiRepository implements IssueRepository {
  private readonly http: HttpPort;

  constructor(http: HttpPort) {
    this.http = http;
  }

  async issue(ref: RepositoryItemRef, cancel?: CancellationSignal): Promise<IssueDetail> {
    const endpoint = issueEndpoint(ref);
    validateRef(ref, endpoint);
    const spec = new RequestSpec(HttpMethod.GET, endpoint, [], false, true);
    const res = await this.http.request(spec, cancel);
    return mapIssue(ref, res, endpoint);
  }

  async issueComments(ref: RepositoryItemRef, request: PageRequest,
    cancel?: CancellationSignal): Promise<Page<CollaborationComment>> {
    const endpoint = issueEndpoint(ref) + '/comments';
    validateRef(ref, endpoint);
    if (!(request instanceof OffsetPageRequest)) {
      throw new ApiError(ApiErrorKind.Parse, 0, 0,
        'issue comments require offset paging', '', endpoint);
    }
    const query: string[] = [
      kv('page', request.page),
      kv('per_page', request.perPage)
    ];
    const spec = new RequestSpec(HttpMethod.GET, endpoint, query, false, true);
    const res = await this.http.request(spec, cancel);
    const raw = parseCommentArray(res, endpoint);
    const items: CollaborationComment[] = [];
    for (const value of raw) {
      items.push(mapComment(value, res, endpoint));
    }
    return new Page<CollaborationComment>(items, request,
      nextOffsetRequest(request, items.length >= request.perPage));
  }

  async addIssueComment(ref: RepositoryItemRef, body: string,
    cancel?: CancellationSignal): Promise<string> {
    const endpoint = issueEndpoint(ref) + '/comments';
    validateRef(ref, endpoint);
    if (body.trim().length === 0) {
      throw new ApiError(ApiErrorKind.Unprocessable, 0, 0,
        'comment body cannot be empty', '', endpoint);
    }
    const requestBody: IssueCommentBody = { body: body };
    const spec = new RequestSpec(HttpMethod.POST, endpoint, [], false, true,
      ArkJSON.stringify(requestBody));
    const res = await this.http.request(spec, cancel);
    if (res.status !== 200 && res.status !== 201 && res.status !== 204) {
      throw new ApiError(ApiErrorKind.Unknown, res.status, 0,
        'unexpected issue comment response status', '', endpoint);
    }
    if (res.status === 204) {
      return '';
    }
    const created = parseObject(res, endpoint) as CommentDto;
    const createdId = identifier(created.id);
    if (createdId.length === 0) {
      throw parseError(res, endpoint, 'comment response missing id');
    }
    return createdId;
  }
}

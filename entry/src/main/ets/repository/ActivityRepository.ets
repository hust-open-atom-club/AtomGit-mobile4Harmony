import { JSON as ArkJSON } from '@kit.ArkTS';

import { ApiError, ApiErrorKind } from '../common/ApiError';
import { CancellationSignal } from '../common/Cancellation';
import {
  CursorPageRequest,
  OffsetPageRequest,
  Page,
  PageRequest,
  nextCursorRequest,
  nextOffsetRequest
} from '../common/Pager';
import { HttpResult } from '../network/HttpClient';
import { HttpPort } from '../network/HttpPort';
import { HttpMethod } from '../network/NetworkPolicy';
import { RequestSpec, kv } from '../network/RequestSpec';
import {
  ActivityDto,
  ActivityPageDto,
  RepositoryActivityPageDto
} from '../model/CollaborationDtos';
import {
  ActivityItem,
  RepositoryItemKind,
  RepositoryItemRef
} from '../model/CollaborationEntities';
import { ActivityRepository } from './Ports';

function segment(value: string): string {
  return encodeURIComponent(value);
}

function nonEmpty(value: string | undefined): boolean {
  return value !== undefined && value.trim().length > 0;
}

function firstLine(value: string | undefined): string {
  if (!nonEmpty(value)) {
    return '';
  }
  const text = (value as string).trim();
  const newline = text.indexOf('\n');
  return newline < 0 ? text : text.substring(0, newline).trim();
}

/**
 * Activity payloads do not carry a stable event ID. Build a deterministic key
 * from fields that identify the action, actor, repository and target.
 */
function activityId(event: ActivityDto, repository: string, target: RepositoryItemRef | undefined): string {
  const noteId = event.note === undefined || event.note.id === undefined ? '' : String(event.note.id);
  const pushTo = event.push_data === undefined || event.push_data.commit_to === undefined
    ? '' : event.push_data.commit_to;
  const targetKey = target === undefined ? '' : target.key();
  const action = event.action_name === undefined ? '' : event.action_name;
  const actor = event.author_username === undefined ? '' : event.author_username;
  const createdAt = event.created_at === undefined ? '' : event.created_at;
  return action + '|' + actor + '|' + repository + '|' + createdAt + '|' + targetKey + '|'
    + noteId + '|' + pushTo;
}

function repositoryParts(projectName: string): string[] {
  const slash = projectName.lastIndexOf('/');
  if (slash <= 0 || slash >= projectName.length - 1) {
    return [];
  }
  return [projectName.substring(0, slash), projectName.substring(slash + 1)];
}

function numberFromLink(link: string, marker: string): number {
  if (link.length === 0) {
    return 0;
  }
  const start = link.indexOf(marker);
  if (start < 0) {
    return 0;
  }
  let end = start + marker.length;
  while (end < link.length) {
    const code = link.charCodeAt(end);
    if (code < 48 || code > 57) {
      break;
    }
    end++;
  }
  if (end === start + marker.length) {
    return 0;
  }
  const parsed = Number(link.substring(start + marker.length, end));
  return Number.isFinite(parsed) && parsed > 0 ? Math.floor(parsed) : 0;
}

function normalizedType(value: string | undefined): string {
  return value === undefined ? '' : value.toLowerCase().replace(/_/g, '-');
}

function targetFromEvent(event: ActivityDto, owner: string, repo: string):
  RepositoryItemRef | undefined {
  const link = event._links === undefined || event._links.action_type === undefined
    ? '' : event._links.action_type;
  let number = numberFromLink(link, '/merge_requests/');
  let kind = RepositoryItemKind.PullRequest;
  if (number === 0) {
    number = numberFromLink(link, '/pulls/');
  }
  if (number === 0) {
    number = numberFromLink(link, '/issues/');
    if (number > 0) {
      kind = RepositoryItemKind.Issue;
    }
  }

  const targetType = normalizedType(event.target_type);
  const targetFormat = normalizedType(event.target_type_format);
  const noteType = event.note === undefined ? '' : normalizedType(event.note.noteable_type);
  if (number === 0) {
    if (targetType.indexOf('merge-request') >= 0 || targetType.indexOf('pull-request') >= 0
      || targetType === 'pr' || targetFormat === 'pr') {
      kind = RepositoryItemKind.PullRequest;
      number = event.target_iid === undefined ? 0 : Number(event.target_iid);
    } else if (targetType.indexOf('issue') >= 0) {
      kind = RepositoryItemKind.Issue;
      number = event.target_iid === undefined ? 0 : Number(event.target_iid);
    } else if (noteType.indexOf('merge-request') >= 0 || noteType.indexOf('pull-request') >= 0) {
      kind = RepositoryItemKind.PullRequest;
      number = event.note === undefined || event.note.noteable_iid === undefined
        ? 0 : Number(event.note.noteable_iid);
    } else if (noteType.indexOf('issue') >= 0) {
      kind = RepositoryItemKind.Issue;
      number = event.note === undefined || event.note.noteable_iid === undefined
        ? 0 : Number(event.note.noteable_iid);
    }
  }
  if (!Number.isFinite(number) || number <= 0) {
    return undefined;
  }
  return new RepositoryItemRef(owner, repo, Math.floor(number));
}

function targetKindFor(event: ActivityDto, target: RepositoryItemRef | undefined): RepositoryItemKind | undefined {
  if (target === undefined) {
    return undefined;
  }
  const types: string[] = [
    normalizedType(event.target_type),
    normalizedType(event.target_type_format),
    event.note === undefined ? '' : normalizedType(event.note.noteable_type)
  ];
  for (const value of types) {
    if (value.indexOf('issue') >= 0) {
      return RepositoryItemKind.Issue;
    }
    if (value.indexOf('merge-request') >= 0 || value.indexOf('pull-request') >= 0
      || value.indexOf('/merge_requests/') >= 0 || value === 'pr') {
      return RepositoryItemKind.PullRequest;
    }
  }
  const link = event._links === undefined || event._links.action_type === undefined
    ? '' : event._links.action_type;
  if (link.indexOf('/issues/') >= 0) {
    return RepositoryItemKind.Issue;
  }
  if (link.indexOf('/merge_requests/') >= 0 || link.indexOf('/pulls/') >= 0) {
    return RepositoryItemKind.PullRequest;
  }
  return undefined;
}

function activityKind(event: ActivityDto, targetKind: RepositoryItemKind | undefined): string {
  if (targetKind === RepositoryItemKind.Issue) {
    return 'issue';
  }
  if (targetKind === RepositoryItemKind.PullRequest) {
    return 'pull_request';
  }
  const action = normalizedType(event.action_name);
  const type = normalizedType(event.target_type);
  if (action.indexOf('comment') >= 0 || action.indexOf('note') >= 0 || type === 'note') {
    return 'comment';
  }
  if (event.push_data !== undefined || action.indexOf('push') >= 0) {
    return 'push';
  }
  return 'activity';
}

function activityTitle(event: ActivityDto): string {
  if (nonEmpty(event.target_title)) {
    return (event.target_title as string).trim();
  }
  if (event.push_data !== undefined && nonEmpty(event.push_data.commit_title)) {
    return (event.push_data.commit_title as string).trim();
  }
  if (nonEmpty(event.title)) {
    const title = (event.title as string).trim();
    // Repository events sometimes place an internal JSON payload in `title`.
    if (!(title.startsWith('{') && title.endsWith('}'))) {
      return title;
    }
  }
  if (event.note !== undefined && nonEmpty(event.note.body)) {
    return firstLine(event.note.body);
  }
  return 'Repository activity';
}

function actorName(event: ActivityDto): string {
  if (event.author === undefined) {
    return nonEmpty(event.author_username) ? (event.author_username as string) : 'Someone';
  }
  if (nonEmpty(event.author.username)) {
    return (event.author.username as string).trim();
  }
  if (nonEmpty(event.author.login)) {
    return (event.author.login as string).trim();
  }
  if (nonEmpty(event.author.name)) {
    return (event.author.name as string).trim();
  }
  return nonEmpty(event.author_username) ? (event.author_username as string) : 'Someone';
}

function actorAvatar(event: ActivityDto): string {
  return event.author === undefined || event.author.avatar_url === undefined
    ? '' : event.author.avatar_url;
}

function webUrlFor(event: ActivityDto): string {
  if (event._links === undefined) {
    return '';
  }
  if (nonEmpty(event._links.action_type)) {
    return event._links.action_type as string;
  }
  return nonEmpty(event._links.project) ? (event._links.project as string) : '';
}

function repositoryName(event: ActivityDto, fallback: string): string {
  if (nonEmpty(event.project_name)) {
    return (event.project_name as string).trim();
  }
  if (event._links !== undefined && nonEmpty(event._links.project)) {
    const link = event._links.project as string;
    const removeQuery = link.split('?')[0];
    const parts = removeQuery.split('/');
    if (parts.length >= 2) {
      return parts[parts.length - 2] + '/' + parts[parts.length - 1];
    }
  }
  return fallback;
}

function mapActivity(event: ActivityDto, fallbackRepository: string): ActivityItem {
  const repository = repositoryName(event, fallbackRepository);
  const parts = repositoryParts(repository);
  const owner = parts.length === 2 ? parts[0] : '';
  const repo = parts.length === 2 ? parts[1] : '';
  const target = owner.length > 0 ? targetFromEvent(event, owner, repo) : undefined;
  const kind = activityKind(event, targetKindFor(event, target));
  return new ActivityItem(
    activityId(event, repository, target),
    kind,
    activityTitle(event),
    actorName(event),
    repository,
    event.created_at === undefined ? '' : event.created_at,
    target,
    targetKindFor(event, target),
    actorAvatar(event),
    event.action_name === undefined ? '' : event.action_name,
    webUrlFor(event)
  );
}

function parseObject(res: HttpResult, endpoint: string): Object {
  let parsed: Object | Object[] | undefined = undefined;
  try {
    parsed = ArkJSON.parse(res.body) as Object | Object[];
  } catch {
    parsed = undefined;
  }
  if (parsed === undefined || parsed === null || Array.isArray(parsed)) {
    throw new ApiError(ApiErrorKind.Parse, res.status, 0, 'expected object response', '', endpoint);
  }
  return parsed as Object;
}

export class ActivityApiRepository implements ActivityRepository {
  private readonly http: HttpPort;

  constructor(http: HttpPort) {
    this.http = http;
  }

  async personalActivity(username: string, year: number, request: PageRequest,
    cancel?: CancellationSignal): Promise<Page<ActivityItem>> {
    const endpoint = '/users/' + segment(username) + '/events';
    const query: string[] = [
      kv('year', Math.floor(year))
    ];
    if (request instanceof CursorPageRequest && nonEmpty(request.cursor)) {
      query.push(kv('next', request.cursor as string));
    }
    const spec = new RequestSpec(HttpMethod.GET, endpoint, query, false, true);
    const res = await this.http.request(spec, cancel);
    const parsed = parseObject(res, endpoint) as ActivityPageDto;
    const buckets = parsed.events;
    if (buckets === undefined || buckets === null) {
      return Page.empty<ActivityItem>(request);
    }
    if (Array.isArray(buckets)) {
      throw new ApiError(ApiErrorKind.Parse, res.status, 0,
        'personal activity events must be date buckets', '', endpoint);
    }
    const dates = Object.keys(buckets).sort((a: string, b: string) => b.localeCompare(a));
    const items: ActivityItem[] = [];
    for (const date of dates) {
      const events = buckets[date];
      if (events === undefined) {
        continue;
      }
      for (const event of events) {
        items.push(mapActivity(event, ''));
      }
    }
    const cursor = request instanceof CursorPageRequest ? request.cursor : undefined;
    const next = parsed.next === undefined ? undefined
      : nextCursorRequest(request instanceof CursorPageRequest
        ? request : new CursorPageRequest(), parsed.next, items.length);
    const nextRequest = next === undefined || (request instanceof CursorPageRequest
      && cursor === parsed.next) ? undefined : next;
    return new Page<ActivityItem>(items, request, nextRequest);
  }

  async repositoryActivity(owner: string, repo: string, request: PageRequest,
    cancel?: CancellationSignal): Promise<Page<ActivityItem>> {
    if (!(request instanceof OffsetPageRequest)) {
      throw new ApiError(ApiErrorKind.Parse, 0, 0,
        'repository activity requires offset paging', '', '/repos/' + owner + '/' + repo + '/events');
    }
    const endpoint = '/repos/' + segment(owner) + '/' + segment(repo) + '/events';
    const query: string[] = [
      kv('page', request.page),
      kv('per_page', request.perPage)
    ];
    const spec = new RequestSpec(HttpMethod.GET, endpoint, query, false, true);
    const res = await this.http.request(spec, cancel);
    const parsed = parseObject(res, endpoint) as RepositoryActivityPageDto;
    const events = parsed.events;
    if (events !== undefined && !Array.isArray(events)) {
      throw new ApiError(ApiErrorKind.Parse, res.status, 0,
        'repository activity events must be an array', '', endpoint);
    }
    const items: ActivityItem[] = [];
    if (events !== undefined) {
      for (const event of events) {
        items.push(mapActivity(event, owner + '/' + repo));
      }
    }
    const rawMore = parsed.has_next_page;
    const hasMore = typeof rawMore === 'boolean' ? rawMore : typeof rawMore === 'number' && rawMore !== 0;
    return new Page<ActivityItem>(items, request,
      nextOffsetRequest(request, hasMore && items.length > 0));
  }
}

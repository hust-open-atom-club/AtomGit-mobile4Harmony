import { JSON as ArkJSON } from '@kit.ArkTS';

import { ApiError, ApiErrorKind } from '../common/ApiError';
import { fromBase64, utf8Decode } from '../common/Codec';
import { CancelToken, HttpResult } from '../network/HttpClient';
import { HttpPort } from '../network/HttpPort';
import { HttpMethod } from '../network/NetworkPolicy';
import { RequestSpec, kv } from '../network/RequestSpec';
import {
  DEFAULT_PER_PAGE,
  PagingType,
  Page,
  PagingState,
  clampPage,
  clampPerPage,
  offsetHasMore
} from '../common/Pager';
import {
  ContentsDirEntryDto,
  ContentsFileDto,
  NamespaceListItemDto,
  OrgDto,
  RepoDto,
  UserDto,
  WorkflowRunDto
} from '../model/Dtos';
import {
  CheckRun,
  CurrentUser,
  NamespaceItem,
  OrgSummary,
  RepoEntry,
  RepoFileContent,
  RepoSummary
} from '../model/Entities';
import {
  buildEntryFromPath,
  toCheckRun,
  toCurrentUser,
  toNamespaceItem,
  toOrgSummary,
  toRepoEntry,
  toRepoFileEntry,
  toRepoSummary
} from '../model/Mappers';
import { MineRepository, RepoReadRepository, SessionReadRepository, UserRepository } from './Ports';

// 实测响应：{ total_count, workflow_runs }
interface WorkflowRunsResponseDto {
  total_count?: number;
  workflow_runs?: WorkflowRunDto[];
}

function seg(s: string): string {
  return encodeURIComponent(s);
}

export class AtomGitRepository
  implements SessionReadRepository, RepoReadRepository {
  private readonly http: HttpPort;

  constructor(http: HttpPort) {
    this.http = http;
  }

  async currentUser(cancel?: CancelToken): Promise<CurrentUser> {
    const spec = new RequestSpec(HttpMethod.GET, '/user', [], false, true);
    const res = await this.http.request(spec, cancel);
    const parsed = this.parseObject(res, '/user');
    return toCurrentUser(parsed as UserDto);
  }

  // 实测返回裸数组
  async myRepos(page: number, perPage: number, cancel?: CancelToken): Promise<Page<RepoSummary>> {
    const query: string[] = [
      kv('page', clampPage(page)),
      kv('per_page', clampPerPage(perPage))
    ];
    const spec = new RequestSpec(HttpMethod.GET, '/user/repos', query, false, true);
    const res = await this.http.request(spec, cancel);
    const list = this.parseArray(res, '/user/repos');
    const repos: RepoSummary[] = [];
    for (const item of list) {
      repos.push(toRepoSummary(item as RepoDto));
    }
    const pp = clampPerPage(perPage);
    return new Page<RepoSummary>(repos, offsetHasMore(list.length, pp), PagingState.first(PagingType.Offset));
  }

  // 实测 type 为 user / group
  async myNamespaces(cancel?: CancelToken): Promise<NamespaceItem[]> {
    const spec = new RequestSpec(HttpMethod.GET, '/user/namespaces', [], false, true);
    const res = await this.http.request(spec, cancel);
    const list = this.parseArray(res, '/user/namespaces');
    const out: NamespaceItem[] = [];
    for (const item of list) {
      out.push(toNamespaceItem(item as NamespaceListItemDto));
    }
    return out;
  }

  async orgsOf(username: string, cancel?: CancelToken): Promise<OrgSummary[]> {
    const spec = new RequestSpec(HttpMethod.GET, '/users/' + seg(username) + '/orgs', [], false, true);
    const res = await this.http.request(spec, cancel);
    const list = this.parseArray(res, '/users/' + username + '/orgs');
    const out: OrgSummary[] = [];
    for (const item of list) {
      out.push(toOrgSummary(item as OrgDto));
    }
    return out;
  }

  async repoDetail(owner: string, repo: string, cancel?: CancelToken): Promise<RepoSummary> {
    const path = '/repos/' + seg(owner) + '/' + seg(repo);
    const spec = new RequestSpec(HttpMethod.GET, path, [], false, true);
    const res = await this.http.request(spec, cancel);
    const parsed = this.parseObject(res, path);
    return toRepoSummary(parsed as RepoDto);
  }

  // 目录返回数组，文件返回单对象；file_list 只有扁平字符串且 path 无效
  async listDir(owner: string, repo: string, path: string,
    cancel?: CancelToken): Promise<RepoEntry[]> {
    const full = this.joinPath(path);
    const spec = new RequestSpec(HttpMethod.GET,
      '/repos/' + seg(owner) + '/' + seg(repo) + '/contents' + full, [], false, true);
    const res = await this.http.request(spec, cancel);
    const list = this.parseArray(res, 'contents');
    const out: RepoEntry[] = [];
    for (const item of list) {
      const d = item as ContentsDirEntryDto;
      out.push(toRepoEntry(d));
    }
    return out;
  }

  // 二进制或解码失败时 decodable=false，text 为空串
  async fileContent(owner: string, repo: string, path: string,
    cancel?: CancelToken): Promise<RepoFileContent> {
    const full = this.joinPath(path);
    const spec = new RequestSpec(HttpMethod.GET,
      '/repos/' + seg(owner) + '/' + seg(repo) + '/contents' + full, [], false, true);
    const res = await this.http.request(spec, cancel);
    const parsed = this.parseObject(res, 'contents');
    const d = parsed as ContentsFileDto;
    const entry = toRepoFileEntry(d);
    const encoding = d.encoding === undefined ? '' : d.encoding;
    const raw = d.content === undefined ? '' : d.content;
    if (encoding !== 'base64' || raw.length === 0) {
      return new RepoFileContent(entry.name, entry.path, entry.size, d.html_url ?? '', '', false);
    }
    const bytes = fromBase64(raw);
    if (bytes.length === 0) {
      return new RepoFileContent(entry.name, entry.path, entry.size, d.html_url ?? '', '', false);
    }
    // README 等按 UTF-8 解码，失败回落空文本
    const text = utf8Decode(bytes);
    const printable = this.isMostlyText(bytes);
    return new RepoFileContent(entry.name, entry.path, entry.size, d.html_url ?? '',
      printable ? text : '', printable);
  }

  // file_list 只返回扁平字符串数组，path 参数不生效
  async flatFileList(owner: string, repo: string, cancel?: CancelToken): Promise<RepoEntry[]> {
    const spec = new RequestSpec(HttpMethod.GET,
      '/repos/' + seg(owner) + '/' + seg(repo) + '/file_list', [], false, true);
    const res = await this.http.request(spec, cancel);
    const list = this.parseArray(res, 'file_list');
    const out: RepoEntry[] = [];
    for (const item of list) {
      if (typeof item === 'string') {
        out.push(buildEntryFromPath(item, ''));
      }
    }
    return out;
  }

  // 实测响应被 { total_count, workflow_runs } 包裹
  async checkRuns(owner: string, repo: string, branch: string | undefined,
    page: number, perPage: number, cancel?: CancelToken): Promise<Page<CheckRun>> {
    const query: string[] = [
      kv('page', clampPage(page)),
      kv('per_page', clampPerPage(perPage))
    ];
    if (branch !== undefined && branch.length > 0) {
      query.push(kv('branch', branch));
    }
    const spec = new RequestSpec(HttpMethod.GET,
      '/repos/' + seg(owner) + '/' + seg(repo) + '/actions/runs', query, true, true);
    const res = await this.http.request(spec, cancel);
    const parsed = this.parseObject(res, 'actions/runs');
    const wrapped = parsed as WorkflowRunsResponseDto;
    const list = wrapped.workflow_runs ?? [];
    const runs: CheckRun[] = [];
    for (const item of list) {
      runs.push(toCheckRun(item as WorkflowRunDto));
    }
    const pp = clampPerPage(perPage);
    return new Page<CheckRun>(runs, offsetHasMore(list.length, pp), PagingState.first(PagingType.Offset));
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
    if (Array.isArray(parsed)) {
      throw new ApiError(ApiErrorKind.Parse, res.status, 0,
        'expected object response', '', endpoint);
    }
    return parsed as Object;
  }

  private parseOrThrow(res: HttpResult, endpoint: string): Object | Object[] {
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

  // 空路径表示根目录
  private joinPath(path: string): string {
    if (path.length === 0 || path === '/') {
      return '/';
    }
    const trimmed = path.startsWith('/') ? path.substring(1) : path;
    const encoded = seg(trimmed);
    return '/' + encoded;
  }

  // 按非零控制字节占比粗判文本
  private isMostlyText(bytes: Uint8Array): boolean {
    if (bytes.length === 0) {
      return true;
    }
    let control = 0;
    const limit = Math.min(bytes.length, 512);
    for (let i = 0; i < limit; i++) {
      const b = bytes[i];
      // 允许 \t \n \r，其余控制字符视为二进制特征
      if (b === 0 || (b < 9) || (b > 13 && b < 32)) {
        control++;
      }
    }
    return control / limit < 0.05;
  }
}

export function repoDefaultPerPage(): number {
  return DEFAULT_PER_PAGE;
}

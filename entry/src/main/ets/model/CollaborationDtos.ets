/**
 * Wire DTOs modeled on the AtomGit v5 payloads recorded in the project research
 * baseline (atomgit-cli 138a070, `internal/api/types.go` and its fixtures).
 * They stay at the network boundary; map them into CollaborationEntities.
 * Fields stay optional because AtomGit omits them per endpoint and response.
 */

export interface UserIdentityDto {
  id?: string | number;
  login?: string;
  name?: string;
  html_url?: string;
}

export interface NamespaceIdentityDto {
  id?: string | number;
  type?: string;
  name?: string;
  path?: string;
}

/** Repository object embedded in issue, comment, and notification payloads. */
export interface RepositoryIdentityDto {
  id?: string | number;
  namespace?: NamespaceIdentityDto;
  creator?: UserIdentityDto;
  full_name?: string;
  human_name?: string;
  name?: string;
  url?: string;
}

export interface LabelIdentityDto {
  id?: string | number;
  name?: string;
  color?: string;
}

/** Issue payload from `/repos/{owner}/{repo}/issues` and `/user/issues`. */
export interface IssueDto {
  id?: string | number;
  number?: string | number;
  title?: string;
  body?: string;
  state?: string;
  html_url?: string;
  created_at?: string;
  updated_at?: string;
  user?: UserIdentityDto;
  assignees?: UserIdentityDto[];
  labels?: LabelIdentityDto[];
  repository?: RepositoryIdentityDto;
}

export interface BranchIdentityDto {
  ref?: string;
  sha?: string;
}

/** Author shape returned by user and repository activity endpoints. */
export interface ActivityAuthorDto extends UserIdentityDto {
  username?: string;
  avatar_url?: string;
  web_url?: string;
  name_cn?: string;
}

export interface ActivityProjectDto {
  main_repository_language?: string[];
  star_count?: number;
  forks_count?: number;
  develop_mode?: string;
  stared?: boolean;
}

export interface ActivityPushDataDto {
  commit_count?: number;
  action?: string;
  ref_type?: string;
  commit_from?: string;
  commit_to?: string;
  ref?: string;
  commit_title?: string;
}

export interface ActivityNoteDto {
  id?: string | number;
  body?: string;
  type?: string;
  noteable_id?: string | number;
  noteable_iid?: string | number;
  noteable_type?: string;
}

export interface ActivityLinksDto {
  project?: string;
  action_type?: string;
}

/** Reviewer record returned with a pull request; `accept_status` is the readback field. */
export interface ApprovalReviewerDto {
  id?: string | number;
  login?: string;
  name?: string;
  accept_status?: string;
}

/** Pull request payload from `/repos/{owner}/{repo}/pulls` and `/user/pulls`. */
export interface PullRequestDto extends IssueDto {
  merged?: boolean;
  merged_at?: string;
  mergeable?: boolean;
  head?: BranchIdentityDto;
  base?: BranchIdentityDto;
  approval_reviewers?: ApprovalReviewerDto[];
}

/** One entry of the date-bucketed personal activity response. */
export interface ActivityDto {
  action?: number;
  action_name?: string;
  author?: ActivityAuthorDto;
  author_id?: string | number;
  author_username?: string;
  created_at?: string;
  project?: ActivityProjectDto;
  project_id?: string | number;
  project_name?: string;
  push_data?: ActivityPushDataDto;
  note?: ActivityNoteDto;
  title?: string;
  target_id?: string | number;
  target_iid?: string | number;
  target_title?: string;
  target_type?: string;
  target_type_format?: string;
  filter_sensitive?: boolean | number;
  _links?: ActivityLinksDto;
}

/** GET /users/{username}/events returns date buckets plus an opaque next cursor. */
export interface ActivityPageDto {
  events?: Record<string, ActivityDto[]>;
  next?: string;
}

/** GET /repos/{owner}/{repo}/events returns a flat page plus a continuation flag. */
export interface RepositoryActivityPageDto {
  events?: ActivityDto[];
  // The documentation says integer, while the live endpoint returns a boolean.
  has_next_page?: boolean | number;
}

/** Issue or pull request comment; review threads add the discussion fields. */
export interface CommentDto {
  id?: string | number;
  body?: string;
  html_url?: string;
  created_at?: string;
  updated_at?: string;
  user?: UserIdentityDto;
  comment_type?: string;
  discussion_id?: string;
  parent_id?: string;
  resolved?: boolean;
  is_outdated?: boolean;
  diff_file?: string;
  path?: string;
  reply?: CommentDto[];
}

/** Pull request changed-file metadata; `patch` is a nested object, not unified diff text. */
export interface PullRequestFilePatchDto {
  old_path?: string;
  new_path?: string;
  added_lines?: number;
  removed_lines?: number;
  too_large?: boolean;
  new_file?: boolean;
  renamed_file?: boolean;
  deleted_file?: boolean;
}

export interface PullRequestFileDto {
  sha?: string;
  filename?: string;
  status?: string;
  additions?: number;
  deletions?: number;
  too_large?: boolean;
  blob_url?: string;
  raw_url?: string;
  patch?: PullRequestFilePatchDto;
}

/** Repository notification payload from GET /repos/{owner}/{repo}/notifications. */
export interface NotificationDto {
  id?: string | number;
  content?: string;
  type?: string;
  unread?: boolean;
  update_at?: string;
  html_url?: string;
  actor?: UserIdentityDto;
  repository?: RepositoryIdentityDto;
}

/** Wire DTOs stay at the network boundary; map them into CollaborationEntities. */
export interface RepositoryIdentityDto { owner?: { login?: string }; full_name?: string; name?: string; }
export interface UserIdentityDto { login?: string; name?: string; }

export interface IssueDto {
  number?: number;
  title?: string;
  state?: string;
  html_url?: string;
  updated_at?: string;
  repository?: RepositoryIdentityDto;
  user?: UserIdentityDto;
}

export interface PullRequestDto extends IssueDto {
  merged?: boolean;
  draft?: boolean;
  head?: { sha?: string };
}

export interface ActivityDto {
  id?: string | number;
  type?: string;
  action?: string;
  title?: string;
  created_at?: string;
  actor?: UserIdentityDto;
  repository?: RepositoryIdentityDto;
  payload?: Object;
}

export interface CommentDto {
  id?: string | number;
  body?: string;
  html_url?: string;
  created_at?: string;
  user?: UserIdentityDto;
}

export interface NotificationDto {
  id?: string | number;
  unread?: boolean;
  subject?: { title?: string; type?: string; url?: string };
  repository?: RepositoryIdentityDto;
}

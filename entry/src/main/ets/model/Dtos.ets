// GET /api/v5/user；id 为字符串
export interface UserDto {
  id?: string;
  login?: string;
  name?: string;
  avatar_url?: string;
  html_url?: string;
  bio?: string;
  company?: string;
  email?: string;
  type?: string;
  blog?: string;
  followers?: number;
  following?: number;
}

export interface OwnerDto {
  id?: string;
  login?: string;
  name?: string;
  avatar_url?: string;
  html_url?: string;
}

// 实测 type 为 user / group
export interface NamespaceDto {
  id?: number;
  type?: string;
  name?: string;
  path?: string;
  html_url?: string;
  owner?: OwnerDto;
}

// 实测无 html_url，外链用 web_url；可见性字段为 private / internal / public
export interface RepoDto {
  id?: number;
  full_name?: string;
  human_name?: string;
  path?: string;
  name?: string;
  url?: string;
  web_url?: string;
  http_url_to_repo?: string;
  description?: string;
  status?: string;
  private?: boolean;
  public?: boolean;
  internal?: boolean;
  fork?: boolean;
  default_branch?: string;
  stargazers_count?: number;
  forks_count?: number;
  open_issues_count?: number;
  watchers_count?: number;
  readme_url?: string;
  namespace?: NamespaceDto;
  creator?: OwnerDto;
}

// GET /users/{u}/orgs
export interface OrgDto {
  id?: number;
  login?: string;
  name?: string;
  path?: string;
  html_url?: string;
  avatar_url?: string;
  description?: string;
}

// GET /api/v5/user/namespaces
export interface NamespaceListItemDto {
  id?: number;
  type?: string;
  name?: string;
  path?: string;
  html_url?: string;
}

// 目录返回数组
export interface ContentsDirEntryDto {
  type?: string;
  name?: string;
  path?: string;
  sha?: string;
  url?: string;
  html_url?: string;
}

// 文件返回对象，content 为 base64，encoding 为 'base64'
export interface ContentsFileDto {
  type?: string;
  encoding?: string;
  size?: number;
  name?: string;
  path?: string;
  sha?: string;
  url?: string;
  html_url?: string;
  content?: string;
}

// 响应被 { total_count, workflow_runs } 包裹，不能当裸数组解析
export interface WorkflowRunDto {
  id?: number;
  name?: string;
  display_title?: string;
  workflow_id?: number;
  workflow_name?: string;
  status?: string;
  conclusion?: string;
  event?: string;
  head_branch?: string;
  head_sha?: string;
  html_url?: string;
  path?: string;
  created_at?: string;
  updated_at?: string;
  run_number?: number;
  run_attempt?: number;
}

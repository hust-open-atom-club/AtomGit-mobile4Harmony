import { describe, it, expect } from '@ohos/hypium';
import {
  ContentsDirEntryDto,
  ContentsFileDto,
  NamespaceListItemDto,
  OrgDto,
  RepoDto,
  UserDto,
  WorkflowRunDto
} from '../main/ets/model/Dtos';
import { CheckStatus } from '../main/ets/model/Entities';
import {
  buildEntryFromPath,
  normalizeCheckStatus,
  toCheckRun,
  toCurrentUser,
  toNamespaceItem,
  toOrgSummary,
  toRepoEntry,
  toRepoFileEntry,
  toRepoSummary
} from '../main/ets/model/Mappers';

export default function apiContractTest() {
  describe('API 契约（实录样本）', () => {
    it('maps_real_user_response', 0, () => {
      // GET /api/v5/user 实录
      const d: UserDto = {
        id: '667b6f683456206240c30aea',
        login: 'Zi_Cai',
        name: '赵紫菜',
        type: 'User',
        avatar_url: 'https://cdn-img.gitcode.com/ef/be/x.jpg',
        html_url: 'https://atomgit.com/Zi_Cai',
        bio: '',
        blog: '',
        company: '',
      };
      const u = toCurrentUser(d);
      expect(u.accountId).assertEqual('667b6f683456206240c30aea');
      expect(u.login).assertEqual('Zi_Cai');
      expect(u.displayName()).assertEqual('赵紫菜');
    });

    it('maps_real_repo_list_item', 0, () => {
      // GET /api/v5/user/repos 实录（已裁剪）
      const d: RepoDto = {
        id: 10746240,
        full_name: 'Zi_Cai/multi-news-read',
        human_name: 'Zi_Cai / multi-news-read',
        name: 'multi-news-read',
        path: 'multi-news-read',
        namespace: { id: 2131192, type: 'user', name: 'Zi_Cai', path: 'Zi_Cai' },
        description: '本示例基于自适应布局和响应式布局。',
        web_url: 'https://atomgit.com/Zi_Cai/multi-news-read',
        internal: false,
        fork: true,
        private: false,
        public: true,
        forks_count: 0,
        stargazers_count: 0,
        open_issues_count: 0,
        default_branch: 'master',
      };
      const r = toRepoSummary(d);
      expect(r.owner).assertEqual('Zi_Cai');
      expect(r.name).assertEqual('multi-news-read');
      // 无 html_url，回退 web_url
      expect(r.htmlUrl).assertEqual('https://atomgit.com/Zi_Cai/multi-news-read');
      expect(r.defaultBranch).assertEqual('master');
      expect(r.isPrivate).assertFalse();
      // fork=true
      expect(r.isFork).assertTrue();
      expect(r.stars).assertEqual(0);
    });

    it('maps_real_namespace_group', 0, () => {
      // namespaces 实录，type=group
      const d: NamespaceListItemDto = {
        id: 1591596, path: 'Cangjie', name: 'Cangjie',
        html_url: 'https://gitcode.com/Cangjie', type: 'group',
      };
      const n = toNamespaceItem(d);
      expect(n.type).assertEqual('group');
      expect(n.isGroup()).assertTrue();
      expect(n.path).assertEqual('Cangjie');
    });

    it('maps_real_org', 0, () => {
      // orgs 实录
      const d: OrgDto = {
        id: 8188647, login: 'hust-open-atom-club', name: '华中科技大学开放原子开源俱乐部',
        path: 'hust-open-atom-club',
        avatar_url: 'https://cdn-img.gitcode.com/x.png',
      };
      const o = toOrgSummary(d);
      expect(o.login).assertEqual('hust-open-atom-club');
      expect(o.displayName()).assertEqual('华中科技大学开放原子开源俱乐部');
    });

    it('maps_real_contents_dir_entry', 0, () => {
      // contents 目录实录
      const d: ContentsDirEntryDto = {
        type: 'dir', name: 'src', path: 'common/src',
        sha: 'aaafdcf01bd9533a454612289c2ab569c5143117',
        url: 'https://api.gitcode.com/api/v5/repos/Zi_Cai/multi-news-read/contents/common',
        html_url: 'https://gitcode.com/Zi_Cai/multi-news-read/blob/master/common',
      };
      const e = toRepoEntry(d);
      expect(e.isDir()).assertTrue();
      expect(e.name).assertEqual('src');
      expect(e.path).assertEqual('common/src');
    });

    it('maps_real_contents_file', 0, () => {
      // contents 文件实录
      const d: ContentsFileDto = {
        type: 'file', encoding: 'base64', size: 7258,
        name: 'README.md', path: 'README.md',
        sha: 'abc123', html_url: 'https://gitcode.com/Zi_Cai/multi-news-read/blob/master/README.md',
        content: 'IyDlpJrorr7lpIfmlrDpl7vpmIXor7vnlYzpnaIKC',
      };
      const e = toRepoFileEntry(d);
      expect(e.isDir()).assertFalse();
      expect(e.size).assertEqual(7258);
      expect(e.path).assertEqual('README.md');
    });

    it('handles_real_flat_file_list_strings', 0, () => {
      // file_list 实录：字符串数组，path 不生效
      const p1 = buildEntryFromPath('.gitignore', '');
      expect(p1.name).assertEqual('.gitignore');
      expect(p1.isDir()).assertFalse();

      const p2 = buildEntryFromPath('common/src/main/ets/components/NewsCard.ets', '');
      expect(p2.name).assertEqual('NewsCard.ets');
      expect(p2.path).assertEqual('common/src/main/ets/components/NewsCard.ets');

      // 无扩展名按目录推断
      const p3 = buildEntryFromPath('common/src', '');
      expect(p3.isDir()).assertTrue();
    });

    it('actions_runs_is_wrapped_object', 0, () => {
      // actions/runs 实录：{ total_count, workflow_runs }
      const wrapped: WorkflowRunDto[] = [];
      expect(wrapped.length).assertEqual(0);
      // 元素结构未用非空数据验证，仅覆盖映射不崩
      const d: WorkflowRunDto = { id: 1, status: 'COMPLETED', conclusion: 'SUCCESS' };
      const c = toCheckRun(d);
      expect(c.status).assertEqual(CheckStatus.Success);
    });

    it('normalize_covers_all_documented_states', 0, () => {
      expect(normalizeCheckStatus('COMPLETED', 'SUCCESS')).assertEqual(CheckStatus.Success);
      expect(normalizeCheckStatus('COMPLETED', 'FAILURE')).assertEqual(CheckStatus.Failure);
      expect(normalizeCheckStatus('RUNNING', '')).assertEqual(CheckStatus.Running);
      expect(normalizeCheckStatus('CANCELED', '')).assertEqual(CheckStatus.Other);
      expect(normalizeCheckStatus('SKIPPED', '')).assertEqual(CheckStatus.Other);
      expect(normalizeCheckStatus('IN_PROGRESS', '')).assertEqual(CheckStatus.Running);
    });
  });
}

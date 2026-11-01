import { describe, it, expect } from '@ohos/hypium';

import { AccountGuard, accountScopedKey } from '../main/ets/security/TokenEnvelope';
import { resolveCacheScope, resolveClearPrefix } from '../main/ets/storage/CacheStore';

export default function cacheScopeTest() {
  describe('AccountCacheScope', () => {
    it('未登录时不产生任何键', 0, () => {
      const g = new AccountGuard();
      expect(resolveCacheScope(g, 'my_repos')).assertEqual(undefined);
      expect(resolveClearPrefix(g)).assertEqual(undefined);
    });

    it('已登录时键带账号前缀', 0, () => {
      const g = new AccountGuard();
      g.setAccount('acc-1');
      expect(resolveCacheScope(g, 'my_repos')).assertEqual('acc:acc-1:my_repos');
      expect(resolveClearPrefix(g)).assertEqual('acc:acc-1:');
    });

    it('换账号后键不同，旧数据不可命中', 0, () => {
      const g = new AccountGuard();
      g.setAccount('acc-old');
      const oldKey = resolveCacheScope(g, 'todos');
      g.clear();
      g.setAccount('acc-new');
      const newKey = resolveCacheScope(g, 'todos');
      expect(oldKey === newKey).assertFalse();
      expect(newKey).assertEqual('acc:acc-new:todos');
    });

    it('退出登录后立即失去作用域', 0, () => {
      const g = new AccountGuard();
      g.setAccount('acc-1');
      expect(resolveCacheScope(g, 'x') === undefined).assertFalse();
      g.clear();
      expect(resolveCacheScope(g, 'x')).assertEqual(undefined);
    });

    it('清理前缀不会误伤其他账号', 0, () => {
      const g = new AccountGuard();
      g.setAccount('a');
      const p = resolveClearPrefix(g);
      expect(p === undefined).assertFalse();
      const prefix = p === undefined ? '' : p;
      expect(prefix).assertEqual('acc:a:');
      // 'acc:ab:x' 不能被 'acc:a:' 前缀误匹配
      expect(('acc:ab:x'.indexOf(prefix) === 0)).assertFalse();
      expect(('acc:a:x'.indexOf(prefix) === 0)).assertTrue();
    });

    it('与 accountScopedKey 保持一致', 0, () => {
      const g = new AccountGuard();
      g.setAccount('acc-1');
      expect(resolveCacheScope(g, 'k')).assertEqual(accountScopedKey('acc-1', 'k'));
    });
  });
}

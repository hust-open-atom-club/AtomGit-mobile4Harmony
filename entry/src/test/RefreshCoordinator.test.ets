import { describe, it, expect } from '@ohos/hypium';

import {
  RefreshCoordinator,
  RefreshDomain,
  RefreshFilter
} from '../main/ets/common/RefreshCoordinator';

export default function refreshCoordinatorTest() {
  describe('RefreshCoordinator', () => {
    it('isolates_listener_failures_and_applies_scoped_filters', 0, () => {
      const coordinator = new RefreshCoordinator();
      let matchingEvents = 0;
      coordinator.subscribe(() => {
        throw new Error('listener failure');
      });
      coordinator.subscribe(() => {
        matchingEvents++;
      }, new RefreshFilter(RefreshDomain.Issue, 'account-a'));

      coordinator.publish(RefreshDomain.Issue, 'account-a', 'comment-confirmed');
      coordinator.publish(RefreshDomain.Issue, 'account-b', 'comment-confirmed');
      coordinator.publish(RefreshDomain.PullRequest, 'account-a', 'approval-confirmed');

      expect(matchingEvents).assertEqual(1);
    });
  });
}

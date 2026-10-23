import { describe, it, expect } from '@ohos/hypium';
import { CheckStatus } from '../main/ets/model/Entities';
import { checkStatusLabel, checkStatusTone } from '../main/ets/model/CheckStatusDisplay';

export default function checkStatusDisplayTest() {
  describe('CheckStatusDisplay', () => {
    it('labels_all_five_statuses', 0, () => {
      expect(checkStatusLabel(CheckStatus.Success)).assertEqual('成功');
      expect(checkStatusLabel(CheckStatus.Failure)).assertEqual('失败');
      expect(checkStatusLabel(CheckStatus.Running)).assertEqual('进行中');
      expect(checkStatusLabel(CheckStatus.Other)).assertEqual('已取消');
      expect(checkStatusLabel(CheckStatus.Unknown)).assertEqual('未知');
    });

    it('tones_map_to_three_colors_and_neutral', 0, () => {
      expect(checkStatusTone(CheckStatus.Success)).assertEqual('success');
      expect(checkStatusTone(CheckStatus.Failure)).assertEqual('error');
      expect(checkStatusTone(CheckStatus.Running)).assertEqual('warning');
      expect(checkStatusTone(CheckStatus.Other)).assertEqual('neutral');
      expect(checkStatusTone(CheckStatus.Unknown)).assertEqual('neutral');
    });
  });
}

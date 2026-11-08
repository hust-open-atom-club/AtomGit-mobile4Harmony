import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { Hypium } from '@ohos/hypium';

import testsuite from '../test/List.test';

const DOMAIN = 0x0000;
export default class TestAbility extends UIAbility {
  private readonly delegator: abilityDelegatorRegistry.AbilityDelegator;

  constructor() {
    super();
    this.delegator = abilityDelegatorRegistry.getAbilityDelegator();
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'AtomGitE2E', 'TestAbility created');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'AtomGitE2E', 'Failed to load E2E host: %{public}s',
          JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'AtomGitE2E', 'E2E host loaded');
      const args = abilityDelegatorRegistry.getArguments();
      hilog.info(DOMAIN, 'AtomGitE2E', 'Starting Hypium test suite');
      Hypium.hypiumTest(this.delegator, args, testsuite);
    });
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'AtomGitE2E', 'TestAbility destroyed');
  }
}

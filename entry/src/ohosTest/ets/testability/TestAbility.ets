import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class TestAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'AtomGitTest', '%{public}s', 'TestAbility onCreate');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'AtomGitTest', '%{public}s', 'TestAbility onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'AtomGitTest', 'Failed to load test content: %{public}s',
          JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'AtomGitTest', '%{public}s', 'Test content loaded');
    });
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'AtomGitTest', '%{public}s', 'TestAbility onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'AtomGitTest', '%{public}s', 'TestAbility onBackground');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'AtomGitTest', '%{public}s', 'TestAbility onDestroy');
  }
}

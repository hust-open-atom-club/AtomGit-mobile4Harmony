import { abilityDelegatorRegistry, TestRunner } from '@kit.TestKit';
import { UIAbility, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

let delegator: abilityDelegatorRegistry.AbilityDelegator | undefined = undefined;

async function onAbilityCreate(data: UIAbility): Promise<void> {
  hilog.info(0x0000, 'AtomGitE2E', 'TestAbility created');
}

function onAddMonitor(err: BusinessError): void {
  if (err !== undefined) {
    hilog.error(0x0000, 'AtomGitE2E', 'Ability monitor failed: %{public}s',
      err.message ?? '');
  }
}

export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {
    hilog.info(0x0000, 'AtomGitE2E', 'OpenHarmonyTestRunner prepared');
  }

  async onRun(): Promise<void> {
    const args = abilityDelegatorRegistry.getArguments();
    delegator = abilityDelegatorRegistry.getAbilityDelegator();
    const moduleName = args.parameters['-m'];
    const monitor: abilityDelegatorRegistry.AbilityMonitor = {
      abilityName: 'TestAbility',
      moduleName: moduleName,
      onAbilityCreate: onAbilityCreate
    };
    const want: Want = {
      bundleName: args.bundleName,
      moduleName: moduleName,
      abilityName: 'TestAbility'
    };
    try {
      await delegator.addAbilityMonitor(monitor);
      await delegator.startAbility(want);
    } catch (err) {
      onAddMonitor(err as BusinessError);
      delegator.finishTest('Unable to start TestAbility', -1, () => {
      });
    }
  }
}

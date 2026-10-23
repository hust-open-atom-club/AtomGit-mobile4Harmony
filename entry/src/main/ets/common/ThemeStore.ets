import { ConfigurationConstant } from '@kit.AbilityKit';

@ObservedV2
export class ThemeStore {
  private static shared: ThemeStore | undefined = undefined;

  static instance(): ThemeStore {
    if (ThemeStore.shared === undefined) {
      ThemeStore.shared = new ThemeStore();
    }
    return ThemeStore.shared as ThemeStore;
  }

  @Trace isDark: boolean = false;

  applyColorMode(colorMode: ConfigurationConstant.ColorMode): void {
    this.isDark = colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }
}

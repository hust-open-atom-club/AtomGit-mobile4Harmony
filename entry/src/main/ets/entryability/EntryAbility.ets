import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { Configuration } from '@ohos.app.ability.Configuration';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

import { AppContainer } from '../common/AppContainer';
import { ContainerHolder } from '../common/ContainerHolder';
import { DisplayMetrics, HeightBp, WidthBp } from '../common/DisplayMetrics';
import { ThemeStore } from '../common/ThemeStore';

const DOMAIN = 0x0000;
// AppStorage 键，须与 pages/Index.ets 一致
const CONTAINER_KEY: string = 'atomgit_container';
// setWindowSystemBarProperties 只接受 '#AARRGGBB' 字符串
const SYSTEM_BAR_CONTENT_LIGHT: string = '#FFFFFFFF';
const SYSTEM_BAR_CONTENT_DARK: string = '#FF000000';

export default class EntryAbility extends UIAbility {
  private container: AppContainer | undefined = undefined;
  private mainWindow: window.Window | undefined = undefined;
  private avoidListener: ((data: window.AvoidAreaOptions) => void) | undefined = undefined;
  private sizeListener: ((size: window.Size) => void) | undefined = undefined;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      const initialColorMode = this.context.config.colorMode;
      if (initialColorMode !== undefined) {
        ThemeStore.instance().applyColorMode(initialColorMode);
      }
    } catch (err) {
      hilog.error(DOMAIN, 'AtomGit', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    try {
      this.container = new AppContainer(this.context);
      const holder = new ContainerHolder();
      holder.container = this.container;
      AppStorage.setOrCreate<ContainerHolder>(CONTAINER_KEY, holder);
    } catch (err) {
      hilog.error(DOMAIN, 'AtomGit', 'Failed to build container: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'AtomGit', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'AtomGit', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'AtomGit', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'AtomGit', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'AtomGit', '%{public}s', 'Succeeded in loading the content.');
      try {
        const win: window.Window = windowStage.getMainWindowSync();
        this.mainWindow = win;
        this.applyImmersiveWindow(win);
      } catch (error) {
        hilog.error(DOMAIN, 'AtomGit', 'getMainWindowSync failed: %{public}s', JSON.stringify(error));
      }
    });
  }

  private applyImmersiveWindow(win: window.Window): void {
    try {
      const uiContext = win.getUIContext();
      const metrics: DisplayMetrics = DisplayMetrics.instance();

      win.setWindowLayoutFullScreen(true).then(() => {
        hilog.info(DOMAIN, 'AtomGit', '%{public}s', 'full screen layout enabled');
        this.applySystemBarStyle();
        this.maximizeOnDesktop(win);
      }).catch((error: BusinessError) => {
        hilog.error(DOMAIN, 'AtomGit', 'setWindowLayoutFullScreen failed: %{public}s', error.message);
      });

      const systemArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navArea: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      metrics.applyInsets(uiContext.px2vp(systemArea.topRect.height),
        uiContext.px2vp(navArea.bottomRect.height));

      const rect: window.Rect = win.getWindowProperties().windowRect;
      metrics.applyWidth(uiContext.px2vp(rect.width));
      metrics.applyBreakpoints(this.toWidthBp(uiContext.getWindowWidthBreakpoint()),
        this.toHeightBp(uiContext.getWindowHeightBreakpoint()));

      this.avoidListener = (data: window.AvoidAreaOptions) => {
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
          metrics.setTopInset(uiContext.px2vp(data.area.topRect.height));
        } else if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          metrics.setBottomInset(uiContext.px2vp(data.area.bottomRect.height));
        }
      };
      this.sizeListener = (size: window.Size) => {
        metrics.applyWidth(uiContext.px2vp(size.width));
        metrics.applyBreakpoints(this.toWidthBp(uiContext.getWindowWidthBreakpoint()),
          this.toHeightBp(uiContext.getWindowHeightBreakpoint()));
      };
      win.on('avoidAreaChange', this.avoidListener);
      win.on('windowSizeChange', this.sizeListener);
    } catch (err) {
      hilog.error(DOMAIN, 'AtomGit', 'applyImmersiveWindow failed: %{public}s', JSON.stringify(err));
    }
  }

  private toWidthBp(bp: WidthBreakpoint): WidthBp {
    switch (bp) {
      case WidthBreakpoint.WIDTH_XS:
        return 'xs';
      case WidthBreakpoint.WIDTH_MD:
        return 'md';
      case WidthBreakpoint.WIDTH_LG:
        return 'lg';
      case WidthBreakpoint.WIDTH_XL:
        return 'xl';
      default:
        return 'sm';
    }
  }

  private toHeightBp(bp: HeightBreakpoint): HeightBp {
    switch (bp) {
      case HeightBreakpoint.HEIGHT_SM:
        return 'sm';
      case HeightBreakpoint.HEIGHT_LG:
        return 'lg';
      default:
        return 'md';
    }
  }

  private maximizeOnDesktop(win: window.Window): void {
    try {
      const status: window.WindowStatusType = win.getWindowStatus();
      if (status !== window.WindowStatusType.FLOATING && status !== window.WindowStatusType.MAXIMIZE) {
        return;
      }
      win.setWindowDecorVisible(false);
      win.maximize().then(() => {
        hilog.info(DOMAIN, 'AtomGit', '%{public}s', 'window maximized');
      }).catch((error: BusinessError) => {
        hilog.warn(DOMAIN, 'AtomGit', 'maximize failed: %{public}s', error.message);
      });
    } catch (error) {
      hilog.warn(DOMAIN, 'AtomGit', 'maximizeOnDesktop failed: %{public}s', JSON.stringify(error));
    }
  }

  private applySystemBarStyle(): void {
    const win: window.Window | undefined = this.mainWindow;
    if (win === undefined) {
      return;
    }
    if (deviceInfo.deviceType === '2in1') {
      return;
    }
    try {
      const isDark: boolean = ThemeStore.instance().isDark;
      const contentColor: string = isDark ? SYSTEM_BAR_CONTENT_LIGHT : SYSTEM_BAR_CONTENT_DARK;
      const props: window.SystemBarProperties = {
        statusBarContentColor: contentColor,
        navigationBarContentColor: contentColor
      };
      win.setWindowSystemBarProperties(props).catch((error: BusinessError) => {
        hilog.error(DOMAIN, 'AtomGit', 'setWindowSystemBarProperties failed: %{public}s', error.message);
      });
    } catch (err) {
      hilog.error(DOMAIN, 'AtomGit', 'applySystemBarStyle failed: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    const win: window.Window | undefined = this.mainWindow;
    if (win !== undefined) {
      if (this.avoidListener !== undefined) {
        win.off('avoidAreaChange', this.avoidListener);
      }
      if (this.sizeListener !== undefined) {
        win.off('windowSizeChange', this.sizeListener);
      }
    }
    this.avoidListener = undefined;
    this.sizeListener = undefined;
    this.mainWindow = undefined;
    hilog.info(DOMAIN, 'AtomGit', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'AtomGit', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'AtomGit', '%{public}s', 'Ability onBackground');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    try {
      const colorMode = newConfig.colorMode;
      if (colorMode !== undefined) {
        ThemeStore.instance().applyColorMode(colorMode);
      }
      this.applySystemBarStyle();
    } catch (err) {
      hilog.error(DOMAIN, 'AtomGit', 'onConfigurationUpdate failed: %{public}s', JSON.stringify(err));
    }
  }
}

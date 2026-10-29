import { curves } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { DividerMode, hdsEffect, hdsMaterial, HdsNavigation, HdsTabs, HdsTabsController } from '@kit.UIDesignKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { AppContainer } from '../common/AppContainer';
import { ContainerHolder } from '../common/ContainerHolder';
import { DisplayMetrics } from '../common/DisplayMetrics';
import { Dimens, FontSize, Radius } from '../components/DesignTokens';
import { GlassCard } from '../components/GlassCard';
import { glassBorderColor } from '../components/Materials';
import { ErrorView } from '../components/StatusViews';
import { RepoBrowseStore } from '../viewmodel/RepoBrowseStore';
import { LoadState, SessionStore } from '../viewmodel/SessionStore';
import { ActivityPage } from './activity/ActivityPage';
import { NotificationPage } from './notification/NotificationPage';
import { LoginPage } from './login/LoginPage';
import { MinePage } from './mine/MinePage';
import { RepoDetailPage } from './repo/RepoDetailPage';
import { TodoPage } from './todo/TodoPage';

const HOLDER_KEY: string = 'atomgit_container';
// 仓库详情路由名，与 navDestination 注册一致
const REPO_DETAIL_ROUTE: string = 'repoDetail';

class TabSpec {
  readonly label: string;
  readonly id: string;
  readonly icon: Resource;

  constructor(label: string, id: string, icon: Resource) {
    this.label = label;
    this.id = id;
    this.icon = icon;
  }
}

@Entry
@ComponentV2
struct Index {
  private readonly tabs: TabSpec[] = [
    new TabSpec('动态', 'tab_activity', $r('sys.symbol.wave')),
    new TabSpec('待办', 'tab_todo', $r('sys.symbol.checkmark_square')),
    new TabSpec('通知', 'tab_notification', $r('sys.symbol.bell')),
    new TabSpec('我的', 'tab_mine', $r('sys.symbol.person_crop_circle_fill'))
  ];

  private readonly pathStack: NavPathStack = new NavPathStack();
  private readonly tabsController: HdsTabsController = new HdsTabsController();
  private preloaded: boolean = false;

  @Local session: SessionStore | undefined = undefined;
  @Local repoBrowse: RepoBrowseStore | undefined = undefined;
  @Local currentTab: number = 0;
  @Local bootstrapped: boolean = false;
  @Local booting: boolean = true;
  @Local bootError: string = '';
  @Local metrics: DisplayMetrics = DisplayMetrics.instance();
  @Local materialType: hdsMaterial.MaterialType = hdsMaterial.MaterialType.ADAPTIVE;
  @Local materialLevel: hdsMaterial.MaterialLevel = hdsMaterial.MaterialLevel.ADAPTIVE;

  async aboutToAppear(): Promise<void> {
    this.initMaterial();
    if (this.bootstrapped) {
      return;
    }
    this.bootstrapped = true;
    hilog.info(0x0000, 'AtomGit', 'aboutToAppear fired');
    await this.readContainer();
  }

  private initMaterial(): void {
    try {
      const types: hdsMaterial.MaterialType[] = hdsMaterial.getSystemMaterialTypes();
      if (!types.includes(hdsMaterial.MaterialType.IMMERSIVE)) {
        this.materialType = hdsMaterial.MaterialType.NONE;
        this.materialLevel = hdsMaterial.MaterialLevel.SMOOTH;
      }
    } catch (err) {
      hilog.warn(0x0000, 'AtomGit', 'material query failed: %{public}s', JSON.stringify(err));
    }
  }

  private async readContainer(): Promise<void> {
    this.booting = true;
    const holder = AppStorage.get<ContainerHolder>(HOLDER_KEY);
    const c: AppContainer | undefined = holder === undefined ? undefined : holder.container;
    if (c === undefined) {
      hilog.error(0x0000, 'AtomGit', 'container missing from AppStorage');
      this.bootError = '应用初始化失败，请重试';
      return;
    }
    this.session = c.session;
    this.repoBrowse = c.repoBrowse;
    try {
      await c.bootstrap();
    } catch (err) {
      hilog.error(0x0000, 'AtomGit', 'bootstrap failed: %{public}s',
        err instanceof Error ? err.message : String(err));
      this.bootError = '登录态恢复失败，请重试';
      this.session = undefined;
      this.repoBrowse = undefined;
    } finally {
      this.booting = false;
    }
  }

  private async retryBoot(): Promise<void> {
    this.bootError = '';
    await this.readContainer();
  }

  private async openRepo(owner: string, name: string): Promise<void> {
    const b = this.repoBrowse;
    if (b === undefined) {
      return;
    }
    await b.open(owner, name);
    if (b.state !== LoadState.Ready) {
      return;
    }
    this.pathStack.pushPathByName(REPO_DETAIL_ROUTE, owner + '/' + name);
  }

  private selectTab(index: number): void {
    if (this.currentTab === index) {
      return;
    }
    this.currentTab = index;
  }

  @Builder
  pageMap(name: string, param: object): void {
    if (name === REPO_DETAIL_ROUTE) {
      RepoDetailPage({
        store: this.repoBrowse as RepoBrowseStore,
        onBack: () => {
          this.pathStack.pop();
        }
      })
    }
  }

  @Builder
  tabItem(index: number, spec: TabSpec): void {
    Column({ space: 2 }) {
      SymbolGlyph(spec.icon)
        .fontSize(22)
        .fontColor([this.currentTab === index
          ? $r('app.color.ag_accent')
          : $r('app.color.ag_text_secondary')])
        .scale({
          x: this.currentTab === index ? 1.06 : 1,
          y: this.currentTab === index ? 1.06 : 1
        })
        .animation({ duration: 240, curve: curves.springMotion(0.4, 0.8) })
      Text(spec.label)
        .fontSize(11)
        .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentTab === index
          ? $r('app.color.ag_accent')
          : $r('app.color.ag_text_secondary'))
        .animation({ duration: 200, curve: Curve.EaseOut })
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
    .borderRadius(18)
    .backgroundColor(Color.Transparent)
    .border({
      width: this.currentTab === index ? 1 : 0,
      color: $r('app.color.ag_accent_soft')
    })
    .shadow(this.currentTab === index
      ? { radius: 14, color: $r('app.color.ag_accent_glow'), offsetX: 0, offsetY: 0 }
      : { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 })
    .visualEffect(new hdsEffect.HdsEffectBuilder()
      .pointLight({
        sourceType: this.currentTab === index
          ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.NONE,
        illuminatedType: this.currentTab === index
          ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT : hdsEffect.PointLightIlluminatedType.NONE,
        options: {
          color: $r('app.color.ag_accent'),
          intensity: this.currentTab === index ? 1.5 : 0,
          height: 24,
          bloom: this.currentTab === index ? 1.0 : 0
        }
      })
      .buildEffect())
    .animation({ duration: 240, curve: curves.springMotion(0.4, 0.8) })
    .id(spec.id)
  }

  private preloadTabs(): void {
    if (this.preloaded) {
      return;
    }
    const s: SessionStore | undefined = this.session;
    if (s === undefined || !s.loggedIn) {
      return;
    }
    try {
      this.tabsController.preloadItems([0, 1, 2, 3]).then(() => {
        this.preloaded = true;
        hilog.info(0x0000, 'AtomGit', '%{public}s', 'tabs preload done');
      }).catch((err: BusinessError) => {
        hilog.warn(0x0000, 'AtomGit', 'tabs preload failed: %{public}s', err.message);
      });
    } catch (err) {
      hilog.warn(0x0000, 'AtomGit', 'tabs preload threw: %{public}s',
        err instanceof Error ? err.message : String(err));
    }
  }

  @Builder
  tabContents(): void {
    TabContent() {
      ActivityPage()
    }
    .tabBar(this.tabItem(0, this.tabs[0]))

    TabContent() {
      TodoPage()
    }
    .tabBar(this.tabItem(1, this.tabs[1]))

    TabContent() {
      NotificationPage()
    }
    .tabBar(this.tabItem(2, this.tabs[2]))

    TabContent() {
      MinePage({
        session: this.session as SessionStore,
        onOpenRepo: (owner: string, name: string) => {
          this.openRepo(owner, name);
        }
      })
    }
    .tabBar(this.tabItem(3, this.tabs[3]))
  }

  @Builder
  sideNavItem(index: number, spec: TabSpec): void {
    Row({ space: Dimens.sm }) {
      SymbolGlyph(spec.icon)
        .fontSize(22)
        .fontColor([this.currentTab === index
          ? $r('app.color.ag_accent')
          : $r('app.color.ag_text_secondary')])
        .visualEffect(new hdsEffect.HdsEffectBuilder()
          .pointLight({
            sourceType: this.currentTab === index
              ? hdsEffect.PointLightSourceType.BRIGHT : hdsEffect.PointLightSourceType.NONE,
            illuminatedType: this.currentTab === index
              ? hdsEffect.PointLightIlluminatedType.BORDER_CONTENT : hdsEffect.PointLightIlluminatedType.NONE,
            options: {
              color: $r('app.color.ag_accent'),
              intensity: this.currentTab === index ? 1.2 : 0,
              height: 20,
              bloom: this.currentTab === index ? 0.8 : 0
            }
          })
          .buildEffect())
      Text(spec.label)
        .fontSize(FontSize.body)
        .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentTab === index
          ? $r('app.color.ag_accent')
          : $r('app.color.ag_text_primary'))
        .maxLines(1)
        .layoutWeight(1)
    }
    .width('100%')
    .height(48)
    .padding({ left: Dimens.md, right: Dimens.md })
    .borderRadius(Radius.chip)
    .backgroundColor(Color.Transparent)
    .border({
      width: this.currentTab === index ? 1 : 0,
      color: $r('app.color.ag_accent_soft')
    })
    .shadow(this.currentTab === index
      ? { radius: 14, color: $r('app.color.ag_accent_glow'), offsetX: 0, offsetY: 0 }
      : { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .onClick(() => {
      this.currentTab = index;
    })
    .id(spec.id)
  }

  @Builder
  sideNav(): void {
    Column() {
      Column() {
        Column({ space: Dimens.xs }) {
          Text('AtomGit')
            .fontSize(FontSize.headline)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ag_text_primary'))
          Text('鸿蒙原生工作台')
            .fontSize(FontSize.caption)
            .fontColor($r('app.color.ag_text_tertiary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: Dimens.md,
          right: Dimens.md,
          top: this.metrics.topInsetVp + Dimens.lg,
          bottom: Dimens.xl
        })

        ForEach(this.tabs, (spec: TabSpec, index: number) => {
          this.sideNavItem(index, spec)
        }, (spec: TabSpec) => spec.id)

        Blank()

        Column({ space: Dimens.xs }) {
          Row({ space: Dimens.xs }) {
            SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
              .fontSize(16)
              .fontColor([$r('app.color.ag_text_tertiary')])
            Text(this.session === undefined || this.session.user === undefined
              ? '' : '@' + this.session.user.login)
              .fontSize(FontSize.caption)
              .fontColor($r('app.color.ag_text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          Text('AtomGit OpenAPI v5')
            .fontSize(10)
            .fontColor($r('app.color.ag_text_tertiary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: Dimens.md,
          right: Dimens.md,
          bottom: this.metrics.bottomInsetVp + Dimens.lg
        })
      }
      .width('100%')
      .height('100%')
      .borderRadius(Radius.card + 8)
      .backgroundColor($r('app.color.ag_panel'))
      .backgroundBlurStyle(BlurStyle.BACKGROUND_REGULAR, {
        colorMode: ThemeColorMode.SYSTEM,
        adaptiveColor: AdaptiveColor.AVERAGE,
        scale: 1.0
      })
      .border({ width: 1, color: glassBorderColor() })
      .shadow({ radius: 24, color: $r('app.color.ag_glass_shadow'), offsetX: 0, offsetY: 8 })
    }
    .width(this.metrics.sideNavWidth())
    .height('100%')
    .padding({
      left: Dimens.sm,
      right: Dimens.sm,
      top: Dimens.sm,
      bottom: Dimens.sm + this.metrics.desktopDockInset()
    })
  }

  @Builder
  mainShell(): void {
    if (this.metrics.isExpanded()) {
      Row() {
        this.sideNav()

        Column() {
          if (this.currentTab === 0) {
            ActivityPage()
          } else if (this.currentTab === 1) {
            TodoPage()
          } else if (this.currentTab === 2) {
            NotificationPage()
          } else {
            MinePage({
              session: this.session as SessionStore,
              onOpenRepo: (owner: string, name: string) => {
                this.openRepo(owner, name);
              }
            })
          }
        }
        .layoutWeight(1)
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    } else {
      HdsTabs({
        barPosition: BarPosition.End,
        index: this.currentTab,
        controller: this.tabsController
      }) {
        this.tabContents()
      }
      .barOverlap(true)
      .vertical(false)
      .scrollable(false)
      .barFloatingStyle({
        barWidth: {
          smallWidth: 294,
          mediumWidth: 328,
          largeWidth: 328
        },
        barBottomMargin: this.metrics.bottomInsetVp + (this.metrics.isCompact() ? 16 : 8),
        adaptToHandedness: true,
        lightColor: $r('app.color.ag_accent'),
        systemMaterialEffect: {
          materialType: this.materialType,
          materialLevel: this.materialLevel
        }
      })
      .onChange((index: number) => {
        this.currentTab = index;
      })
      .onAppear(() => {
        this.preloadTabs();
      })
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }

  @Builder
  bootView(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: Dimens.md }) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color($r('app.color.ag_accent'))
        Text('正在初始化…')
          .fontSize(FontSize.body)
          .fontColor($r('app.color.ag_text_secondary'))
      }
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.metrics.topInsetVp })
    .backgroundColor($r('app.color.ag_background'))
    .id('boot_loading')
  }

  @Builder
  errorView(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        GlassCard({ radius: Radius.card + Dimens.sm }) {
          ErrorView({
            message: this.bootError,
            viewId: 'boot_error',
            retryable: true,
            onRetry: () => {
              this.retryBoot();
            }
          })
        }
      }
      .padding({ left: Dimens.lg, right: Dimens.lg })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.metrics.topInsetVp })
    .backgroundColor($r('app.color.ag_background'))
  }

  build() {
    HdsNavigation(this.pathStack) {
      if (this.bootError.length > 0) {
        this.errorView()
      } else if (this.booting || this.session === undefined) {
        this.bootView()
      } else if (!this.session.loggedIn) {
        LoginPage({
          session: this.session as SessionStore,
          onLoggedIn: () => {
            this.currentTab = 0;
          }
        })
          .width('100%')
          .height('100%')
      } else {
        this.mainShell()
      }
    }
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.pageMap)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ag_background'))
  }
}

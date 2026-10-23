import { curves, LengthMetrics, uiMaterial } from '@kit.ArkUI';
import {
  hdsMaterial,
  HdsListItemCard,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  PrefixIcon,
  ScrollEffectType,
  SuffixArrow,
  SuffixText
} from '@kit.UIDesignKit';

import { CheckRun, RepoEntry } from '../../model/Entities';
import { checkStatusLabel, checkStatusTone } from '../../model/CheckStatusDisplay';
import { EmptyRepoBrowseStore } from '../../viewmodel/EmptyRepoBrowseStore';
import { RepoBrowseStore } from '../../viewmodel/RepoBrowseStore';
import { DisplayMetrics } from '../../common/DisplayMetrics';
import { ThemeStore } from '../../common/ThemeStore';
import { Dimens, FontSize, Radius } from '../../components/DesignTokens';
import { RepoMetaChips } from '../../components/RepoMetaChips';
import { glassMaterial, glassOrBackground } from '../../components/Materials';
import { EmptyView, ErrorView, toneColor } from '../../components/StatusViews';

const SEGMENT_TRANSITION: TransitionEffect =
  TransitionEffect.OPACITY
    .combine(TransitionEffect.translate({ y: 12 }))
    .animation({ duration: 240, curve: Curve.EaseOut });

const SEGMENT_LABELS: string[] = ['README', '文件', '流水线'];
const SEGMENT_IDS: string[] = ['repo_tab_readme', 'repo_tab_files', 'repo_tab_ci'];

@ComponentV2
export struct RepoDetailPage {
  @Param store: RepoBrowseStore = new EmptyRepoBrowseStore();
  @Param onBack: () => void = () => {};

  @Local currentTab: number = 0;

  @Local theme: ThemeStore = ThemeStore.instance();
  @Local glass: uiMaterial.Material | undefined = undefined;
  @Local metrics: DisplayMetrics = DisplayMetrics.instance();

  private readonly readmeScroller: Scroller = new Scroller();
  private readonly filesScroller: Scroller = new Scroller();
  private readonly ciScroller: Scroller = new Scroller();

  private readonly spring: AnimateParam = { curve: curves.springMotion(0.4, 0.8) };

  aboutToAppear(): void {
    this.glass = glassMaterial(uiMaterial.ImmersiveStyle.THIN, this.theme.isDark);
    if (this.metrics.isExpanded() && this.currentTab === 1) {
      this.currentTab = 0;
    }
  }

  @Monitor('theme.isDark')
  onThemeChange(): void {
    this.glass = glassMaterial(uiMaterial.ImmersiveStyle.THIN, this.theme.isDark);
  }

  private async pickEntry(e: RepoEntry): Promise<void> {
    if (e.isDir()) {
      await this.store.enterDir(e.path);
      return;
    }
    await this.store.openFile(e.path);
    this.currentTab = 0;
  }

  private handleBack(): void {
    this.store.goUp().then((moved: boolean) => {
      if (!moved) {
        this.onBack();
      }
    });
  }

  private entrySymbol(e: RepoEntry): Resource {
    return e.isDir() ? $r('sys.symbol.folder') : $r('sys.symbol.doc_text');
  }

  @Builder
  repoSummary(): void {
    if (this.store.repo !== undefined) {
      Column({ space: Dimens.md }) {
        Text(this.store.repo.fullName)
          .fontSize(FontSize.headline)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor($r('app.color.ag_text_primary'))
        if (this.store.repo.description.length > 0) {
          Text(this.store.repo.description)
            .fontSize(FontSize.body)
            .width('100%')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .ellipsisMode(EllipsisMode.MULTILINE_CENTER)
            .fontColor($r('app.color.ag_text_secondary'))
        }
        RepoMetaChips({ repo: this.store.repo })
      }
      .width('100%')
      .padding(Dimens.lg)
      .borderRadius(Radius.card)
      .backgroundColor($r('app.color.ag_surface'))
      .border({ width: 1, color: $r('app.color.ag_card_border') })
    }
  }

  @Builder
  renderReadme(): void {
    Column() {
      if (!this.metrics.isExpanded()) {
        Column() {
          this.repoSummary()
        }
        .padding({ left: Dimens.lg, right: Dimens.lg, top: Dimens.md })
      }

      if (this.store.file !== undefined) {
        if (this.store.file.decodable) {
          Scroll(this.readmeScroller) {
            Text(this.store.file.text)
              .fontSize(13)
              .lineHeight(20)
              .width('100%')
              .padding(Dimens.lg)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .id('repo_readme_text')
        } else {
          Text('该文件不是可显示的文本')
            .fontSize(FontSize.body)
            .fontColor($r('app.color.ag_text_secondary'))
            .padding(Dimens.lg)
        }
      } else {
        EmptyView({ text: '选择文件查看内容' })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .transition(SEGMENT_TRANSITION)
  }

  @Builder
  renderFiles(): void {
    Column() {
      if (this.store.entries.length === 0) {
        EmptyView({ text: '空目录' })
      } else {
        List({ scroller: this.filesScroller }) {
          ForEach(this.store.entries, (e: RepoEntry) => {
            ListItem() {
              HdsListItemCard({
                prefixItem: new PrefixIcon({
                  iconValue: { symbol: this.entrySymbol(e) }
                }),
                textItem: {
                  primaryText: { text: e.name },
                  secondaryText: { text: e.isDir() ? '目录' : '文件' }
                },
                suffixItem: e.isDir()
                  ? new SuffixArrow()
                  : new SuffixText({ text: e.size.toString() + ' B' }),
                cardHeight: 62,
                cardBorderRadius: Radius.chip,
                cardBackgroundColor: Color.Transparent,
                onClick: () => {
                  this.pickEntry(e);
                }
              })
              .width('100%')
            }
          }, (e: RepoEntry) => e.path)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .padding({ left: Dimens.sm, right: Dimens.sm })
        .id('repo_files_list')
      }
    }
    .width('100%')
    .layoutWeight(1)
    .transition(SEGMENT_TRANSITION)
  }

  @Builder
  renderChecks(): void {
    Column() {
      if (this.store.checks.length === 0) {
        EmptyView({ text: '暂无流水线记录', viewId: 'repo_ci_empty' })
      } else {
        List({ scroller: this.ciScroller }) {
          ForEach(this.store.checks, (c: CheckRun) => {
            ListItem() {
              Row({ space: Dimens.md }) {
                SymbolGlyph($r('sys.symbol.circle_fill'))
                  .fontSize(10)
                  .fontColor([toneColor(checkStatusTone(c.status))])
                Column({ space: 3 }) {
                  Text(c.name)
                    .fontSize(FontSize.bodyLarge)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .fontColor($r('app.color.ag_text_primary'))
                  Text(c.branch + ' · ' + checkStatusLabel(c.status))
                    .fontSize(FontSize.caption)
                    .fontColor($r('app.color.ag_text_secondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding({ left: Dimens.md, right: Dimens.md, top: Dimens.md, bottom: Dimens.md })
              .borderRadius(Radius.chip)
              .backgroundColor($r('app.color.ag_surface'))
              .margin({ left: Dimens.sm, right: Dimens.sm, top: Dimens.xs })
            }
          }, (c: CheckRun) => c.id.toString())
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .id('repo_ci_list')
      }
    }
    .width('100%')
    .layoutWeight(1)
    .transition(SEGMENT_TRANSITION)
  }

  @Builder
  segmentItem(i: number): void {
    Text(SEGMENT_LABELS[i])
      .fontSize(FontSize.body)
      .fontWeight(this.currentTab === i ? FontWeight.Medium : FontWeight.Regular)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .fontColor(this.currentTab === i
        ? $r('app.color.ag_text_on_accent')
        : $r('app.color.ag_text_secondary'))
      .padding({ top: Dimens.sm + 2, bottom: Dimens.sm + 2 })
      .borderRadius(Radius.chip)
      .backgroundColor(this.currentTab === i
        ? $r('app.color.ag_accent')
        : Color.Transparent)
      .animation(this.spring)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.96 })
      .onClick(() => {
        this.currentTab = i;
      })
      .id(SEGMENT_IDS[i])
  }

  @Builder
  segmentBar(): void {
    Row({ space: Dimens.xs }) {
      if (this.metrics.isExpanded()) {
        this.segmentItem(0)
        this.segmentItem(2)
      } else {
        this.segmentItem(0)
        this.segmentItem(1)
        this.segmentItem(2)
      }
    }
    .width('100%')
    .padding(Dimens.xs)
    .borderRadius(Radius.chip + Dimens.xs)
    .margin({
      left: this.metrics.isExpanded() ? 0 : Dimens.lg,
      right: this.metrics.isExpanded() ? 0 : Dimens.lg,
      top: Dimens.sm,
      bottom: Dimens.sm
    })
    .backgroundColor(glassOrBackground(this.glass))
    .systemMaterial(this.glass)
  }

  @Builder
  renderContent(): void {
    if (this.currentTab === 0) {
      this.renderReadme()
    } else if (this.currentTab === 1) {
      this.renderFiles()
    } else {
      this.renderChecks()
    }
  }

  build() {
    HdsNavDestination() {
      Column() {
        Blank()
          .width('100%')
          .height(this.metrics.topInsetVp + 56)
        if (this.store.errorMessage.length > 0) {
          ErrorView({
            message: this.store.errorMessage,
            viewId: 'repo_error'
          })
        }

        if (this.metrics.isExpanded()) {
          Row() {
            Column() {
              this.repoSummary()
              Column() {
                this.renderFiles()
              }
              .layoutWeight(1)
              .margin({ top: Dimens.sm })
            }
            .width(340)
            .height('100%')
            .padding({ left: Dimens.lg, right: Dimens.sm, top: Dimens.md })

            Divider()
              .vertical(true)
              .height('100%')
              .color($r('app.color.ag_separator'))

            Column() {
              this.segmentBar()
              Column() {
                this.renderContent()
              }
              .width('100%')
              .layoutWeight(1)
            }
            .layoutWeight(1)
            .height('100%')
            .padding({ left: Dimens.sm, right: Dimens.lg, top: Dimens.md })
          }
          .width('100%')
          .height('100%')
          .layoutWeight(1)
          .padding({
            left: this.metrics.pagePadding(),
            right: this.metrics.pagePadding(),
            bottom: this.metrics.desktopDockInset()
          })
        } else {
          this.segmentBar()
          Column() {
            this.renderContent()
          }
          .width('100%')
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.ag_background'))
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(0)
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
      content: {
        title: {
          mainTitle: this.store.rootLabel(),
          mainTitleId: 'repo_title'
        }
      }
    })
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.readmeScroller, this.filesScroller, this.ciScroller])
    .onBackPressed(() => {
      this.handleBack();
      return true;
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .width('100%')
    .height('100%')
  }
}

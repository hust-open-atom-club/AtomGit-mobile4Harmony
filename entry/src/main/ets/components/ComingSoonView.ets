import { DisplayMetrics } from '../common/DisplayMetrics';
import { Dimens, Elevation, FontSize, Motion, Radius } from './DesignTokens';
import { TAB_BAR_CONTENT_INSET } from './NavigationMetrics';

@ComponentV2
export struct ComingSoonView {
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param symbol: Resource = $r('sys.symbol.wave');
  @Param viewId: string = '';
  @Param features: string[] = [];
  @Param apiHint: string = '';

  @Local metrics: DisplayMetrics = DisplayMetrics.instance();
  @Local appeared: boolean = false;

  aboutToAppear(): void {
    this.getUIContext().animateTo({ duration: Motion.slow, curve: Curve.Friction }, () => {
      this.appeared = true;
    });
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .width(240)
        .height(240)
        .fill($r('app.color.ag_hero_orb'))
        .opacity(0.55)
        .blur(60)
        .offset({ x: 120, y: -220 })

      Column({ space: Dimens.lg }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(72)
            .height(72)
            .fill($r('app.color.ag_accent_soft'))
          SymbolGlyph(this.symbol)
            .fontSize(34)
            .fontColor([$r('app.color.ag_accent')])
        }

        Text('协作模块 · 规划中')
          .fontSize(FontSize.caption)
          .fontColor($r('app.color.ag_accent'))
          .fontWeight(FontWeight.Medium)
          .padding({ left: Dimens.md, right: Dimens.md, top: 5, bottom: 5 })
          .borderRadius(Radius.chip)
          .backgroundColor($r('app.color.ag_accent_soft'))

        Text(this.title)
          .fontSize(FontSize.display)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ag_text_primary'))
          .textAlign(TextAlign.Center)

        Text(this.subtitle)
          .fontSize(FontSize.body)
          .fontColor($r('app.color.ag_text_secondary'))
          .textAlign(TextAlign.Center)
          .maxLines(3)

        if (this.features.length > 0) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
            ForEach(this.features, (feature: string) => {
              Text(feature)
                .fontSize(FontSize.caption)
                .fontColor($r('app.color.ag_text_secondary'))
                .padding({ left: Dimens.md, right: Dimens.md, top: 6, bottom: 6 })
                .margin(Dimens.xs)
                .borderRadius(Radius.chip)
                .border({ width: 1, color: $r('app.color.ag_separator') })
            }, (feature: string) => feature)
          }
          .width('100%')
        }

        if (this.apiHint.length > 0) {
          Row({ space: Dimens.xs }) {
            SymbolGlyph($r('sys.symbol.circle_fill'))
              .fontSize(7)
              .fontColor([$r('app.color.ag_success')])
            Text(this.apiHint)
              .fontSize(FontSize.caption)
              .fontColor($r('app.color.ag_text_tertiary'))
          }
          .padding({ top: Dimens.sm })
        }
      }
      .width('86%')
      .constraintSize({ maxWidth: 420 })
      .padding({ left: Dimens.xxl, right: Dimens.xxl, top: Dimens.xxl, bottom: Dimens.xxl })
      .borderRadius(Radius.card + 8)
      .backgroundColor($r('app.color.ag_surface'))
      .border({ width: 1, color: $r('app.color.ag_card_border') })
      .shadow({ radius: Elevation.hero, color: $r('app.color.ag_glass_shadow'), offsetX: 0, offsetY: 8 })
      .opacity(this.appeared ? 1 : 0)
      .translate({ y: this.appeared ? 0 : 12 })
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.metrics.topInsetVp,
      bottom: TAB_BAR_CONTENT_INSET + this.metrics.bottomInsetVp + this.metrics.desktopDockInset() + Dimens.sm
    })
    .linearGradient({
      angle: 180,
      colors: [[$r('app.color.ag_hero_start'), 0], [$r('app.color.ag_background'), 0.55]]
    })
    .id(this.viewId)
  }
}

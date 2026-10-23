import { StatusTone } from '../model/CheckStatusDisplay';
import { Dimens, FontSize } from './DesignTokens';

export function toneColor(tone: StatusTone): ResourceColor {
  if (tone === 'success') {
    return $r('app.color.ag_success');
  }
  if (tone === 'error') {
    return $r('app.color.ag_error');
  }
  if (tone === 'warning') {
    return $r('app.color.ag_warning');
  }
  return $r('app.color.ag_text_secondary');
}

const STATUS_APPEAR: TransitionEffect =
  TransitionEffect.OPACITY
    .combine(TransitionEffect.translate({ y: 8 }))
    .animation({ duration: 220, curve: Curve.EaseOut });

@ComponentV2
export struct LoadingView {
  @Param text: string = '加载中…';

  build() {
    Text(this.text)
      .fontSize(14)
      .fontColor($r('app.color.ag_text_tertiary'))
      .width('100%')
      .padding(16)
      .transition(STATUS_APPEAR)
  }
}

@ComponentV2
export struct EmptyView {
  @Param text: string = '暂无内容';
  @Param viewId: string = '';
  @Param symbol: Resource | undefined = undefined;

  build() {
    Column({ space: this.symbol === undefined ? 0 : Dimens.sm }) {
      if (this.symbol !== undefined) {
        SymbolGlyph(this.symbol)
          .fontSize(30)
          .fontColor([$r('app.color.ag_text_tertiary')])
      }
      Text(this.text)
        .fontSize(FontSize.body)
        .fontColor($r('app.color.ag_text_tertiary'))
        .width('100%')
        .textAlign(this.symbol === undefined ? TextAlign.Start : TextAlign.Center)
    }
    .width('100%')
    .padding({
      left: Dimens.lg,
      right: Dimens.lg,
      top: this.symbol === undefined ? Dimens.lg : Dimens.xxl,
      bottom: this.symbol === undefined ? Dimens.lg : Dimens.xxl
    })
    .alignItems(this.symbol === undefined ? HorizontalAlign.Start : HorizontalAlign.Center)
    .transition(STATUS_APPEAR)
    .id(this.viewId)
  }
}

@ComponentV2
export struct ErrorView {
  @Param message: string = '';
  @Param viewId: string = '';
  @Param fontSize: number = 13;
  @Param padH: number = 16;
  @Param padV: number = 6;
  @Param retryable: boolean = false;
  @Param onRetry: () => void = () => {};
  @Param symbol: Resource | undefined = undefined;

  build() {
    Column({ space: Dimens.sm }) {
      Row({ space: Dimens.xs }) {
        if (this.symbol !== undefined) {
          SymbolGlyph(this.symbol)
            .fontSize(this.fontSize + 4)
            .fontColor([$r('app.color.ag_error')])
        }
        Text(this.message)
          .fontSize(this.fontSize)
          .fontColor($r('app.color.ag_error'))
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.retryable) {
        Button('重试')
          .fontSize(13)
          .height(32)
          .backgroundColor($r('app.color.ag_background'))
          .fontColor($r('app.color.ag_accent'))
          .onClick(() => {
            this.onRetry();
          })
      }
    }
    .width('100%')
    .padding({ left: this.padH, right: this.padH, top: this.padV, bottom: this.padV })
    .transition(STATUS_APPEAR)
    .id(this.viewId)
  }
}

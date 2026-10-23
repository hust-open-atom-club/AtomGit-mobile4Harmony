import { uiMaterial } from '@kit.ArkUI';

import { ThemeStore } from '../common/ThemeStore';
import { Dimens, Elevation, Radius } from './DesignTokens';
import { glassBorderColor, glassMaterial, glassOrBackground } from './Materials';

@Builder
function glassCardEmpty(): void {
}

@ComponentV2
export struct GlassCard {
  @BuilderParam content: () => void = glassCardEmpty;
  @Param radius: number = Radius.card;
  @Param style: uiMaterial.ImmersiveStyle = uiMaterial.ImmersiveStyle.REGULAR;
  @Param cardPadding: Padding = {
    left: Dimens.lg, right: Dimens.lg, top: Dimens.lg, bottom: Dimens.lg
  };
  @Param elevated: boolean = true;

  @Local theme: ThemeStore = ThemeStore.instance();
  @Local glass: uiMaterial.Material | undefined = undefined;

  aboutToAppear(): void {
    this.glass = glassMaterial(this.style, this.theme.isDark);
  }

  @Monitor('theme.isDark')
  onThemeChange(): void {
    this.glass = glassMaterial(this.style, this.theme.isDark);
  }

  private cardShadow(): ShadowOptions {
    if (!this.elevated) {
      return { radius: 0, color: Color.Transparent, offsetX: 0, offsetY: 0 };
    }
    return {
      radius: Elevation.card,
      color: $r('app.color.ag_glass_shadow'),
      offsetX: 0,
      offsetY: 8
    };
  }

  private cardBorderColor(): ResourceColor {
    return this.glass === undefined ? $r('app.color.ag_card_border') : glassBorderColor();
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .borderRadius(this.radius)
    .padding(this.cardPadding)
    .backgroundColor(glassOrBackground(this.glass))
    .border({ width: 1, color: this.cardBorderColor() })
    .shadow(this.cardShadow())
    .systemMaterial(this.glass)
  }
}

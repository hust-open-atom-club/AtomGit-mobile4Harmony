import { DisplayMetrics } from '../../common/DisplayMetrics';
import { snack } from '../../common/Toast';
import { hdsEffect } from '@kit.UIDesignKit';
import { EmptySessionStore } from '../../viewmodel/EmptySessionStore';
import { SessionStore } from '../../viewmodel/SessionStore';
import { Dimens, FontSize, Radius } from '../../components/DesignTokens';
import { GlassCard } from '../../components/GlassCard';
import { ErrorView } from '../../components/StatusViews';

@ComponentV2
export struct LoginPage {
  @Param session: SessionStore = new EmptySessionStore();
  @Param onLoggedIn: () => void = () => {};

  @Local input: string = '';
  @Local submitting: boolean = false;
  @Local metrics: DisplayMetrics = DisplayMetrics.instance();
  @Local appeared: boolean = false;

  aboutToAppear(): void {
    this.getUIContext().animateTo({ duration: 420, curve: Curve.Friction }, () => {
      this.appeared = true;
    });
  }

  private async submit(): Promise<void> {
    if (this.session === undefined || this.session === null) {
      snack(this.getUIContext(), '初始化未完成，请稍后重试');
      return;
    }
    if (this.submitting) {
      return;
    }
    if (this.input.trim().length === 0) {
      snack(this.getUIContext(), '请输入访问令牌');
      return;
    }
    this.submitting = true;
    const ok: boolean = await this.session.login(this.input);
    this.submitting = false;
    if (ok) {
      this.input = '';
      this.onLoggedIn();
    } else {
      snack(this.getUIContext(), '登录失败，请检查令牌');
    }
  }

  @Builder
  brandHeader(): void {
    Column({ space: Dimens.md }) {
      Stack({ alignContent: Alignment.Center }) {
        Rect()
          .width(68)
          .height(68)
          .radius(22)
          .fill($r('app.color.ag_accent'))
          .shadow({
            radius: 20,
            color: $r('app.color.ag_accent_glow'),
            offsetX: 0,
            offsetY: 10
          })
        Text('A')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ag_text_on_accent'))
      }

      Text('AtomGit')
        .fontSize(FontSize.display + 6)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ag_text_primary'))

      Text('鸿蒙原生工作台')
        .fontSize(FontSize.body)
        .fontColor($r('app.color.ag_text_secondary'))
        .letterSpacing(1)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .opacity(this.appeared ? 1 : 0)
    .translate({ y: this.appeared ? 0 : 18 })
    .animation({ duration: 420, curve: Curve.Friction })
  }

  @Builder
  tokenCard(): void {
    Column() {
      GlassCard({
        cardPadding: {
          left: Dimens.xl, right: Dimens.xl, top: Dimens.xl, bottom: Dimens.xl
        }
      }) {
        Column({ space: Dimens.lg }) {
          Text('使用个人访问令牌（PAT）登录')
            .fontSize(FontSize.title)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ag_text_primary'))
            .width('100%')

          TextInput({ placeholder: '粘贴访问令牌', text: this.input })
            .type(InputType.Password)
            .showPasswordIcon(true)
            .enterKeyType(EnterKeyType.Done)
            .height(48)
            .borderRadius(Radius.chip)
            .backgroundColor($r('app.color.ag_surface_sunken'))
            .border({ width: 1, color: $r('app.color.ag_card_border') })
            .padding({ left: Dimens.md, right: Dimens.md })
            .enabled(!this.submitting)
            .onChange((v: string) => {
              this.input = v;
            })
            .onSubmit(() => {
              this.submit();
            })
            .id('login_token_input')

          Button() {
            Row({ space: Dimens.sm }) {
              if (this.submitting) {
                LoadingProgress()
                  .width(18)
                  .height(18)
                  .color($r('app.color.ag_text_on_accent'))
              }
              Text(this.submitting ? '登录中…' : '登录')
                .fontSize(FontSize.title)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.ag_text_on_accent'))
            }
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height(48)
          .borderRadius(Radius.chip + 2)
          .linearGradient({
            angle: 90,
            colors: [[$r('app.color.ag_accent'), 0], [$r('app.color.ag_accent_strong'), 1]]
          })
          .enabled(!this.submitting)
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
          .visualEffect(new hdsEffect.HdsEffectBuilder()
            .pressShadow(hdsEffect.PressShadowType.BLEND_WHITE)
            .buildEffect())
          .onClick(() => {
            this.submit();
          })
          .id('login_submit')

          if (this.session.errorMessage.length > 0) {
            ErrorView({
              message: this.session.errorMessage,
              viewId: 'login_error',
              fontSize: FontSize.body,
              padH: 0,
              padV: 0
            })
          }
        }
        .width('100%')
      }
    }
    .width('100%')
    .opacity(this.appeared ? 1 : 0)
    .translate({ y: this.appeared ? 0 : 28 })
    .animation({ duration: 420, delay: 90, curve: Curve.Friction })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Circle()
        .width(280)
        .height(280)
        .fill($r('app.color.ag_hero_orb'))
        .opacity(0.6)
        .blur(64)
        .offset({ x: 180, y: -120 })

      Scroll() {
        Column() {
          Column({ space: Dimens.xl }) {
            this.brandHeader()
            this.tokenCard()

            Row({ space: Dimens.xs }) {
              SymbolGlyph($r('sys.symbol.lock_fill'))
                .fontSize(13)
                .fontColor([$r('app.color.ag_text_tertiary')])
              Text('令牌经系统资产库加密保存，密钥不与密文同存')
                .fontSize(FontSize.caption)
                .fontColor($r('app.color.ag_text_tertiary'))
            }
            .width('100%')

            Text('获取方式：atomgit.com → 设置 → 访问令牌')
              .fontSize(FontSize.caption)
              .fontColor($r('app.color.ag_text_tertiary'))
              .width('100%')
          }
          .width('100%')
          .constraintSize({ maxWidth: 460 })
          .padding({ left: Dimens.xxl, right: Dimens.xxl })
          .margin({ top: this.metrics.topInsetVp + 56, bottom: this.metrics.bottomInsetVp + this.metrics.desktopDockInset() + 32 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 160,
      colors: [[$r('app.color.ag_hero_start'), 0], [$r('app.color.ag_background'), 0.6]]
    })
  }
}

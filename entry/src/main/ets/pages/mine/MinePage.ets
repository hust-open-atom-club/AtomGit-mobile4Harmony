import {
  HdsListItemCard,
  PrefixIcon,
  SuffixArrow,
  SuffixText
} from '@kit.UIDesignKit';

import { DisplayMetrics } from '../../common/DisplayMetrics';
import { snack, toast } from '../../common/Toast';
import { EmptySessionStore } from '../../viewmodel/EmptySessionStore';
import { LoadState, SessionStore } from '../../viewmodel/SessionStore';
import { OrgSummary, RepoSummary } from '../../model/Entities';
import { Dimens, FontSize, Motion, Radius } from '../../components/DesignTokens';
import { EmptyView, ErrorView } from '../../components/StatusViews';
import { TAB_BAR_CONTENT_INSET } from '../../components/NavigationMetrics';

@ComponentV2
export struct MinePage {
  @Param session: SessionStore = new EmptySessionStore();
  @Param onOpenRepo: (owner: string, name: string) => void = () => {};

  @Local loggingOut: boolean = false;
  @Local metrics: DisplayMetrics = DisplayMetrics.instance();
  @Local appeared: boolean = false;

  aboutToAppear(): void {
    this.getUIContext().animateTo({ duration: Motion.slow, curve: Curve.Friction }, () => {
      this.appeared = true;
    });
  }

  private displayName(): string {
    const user = this.session.user;
    return user === undefined ? '' : user.displayName();
  }

  private login(): string {
    const user = this.session.user;
    return user === undefined ? '' : user.login;
  }

  private initial(): string {
    const name = this.displayName();
    return name.length > 0 ? name.substring(0, 1).toUpperCase() : 'A';
  }

  private bio(): string {
    const user = this.session.user;
    return user === undefined ? '' : user.bio;
  }

  private async logout(): Promise<void> {
    if (this.loggingOut) {
      return;
    }
    this.loggingOut = true;
    await this.session.logout();
    this.loggingOut = false;
    toast('已退出登录');
  }

  private openRepo(r: RepoSummary): void {
    this.onOpenRepo(r.owner, r.name);
  }

  @Builder
  statChip(label: string, kind: string): void {
    Row({ space: Dimens.xs }) {
      Text(kind === 'repos' ? this.session.repos.length.toString() : this.session.orgs.length.toString())
        .fontSize(FontSize.title)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ag_text_primary'))
      Text(label)
        .fontSize(FontSize.caption)
        .fontColor($r('app.color.ag_text_secondary'))
    }
    .padding({ left: Dimens.md, right: Dimens.md, top: 6, bottom: 6 })
    .borderRadius(Radius.chip + 2)
    .backgroundColor($r('app.color.ag_chip_bg'))
  }

  @Builder
  hero(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      Circle()
        .width(180)
        .height(180)
        .fill($r('app.color.ag_hero_orb'))
        .opacity(0.62)
        .blur(44)
        .offset({ x: 220, y: -70 })

      Column({ space: Dimens.lg }) {
        Row({ space: Dimens.md }) {
          Stack({ alignContent: Alignment.Center }) {
            Circle()
              .width(58)
              .height(58)
              .fill($r('app.color.ag_accent_soft'))
            Text(this.initial())
              .fontSize(FontSize.headline)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ag_accent'))
          }

          Column({ space: Dimens.xs }) {
            Text(this.displayName())
              .fontSize(FontSize.headline)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.ag_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .id('mine_display_name')
            Text('@' + this.login())
              .fontSize(FontSize.body)
              .fontColor($r('app.color.ag_text_secondary'))
              .maxLines(1)
              .id('mine_login')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
            .fontSize(22)
            .fontColor([$r('app.color.ag_accent')])
        }
        .width('100%')

        if (this.bio().length > 0) {
          Text(this.bio())
            .fontSize(FontSize.body)
            .fontColor($r('app.color.ag_text_secondary'))
            .width('100%')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .ellipsisMode(EllipsisMode.MULTILINE_CENTER)
        }

        Row({ space: Dimens.sm }) {
          this.statChip('项目', 'repos')
          this.statChip('组织', 'orgs')
          Blank()
          Text('API v5')
            .fontSize(FontSize.caption)
            .fontColor($r('app.color.ag_text_tertiary'))
        }
        .width('100%')
      }
      .width('100%')
      .padding(Dimens.xl)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .borderRadius(Radius.card + Dimens.xs)
    .clip(true)
    .linearGradient({
      angle: 135,
      colors: [[$r('app.color.ag_hero_start'), 0], [$r('app.color.ag_hero_end'), 1]]
    })
    .border({ width: 1, color: $r('app.color.ag_card_border') })
  }

  @Builder
  sectionHeader(title: string, kind: string): void {
    Row() {
      Text(title)
        .fontSize(FontSize.title)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ag_text_primary'))
      Blank()
      Text(kind === 'repos' ? this.session.repos.length.toString() : this.session.orgs.length.toString())
        .fontSize(FontSize.caption)
        .fontColor($r('app.color.ag_text_tertiary'))
    }
    .width('100%')
    .padding({ left: Dimens.xs, right: Dimens.xs, top: Dimens.md, bottom: Dimens.xs })
  }

  @Builder
  repoCard(r: RepoSummary): void {
    Column({ space: Dimens.xs }) {
      Row({ space: Dimens.xs }) {
        Text(r.displayName.length > 0 ? r.displayName : r.name)
          .fontSize(FontSize.title)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ag_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (r.isPrivate) {
          SymbolGlyph($r('sys.symbol.lock_fill'))
            .fontSize(12)
            .fontColor([$r('app.color.ag_text_tertiary')])
        }
        Text('★ ' + r.stars.toString())
          .fontSize(FontSize.caption)
          .fontColor($r('app.color.ag_text_tertiary'))
      }
      .width('100%')

      Text(r.description.length > 0 ? r.description : '暂无描述')
        .fontSize(FontSize.caption)
        .fontColor($r('app.color.ag_text_secondary'))
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .ellipsisMode(EllipsisMode.MULTILINE_CENTER)
        .height(34)
        .align(Alignment.TopStart)

      Blank()

      Row({ space: Dimens.xs }) {
        SymbolGlyph($r('sys.symbol.folder'))
          .fontSize(11)
          .fontColor([$r('app.color.ag_text_tertiary')])
        Text(r.owner + ' / ' + r.name)
          .fontSize(10)
          .fontColor($r('app.color.ag_text_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text('Issue ' + r.openIssues.toString())
          .fontSize(10)
          .fontColor($r('app.color.ag_text_tertiary'))
      }
      .width('100%')
    }
    .width('100%')
    .height(128)
    .padding(Dimens.md)
    .borderRadius(Radius.card)
    .backgroundColor($r('app.color.ag_surface'))
    .border({ width: 1, color: $r('app.color.ag_card_border') })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.985 })
    .onClick(() => {
      this.openRepo(r);
    })
  }

  @Builder
  orgCard(o: OrgSummary): void {
    HdsListItemCard({
      prefixItem: new PrefixIcon({
        iconValue: { symbol: $r('sys.symbol.folder') }
      }),
      textItem: {
        primaryText: { text: o.displayName() },
        secondaryText: { text: o.login }
      },
      suffixItem: new SuffixArrow(),
      cardHeight: 62,
      cardBorderRadius: Radius.chip,
      cardBackgroundColor: $r('app.color.ag_surface')
    })
    .width('100%')
  }

  @Builder
  loadMoreRow(): void {
    Button(this.session.hasMoreRepos ? '加载更多项目' : '已全部加载')
      .fontSize(FontSize.body)
      .width('100%')
      .height(44)
      .borderRadius(Radius.chip + 2)
      .backgroundColor($r('app.color.ag_surface'))
      .border({ width: 1, color: $r('app.color.ag_card_border') })
      .fontColor(this.session.hasMoreRepos
        ? $r('app.color.ag_accent')
        : $r('app.color.ag_text_tertiary'))
      .enabled(this.session.state !== LoadState.Loading)
      .onClick(() => {
        if (this.session.hasMoreRepos) {
          this.session.loadRepos();
        } else {
          snack(this.getUIContext(), '已全部加载');
        }
      })
  }

  @Builder
  logoutButton(): void {
    Button() {
      Row({ space: Dimens.sm }) {
        SymbolGlyph($r('sys.symbol.arrow_up_right'))
          .fontSize(18)
          .fontColor([$r('app.color.ag_error')])
        Text(this.loggingOut ? '退出中…' : '退出登录')
          .fontSize(FontSize.body)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ag_error'))
      }
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(48)
    .borderRadius(Radius.chip + 2)
    .backgroundColor($r('app.color.ag_surface'))
    .border({ width: 1, color: $r('app.color.ag_card_border') })
    .enabled(!this.loggingOut)
    .onClick(() => {
      this.logout();
    })
    .id('mine_logout')
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      List({ space: Dimens.sm }) {
        ListItem() {
          this.hero()
        }
        .margin({ top: this.metrics.topInsetVp + Dimens.sm })

        if (this.session.errorMessage.length > 0) {
          ListItem() {
            ErrorView({ message: this.session.errorMessage, viewId: 'mine_error' })
          }
        }

        ListItem() {
          this.sectionHeader('我的项目', 'repos')
        }

        if (this.session.repos.length === 0) {
          ListItem() {
            EmptyView({
              text: '暂无项目',
              viewId: 'mine_repos_empty',
              symbol: $r('sys.symbol.folder')
            })
          }
        } else {
          ListItem() {
            GridRow({
              columns: { sm: 4, md: 8, lg: 12 },
              gutter: { x: Dimens.md, y: Dimens.md }
            }) {
              ForEach(this.session.repos, (r: RepoSummary) => {
                GridCol({ span: { sm: 4, md: 4, lg: 4 } }) {
                  this.repoCard(r)
                }
              }, (r: RepoSummary) => r.fullName + r.id.toString())
            }
            .width('100%')
          }

          ListItem() {
            this.loadMoreRow()
          }
        }

        if (this.session.orgs.length > 0) {
          ListItem() {
            this.sectionHeader('我的组织', 'orgs')
          }

          ListItem() {
            GridRow({
              columns: { sm: 4, md: 8, lg: 12 },
              gutter: { x: Dimens.md, y: Dimens.md }
            }) {
              ForEach(this.session.orgs, (o: OrgSummary) => {
                GridCol({ span: { sm: 4, md: 4, lg: 4 } }) {
                  this.orgCard(o)
                }
              }, (o: OrgSummary) => o.login)
            }
            .width('100%')
          }
        }

        ListItem() {
          this.logoutButton()
        }
        .margin({
          top: Dimens.lg,
          bottom: TAB_BAR_CONTENT_INSET + this.metrics.bottomInsetVp + this.metrics.desktopDockInset() + Dimens.sm
        })
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: this.metrics.contentMaxWidth() })
      .padding({ left: this.metrics.pagePadding(), right: this.metrics.pagePadding() })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd(() => {
        if (this.session.state !== LoadState.Loading && this.session.hasMoreRepos) {
          this.session.loadRepos();
        }
      })
      .id('mine_repos_list')
      .backgroundColor($r('app.color.ag_background'))
    }
    .width('100%')
    .height('100%')
  }
}

import { DisplayMetrics } from '../../common/DisplayMetrics';
import { EmptySessionStore } from '../../viewmodel/EmptySessionStore';
import {
  ActivityDay,
  ActivitySource,
  ActivityStore,
  EmptyActivityStore
} from '../../viewmodel/ActivityStore';
import { LoadState, SessionStore } from '../../viewmodel/SessionStore';
import {
  activityActionLabel,
  activityClock,
  activityKindLabel,
  actorInitial
} from '../../model/ActivityDisplay';
import { ActivityItem } from '../../model/CollaborationEntities';
import { RepoSummary } from '../../model/Entities';
import { Dimens, FontSize, Motion, Radius } from '../../components/DesignTokens';
import { TAB_BAR_CONTENT_INSET } from '../../components/NavigationMetrics';
import { EmptyView, ErrorView } from '../../components/StatusViews';

@ComponentV2
export struct ActivityPage {
  @Param store: ActivityStore = new EmptyActivityStore();
  @Param session: SessionStore = new EmptySessionStore();
  @Param onOpenRepo: (owner: string, name: string) => void = () => {};

  @Local refreshing: boolean = false;
  @Local metrics: DisplayMetrics = DisplayMetrics.instance();
  @Local appeared: boolean = false;

  aboutToAppear(): void {
    this.getUIContext().animateTo({ duration: Motion.slow, curve: Curve.Friction }, () => {
      this.appeared = true;
    });
    this.initialize();
  }

  aboutToDisappear(): void {
    this.store.cancelPending();
  }

  @Monitor('session.repos.length')
  onReposChanged(): void {
    this.syncSession();
    if (this.store.source === ActivitySource.Project) {
      this.openProjects();
    }
  }

  private syncSession(): void {
    const user = this.session.user;
    if (user === undefined) {
      return;
    }
    this.store.initialize(user.accountId, user.login, this.session.repos);
  }

  private initialize(): Promise<void> {
    this.syncSession();
    if (this.session.user === undefined) {
      return Promise.resolve();
    }
    if (this.store.source === ActivitySource.Project) {
      const project = this.store.selectedProject();
      if (project !== undefined) {
        return this.store.openProject(project.owner, project.name);
      }
    }
    return this.store.openPersonal();
  }

  private async openPersonal(): Promise<void> {
    await this.store.openPersonal();
  }

  private async openProjects(): Promise<void> {
    this.syncSession();
    await this.store.openProjects();
  }

  private async openProject(repo: RepoSummary): Promise<void> {
    this.syncSession();
    await this.store.openProject(repo.owner, repo.name);
  }

  private async refresh(): Promise<void> {
    this.refreshing = true;
    await this.store.refresh();
    this.refreshing = false;
  }

  private async loadMore(): Promise<void> {
    if (this.store.loadingMore) {
      return;
    }
    await this.store.loadMore();
  }

  private openItem(item: ActivityItem): void {
    if (item.target !== undefined) {
      this.onOpenRepo(item.target.owner, item.target.repo);
      return;
    }
    const slash = item.repository.indexOf('/');
    if (slash > 0 && slash < item.repository.length - 1) {
      this.onOpenRepo(item.repository.substring(0, slash),
        item.repository.substring(slash + 1));
    }
  }

  private itemSymbol(item: ActivityItem): Resource {
    if (item.kind === 'pull_request') {
      return $r('sys.symbol.checkmark_square');
    }
    if (item.kind === 'push') {
      return $r('sys.symbol.arrow_up_right');
    }
    if (item.kind === 'issue' || item.kind === 'comment') {
      return $r('sys.symbol.doc_text');
    }
    return $r('sys.symbol.wave');
  }

  private projectKey(repo: RepoSummary): string {
    return repo.owner + '/' + repo.name;
  }

  @Builder
  sourceTab(source: ActivitySource, label: string): void {
    Text(label)
      .fontSize(FontSize.body)
      .fontWeight(this.store.source === source ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.store.source === source
        ? $r('app.color.ag_text_on_accent')
        : $r('app.color.ag_text_secondary'))
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .padding({ top: Dimens.sm, bottom: Dimens.sm })
      .borderRadius(Radius.chip)
      .backgroundColor(this.store.source === source
        ? $r('app.color.ag_accent')
        : Color.Transparent)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
      .onClick(() => {
        if (source === ActivitySource.Personal) {
          this.openPersonal();
        } else {
          this.openProjects();
        }
      })
      .id(source === ActivitySource.Personal ? 'activity_source_personal' : 'activity_source_projects')
  }

  @Builder
  header(): void {
    Column({ space: Dimens.md }) {
      Row({ space: Dimens.md }) {
        Column({ space: 2 }) {
          Text('Activity')
            .fontSize(FontSize.headline)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ag_text_primary'))
          Text(this.session.user === undefined ? '' : '@' + this.session.user.login)
            .fontSize(FontSize.caption)
            .fontColor($r('app.color.ag_text_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.arrow_up_right'))
            .fontSize(17)
            .fontColor([$r('app.color.ag_accent')])
            .rotate({ angle: -45 })
        }
        .width(38)
        .height(38)
        .backgroundColor($r('app.color.ag_accent_soft'))
        .onClick(() => {
          this.refresh();
        })
        .enabled(this.store.state !== LoadState.Loading
          && this.store.state !== LoadState.Refreshing)
        .id('activity_refresh')
      }
      .width('100%')

      Row() {
        this.sourceTab(ActivitySource.Personal, 'Mine')
        this.sourceTab(ActivitySource.Project, 'Projects')
      }
      .width('100%')
      .padding(3)
      .borderRadius(Radius.chip + 2)
      .backgroundColor($r('app.color.ag_chip_bg'))

      if (this.store.source === ActivitySource.Project && this.store.projects.length > 0) {
        List({ space: Dimens.sm }) {
          ForEach(this.store.projects, (repo: RepoSummary) => {
            ListItem() {
              Text(repo.fullName)
                .fontSize(FontSize.caption)
                .fontColor(this.store.selectedProjectKey === this.projectKey(repo)
                  ? $r('app.color.ag_accent')
                  : $r('app.color.ag_text_secondary'))
                .fontWeight(this.store.selectedProjectKey === this.projectKey(repo)
                  ? FontWeight.Medium : FontWeight.Regular)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .padding({ left: Dimens.md, right: Dimens.md, top: 7, bottom: 7 })
                .borderRadius(Radius.chip)
                .border({
                  width: 1,
                  color: this.store.selectedProjectKey === this.projectKey(repo)
                    ? $r('app.color.ag_accent_soft')
                    : $r('app.color.ag_separator')
                })
                .backgroundColor(this.store.selectedProjectKey === this.projectKey(repo)
                  ? $r('app.color.ag_accent_soft')
                  : Color.Transparent)
                .onClick(() => {
                  this.openProject(repo);
                })
            }
          }, (repo: RepoSummary) => repo.owner + '/' + repo.name)
        }
        .listDirection(Axis.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(38)
        .id('activity_project_selector')
      }

      Row({ space: Dimens.xs }) {
        Text(this.store.lastUpdatedAt.length > 0
          ? 'Updated ' + this.store.lastUpdatedAt
          : 'Recent events')
          .fontSize(10)
          .fontColor($r('app.color.ag_text_tertiary'))
        Blank()
        if (this.store.source === ActivitySource.Project && this.store.selectedProject() !== undefined) {
          Text('Selected project only')
            .fontSize(10)
            .fontColor($r('app.color.ag_text_tertiary'))
            .maxLines(1)
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: Dimens.lg, right: Dimens.lg, top: Dimens.md, bottom: Dimens.sm })
    .opacity(this.appeared ? 1 : 0)
    .translate({ y: this.appeared ? 0 : 8 })
  }

  @Builder
  avatar(item: ActivityItem): void {
    Stack({ alignContent: Alignment.Center }) {
      Text(actorInitial(item))
        .fontSize(FontSize.body)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ag_accent'))
      if (item.actorAvatarUrl.length > 0) {
        Image(item.actorAvatarUrl)
          .width(34)
          .height(34)
          .borderRadius(17)
          .objectFit(ImageFit.Cover)
      }
    }
    .width(34)
    .height(34)
    .borderRadius(17)
    .backgroundColor($r('app.color.ag_accent_soft'))
    .clip(true)
  }

  @Builder
  activityRow(item: ActivityItem): void {
    Row({ space: Dimens.md }) {
      this.avatar(item)

      Column({ space: 5 }) {
        Row({ space: 5 }) {
          Text(item.actor)
            .fontSize(FontSize.body)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ag_text_primary'))
            .maxLines(1)
          Text(activityActionLabel(item))
            .fontSize(FontSize.body)
            .fontColor($r('app.color.ag_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')

        Text(item.title)
          .fontSize(FontSize.bodyLarge)
          .fontColor($r('app.color.ag_text_primary'))
          .width('100%')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .ellipsisMode(EllipsisMode.MULTILINE_CENTER)

        Row({ space: 6 }) {
          Row({ space: 3 }) {
            SymbolGlyph(this.itemSymbol(item))
              .fontSize(11)
              .fontColor([$r('app.color.ag_accent')])
            Text(activityKindLabel(item))
              .fontSize(10)
              .fontColor($r('app.color.ag_accent'))
          }
          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .borderRadius(Radius.chip)
          .backgroundColor($r('app.color.ag_accent_soft'))

          Text(item.repository)
            .fontSize(10)
            .fontColor($r('app.color.ag_text_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(activityClock(item.createdAt))
            .fontSize(10)
            .fontColor($r('app.color.ag_text_tertiary'))
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.arrow_up_right'))
        .fontSize(13)
        .fontColor([$r('app.color.ag_text_tertiary')])
        .rotate({ angle: 45 })
    }
    .width('100%')
    .padding({ left: Dimens.md, right: Dimens.md, top: Dimens.md, bottom: Dimens.md })
    .borderRadius(Radius.card)
    .backgroundColor($r('app.color.ag_surface'))
    .border({ width: 1, color: $r('app.color.ag_card_border') })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.99 })
    .onClick(() => {
      this.openItem(item);
    })
  }

  @Builder
  feedItems(): void {
    if (this.store.state === LoadState.Loading && this.store.items.length === 0) {
      ListItem() {
        Row({ space: Dimens.sm }) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color($r('app.color.ag_accent'))
          Text('Loading activity')
            .fontSize(FontSize.body)
            .fontColor($r('app.color.ag_text_secondary'))
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: Dimens.xxl, bottom: Dimens.xxl })
      }
    } else if (this.store.state === LoadState.Error && this.store.items.length === 0) {
      ListItem() {
        ErrorView({
          message: this.store.errorMessage,
          retryable: true,
          onRetry: () => {
            this.store.retry();
          },
          viewId: 'activity_error'
        })
      }
    } else if (this.store.source === ActivitySource.Project && !this.store.hasProjects()) {
      ListItem() {
        EmptyView({
          text: 'No accessible projects',
          symbol: $r('sys.symbol.folder'),
          viewId: 'activity_no_projects'
        })
      }
    } else if (this.store.items.length === 0) {
      ListItem() {
        EmptyView({
          text: this.store.source === ActivitySource.Personal
            ? 'No recent activity for this account'
            : 'No recent activity for this project',
          symbol: $r('sys.symbol.wave'),
          viewId: 'activity_empty'
        })
      }
    } else {
      if (this.store.errorMessage.length > 0) {
        ListItem() {
          ErrorView({
            message: this.store.errorMessage,
            retryable: true,
            onRetry: () => {
              this.store.retry();
            },
            viewId: 'activity_partial_error'
          })
        }
      }

      ForEach(this.store.days, (day: ActivityDay) => {
        ListItem() {
          Text(day.label)
            .fontSize(FontSize.caption)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ag_text_secondary'))
            .width('100%')
            .padding({ left: Dimens.xs, top: Dimens.sm, bottom: Dimens.xs })
        }
        ForEach(day.items, (item: ActivityItem) => {
          ListItem() {
            this.activityRow(item)
          }
          .padding({ bottom: Dimens.sm })
        }, (item: ActivityItem) => item.id)
      }, (day: ActivityDay) => day.key)

      ListItem() {
        if (this.store.loadingMore) {
          Row({ space: Dimens.sm }) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color($r('app.color.ag_accent'))
            Text('Loading more')
              .fontSize(FontSize.caption)
              .fontColor($r('app.color.ag_text_tertiary'))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding(Dimens.md)
        } else if (this.store.hasMore) {
          Button('Load more')
            .fontSize(FontSize.caption)
            .height(34)
            .backgroundColor($r('app.color.ag_accent_soft'))
            .fontColor($r('app.color.ag_accent'))
            .onClick(() => {
              this.loadMore();
            })
            .id('activity_load_more')
        } else {
          Text('You are all caught up')
            .fontSize(10)
            .fontColor($r('app.color.ag_text_tertiary'))
            .padding({ top: Dimens.md, bottom: Dimens.xl })
            .id('activity_end')
        }
      }
    }
  }

  build() {
    Column() {
      this.header()

      Refresh({ refreshing: this.refreshing }) {
        List() {
          this.feedItems()
        }
        .width('100%')
        .height('100%')
        .padding({ left: Dimens.lg, right: Dimens.lg, bottom: Dimens.md })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onReachEnd(() => {
          this.loadMore();
        })
        .id('activity_list')
      }
      .layoutWeight(1)
      .width('100%')
      .onRefreshing(() => {
        this.refresh();
      })
      .id('activity_refresh_container')
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.metrics.topInsetVp,
      bottom: TAB_BAR_CONTENT_INSET + this.metrics.bottomInsetVp
        + this.metrics.desktopDockInset() + Dimens.sm
    })
    .linearGradient({
      angle: 180,
      colors: [[$r('app.color.ag_hero_start'), 0], [$r('app.color.ag_background'), 0.45]]
    })
    .id('activity_page')
  }
}

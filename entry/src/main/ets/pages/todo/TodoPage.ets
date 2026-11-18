import { DisplayMetrics } from '../../common/DisplayMetrics';
import { EmptySessionStore } from '../../viewmodel/EmptySessionStore';
import { EmptyTodoStore, TodoCategory, TodoScope, TodoStore, scopesForCategory }
  from '../../viewmodel/TodoStore';
import { SessionStore } from '../../viewmodel/SessionStore';
import { RepositoryItemKind, WorkItem } from '../../model/CollaborationEntities';
import { Dimens, FontSize, Motion, Radius } from '../../components/DesignTokens';
import { TAB_BAR_CONTENT_INSET } from '../../components/NavigationMetrics';
import { EmptyView, ErrorView } from '../../components/StatusViews';
import { GlassCard } from '../../components/GlassCard';

@ComponentV2
export struct TodoPage {
  @Param store: TodoStore = new EmptyTodoStore();
  @Param session: SessionStore = new EmptySessionStore();
  @Param onOpenItem: (workItem: WorkItem) => void = () => {};

  @Local category: TodoCategory = TodoCategory.Pending;
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

  @Monitor('session.user')
  onAccountChanged(): void {
    this.initialize();
  }

  private initialize(): void {
    const user = this.session.user;
    this.store.initialize(user === undefined ? '' : user.accountId);
    if (user !== undefined) {
      this.store.loadAll();
    }
  }

  private async refresh(): Promise<void> {
    this.refreshing = true;
    await this.store.refresh();
    this.refreshing = false;
  }

  private async loadMoreAtEnd(): Promise<void> {
    for (const scope of scopesForCategory(this.category)) {
      await this.store.loadMore(scope);
    }
  }

  private categoryLabel(category: TodoCategory): string {
    return category === TodoCategory.Pending ? 'To handle' : 'Created by me';
  }

  private scopeLabel(scope: TodoScope): string {
    switch (scope) {
      case TodoScope.AssignedIssues:
        return 'Issues assigned to me';
      case TodoScope.AssignedPullRequests:
        return 'Pull requests assigned to me';
      case TodoScope.NeedsApprovalPullRequests:
        return 'Pull requests awaiting my approval';
      case TodoScope.NeedsReviewPullRequests:
        return 'Pull requests awaiting my review';
      case TodoScope.CreatedIssues:
        return 'Issues I created';
      default:
        return 'Pull requests I created';
    }
  }

  private emptyText(scope: TodoScope): string {
    switch (scope) {
      case TodoScope.AssignedIssues:
        return 'No open issues are assigned to you';
      case TodoScope.AssignedPullRequests:
        return 'No open pull requests are assigned to you';
      case TodoScope.NeedsApprovalPullRequests:
        return 'No pull requests are awaiting your approval';
      case TodoScope.NeedsReviewPullRequests:
        return 'No pull requests are awaiting your review';
      case TodoScope.CreatedIssues:
        return 'You have no open issues';
      default:
        return 'You have no open pull requests';
    }
  }

  private scopeSymbol(scope: TodoScope): Resource {
    if (scope === TodoScope.AssignedIssues || scope === TodoScope.CreatedIssues) {
      return $r('sys.symbol.doc_text');
    }
    return $r('sys.symbol.checkmark_square');
  }

  private itemType(item: WorkItem): string {
    return item.kind === RepositoryItemKind.Issue ? 'Issue' : 'Pull request';
  }

  private itemSymbol(item: WorkItem): Resource {
    return item.kind === RepositoryItemKind.Issue
      ? $r('sys.symbol.doc_text') : $r('sys.symbol.checkmark_square');
  }

  private updatedText(value: string): string {
    if (value.length === 0) {
      return 'Update time unavailable';
    }
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      return 'Update time unavailable';
    }
    const names: string[] = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[date.getMonth()] + ' ' + date.getDate().toString() + ', '
      + date.getFullYear().toString() + ' ' + this.pad(date.getHours()) + ':'
      + this.pad(date.getMinutes());
  }

  private pad(value: number): string {
    return value < 10 ? '0' + value.toString() : value.toString();
  }

  @Builder
  categoryTab(category: TodoCategory): void {
    Column({ space: 2 }) {
      Text(this.categoryLabel(category))
        .fontSize(FontSize.body)
        .fontWeight(this.category === category ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.category === category
          ? $r('app.color.ag_text_on_accent') : $r('app.color.ag_text_secondary'))
      Text(this.store.categoryLoadedCount(category).toString() + ' loaded')
        .fontSize(10)
        .fontColor(this.category === category
          ? $r('app.color.ag_text_on_accent') : $r('app.color.ag_text_tertiary'))
    }
    .layoutWeight(1)
    .padding({ top: Dimens.sm, bottom: Dimens.sm })
    .borderRadius(Radius.chip)
    .backgroundColor(this.category === category ? $r('app.color.ag_accent') : Color.Transparent)
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.97 })
    .onClick(() => {
      this.category = category;
    })
    .id('todo_category_' + category)
  }

  @Builder
  header(): void {
    Column({ space: Dimens.md }) {
      Row({ space: Dimens.md }) {
        Column({ space: 2 }) {
          Text('Todo workspace')
            .fontSize(FontSize.headline)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.ag_text_primary'))
          Text(this.session.user === undefined ? '' : '@' + this.session.user.login)
            .fontSize(FontSize.caption)
            .fontColor($r('app.color.ag_text_tertiary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.store.categoryLoadedCount(this.category).toString() + ' loaded')
          .fontSize(FontSize.caption)
          .fontColor($r('app.color.ag_text_secondary'))
          .padding({ left: Dimens.sm, right: Dimens.sm, top: 5, bottom: 5 })
          .borderRadius(Radius.chip)
          .backgroundColor($r('app.color.ag_accent_soft'))
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: Dimens.xs }) {
        this.categoryTab(TodoCategory.Pending)
        this.categoryTab(TodoCategory.Created)
      }
      .width('100%')
      .padding(Dimens.xs)
      .borderRadius(Radius.chip)
      .backgroundColor($r('app.color.ag_surface'))
      .border({ width: 1, color: $r('app.color.ag_card_border') })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: Dimens.lg, right: Dimens.lg, top: Dimens.md, bottom: Dimens.md })
  }

  @Builder
  retryButton(scope: TodoScope): void {
    Button('Retry')
      .fontSize(FontSize.caption)
      .height(32)
      .backgroundColor($r('app.color.ag_accent_soft'))
      .fontColor($r('app.color.ag_accent'))
      .onClick(() => {
        this.store.retry(scope);
      })
      .id('todo_retry_' + scope)
  }

  @Builder
  itemRow(item: WorkItem): void {
    Row({ space: Dimens.md }) {
      Column() {
        SymbolGlyph(this.itemSymbol(item))
          .fontSize(19)
          .fontColor([$r('app.color.ag_accent')])
      }
      .width(36)
      .height(36)
      .justifyContent(FlexAlign.Center)
      .borderRadius(Radius.chip)
      .backgroundColor($r('app.color.ag_accent_soft'))

      Column({ space: 5 }) {
        Text(item.title)
          .fontSize(FontSize.bodyLarge)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ag_text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(item.ref.owner + '/' + item.ref.repo)
          .fontSize(FontSize.caption)
          .fontColor($r('app.color.ag_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Row({ space: Dimens.sm }) {
          Text(this.itemType(item))
            .fontSize(10)
            .fontColor($r('app.color.ag_accent'))
          Text('#' + item.ref.number.toString())
            .fontSize(10)
            .fontColor($r('app.color.ag_text_tertiary'))
          Text(item.state)
            .fontSize(10)
            .fontColor($r('app.color.ag_text_secondary'))
          Text(this.updatedText(item.updatedAt))
            .fontSize(10)
            .fontColor($r('app.color.ag_text_tertiary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: Dimens.md, bottom: Dimens.md })
    .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.99 })
    .onClick(() => {
      this.onOpenItem(item);
    })
  }

  @Builder
  scopeSection(scope: TodoScope): void {
    GlassCard({
      radius: Radius.card,
      elevated: false,
      cardPadding: { left: Dimens.md, right: Dimens.md, top: Dimens.md, bottom: Dimens.md }
    }) {
      Column({ space: Dimens.xs }) {
        Row({ space: Dimens.sm }) {
          SymbolGlyph(this.scopeSymbol(scope))
            .fontSize(17)
            .fontColor([$r('app.color.ag_text_secondary')])
          Text(this.scopeLabel(scope))
            .fontSize(FontSize.bodyLarge)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ag_text_primary'))
            .layoutWeight(1)
          Text(this.store.scopeCountText(scope))
            .fontSize(10)
            .fontColor($r('app.color.ag_text_tertiary'))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (this.store.stateFor(scope).loading && this.store.stateFor(scope).items.length === 0) {
          Row({ space: Dimens.sm }) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color($r('app.color.ag_accent'))
            Text('Loading ' + this.scopeLabel(scope).toLowerCase())
              .fontSize(FontSize.caption)
              .fontColor($r('app.color.ag_text_secondary'))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: Dimens.xl, bottom: Dimens.xl })
        } else if (this.store.stateFor(scope).errorMessage.length > 0
          && this.store.stateFor(scope).items.length === 0) {
          Column({ space: Dimens.sm }) {
            ErrorView({
              message: this.store.stateFor(scope).errorMessage,
              viewId: 'todo_error_' + scope
            })
            this.retryButton(scope)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        } else if (this.store.stateFor(scope).items.length === 0) {
          EmptyView({
            text: this.emptyText(scope),
            symbol: this.scopeSymbol(scope),
            viewId: 'todo_empty_' + scope
          })
        } else {
          if (this.store.stateFor(scope).errorMessage.length > 0) {
            Row({ space: Dimens.sm }) {
              ErrorView({
                message: this.store.stateFor(scope).errorMessage,
                viewId: 'todo_partial_error_' + scope
              })
              .layoutWeight(1)
              this.retryButton(scope)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }

          ForEach(this.store.stateFor(scope).items, (item: WorkItem) => {
            Column() {
              Divider()
                .color($r('app.color.ag_separator'))
              this.itemRow(item)
            }
            .width('100%')
          }, (item: WorkItem) => item.kind + '|' + item.ref.key())

          if (this.store.stateFor(scope).loadingMore) {
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
            .padding({ top: Dimens.sm, bottom: Dimens.sm })
          } else if (this.store.stateFor(scope).hasMore) {
            Button('Load more')
              .fontSize(FontSize.caption)
              .height(32)
              .backgroundColor($r('app.color.ag_accent_soft'))
              .fontColor($r('app.color.ag_accent'))
              .onClick(() => {
                this.store.loadMore(scope);
              })
              .id('todo_load_more_' + scope)
          } else {
            Text('End of loaded items')
              .fontSize(10)
              .fontColor($r('app.color.ag_text_tertiary'))
              .padding({ top: Dimens.xs, bottom: Dimens.xs })
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  partialFailureNotice(): void {
    if (this.store.failedScopeCount(this.category) > 0) {
      Row({ space: Dimens.sm }) {
        SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
          .fontSize(16)
          .fontColor([$r('app.color.ag_warning')])
        Text(this.store.failedScopeCount(this.category).toString()
          + (this.store.failedScopeCount(this.category) === 1
            ? ' source could not be loaded' : ' sources could not be loaded'))
          .fontSize(FontSize.caption)
          .fontColor($r('app.color.ag_text_secondary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding(Dimens.md)
      .borderRadius(Radius.chip)
      .backgroundColor($r('app.color.ag_surface'))
      .border({ width: 1, color: $r('app.color.ag_warning') })
    }
  }

  build() {
    Column() {
      this.header()

      Refresh({ refreshing: this.refreshing }) {
        List({ space: Dimens.md }) {
          ListItem() {
            this.partialFailureNotice()
          }

          ForEach(scopesForCategory(this.category), (scope: TodoScope) => {
            ListItem() {
              this.scopeSection(scope)
            }
          }, (scope: TodoScope) => scope)

          ListItem() {
            Text('Counts show only items loaded on this device.')
              .fontSize(10)
              .fontColor($r('app.color.ag_text_tertiary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: Dimens.sm, bottom: Dimens.xl })
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: Dimens.lg, right: Dimens.lg, bottom: Dimens.md })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onReachEnd(() => {
          this.loadMoreAtEnd();
        })
        .id('todo_list')
      }
      .layoutWeight(1)
      .width('100%')
      .onRefreshing(() => {
        this.refresh();
      })
      .id('todo_refresh_container')
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
    .id('todo_page')
  }
}

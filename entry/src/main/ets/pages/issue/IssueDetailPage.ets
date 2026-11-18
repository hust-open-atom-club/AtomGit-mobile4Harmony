import { DisplayMetrics } from '../../common/DisplayMetrics';
import { Dimens, FontSize, Motion, Radius } from '../../components/DesignTokens';
import { GlassCard } from '../../components/GlassCard';
import { EmptyView, ErrorView, LoadingView } from '../../components/StatusViews';
import {
  CollaborationComment,
  IssueDetail,
  RepositoryItemRef
} from '../../model/CollaborationEntities';
import {
  EmptyIssueDetailStore,
  IssueDetailStore
} from '../../viewmodel/IssueDetailStore';
import { LoadState } from '../../viewmodel/SessionStore';

@ComponentV2
export struct IssueDetailPage {
  @Param ref: RepositoryItemRef = new RepositoryItemRef('', '', 0);
  @Param store: IssueDetailStore = new EmptyIssueDetailStore();
  @Param onBack: () => void = () => {};
  @Param onOpenWeb: (url: string) => void = () => {};

  @Local metrics: DisplayMetrics = DisplayMetrics.instance();
  @Local appeared: boolean = false;

  aboutToAppear(): void {
    this.store.initialize(this.ref);
    this.store.load();
    this.getUIContext().animateTo({ duration: Motion.slow, curve: Curve.Friction }, () => {
      this.appeared = true;
    });
  }

  aboutToDisappear(): void {
    this.store.cancelPending();
  }

  private async refresh(): Promise<void> {
    await this.store.refresh();
  }

  private async loadMore(): Promise<void> {
    if (this.store.loadingMore) {
      return;
    }
    await this.store.loadMore();
  }

  private async submit(): Promise<void> {
    await this.store.submitComment();
  }

  private openWeb(): void {
    if (this.store.issue !== undefined && this.store.issue.htmlUrl.length > 0) {
      this.onOpenWeb(this.store.issue.htmlUrl);
    }
  }

  private statusLabel(value: string): string {
    const normalized = value.trim().toLowerCase();
    if (normalized === 'open') {
      return 'Open';
    }
    if (normalized === 'closed') {
      return 'Closed';
    }
    if (normalized.length === 0) {
      return 'Unknown';
    }
    return value.charAt(0).toUpperCase() + value.substring(1);
  }

  private statusColor(value: string): ResourceColor {
    return value.trim().toLowerCase() === 'open'
      ? $r('app.color.ag_success')
      : $r('app.color.ag_text_secondary');
  }

  private formatTimestamp(value: string): string {
    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) {
      return value;
    }
    const monthNames: string[] = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const hours = parsed.getHours() < 10 ? '0' + parsed.getHours().toString()
      : parsed.getHours().toString();
    const minutes = parsed.getMinutes() < 10 ? '0' + parsed.getMinutes().toString()
      : parsed.getMinutes().toString();
    return monthNames[parsed.getMonth()] + ' ' + parsed.getDate().toString() + ', '
      + parsed.getFullYear().toString() + ' ' + hours + ':' + minutes;
  }

  private commentTypeLabel(value: string): string {
    if (value.trim().length === 0) {
      return '';
    }
    return value.replace(/_/g, ' ');
  }

  @Builder
  header(): void {
    Row({ space: Dimens.md }) {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.arrow_left'))
          .fontSize(18)
          .fontColor([$r('app.color.ag_text_primary')])
      }
      .width(38)
      .height(38)
      .backgroundColor($r('app.color.ag_surface'))
      .border({ width: 1, color: $r('app.color.ag_card_border') })
      .onClick(() => {
        this.onBack();
      })
      .id('issue_back')

      Column({ space: 2 }) {
        Text('Issue #' + this.ref.number.toString())
          .fontSize(FontSize.headline)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ag_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.ref.owner + '/' + this.ref.repo)
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
      }
      .width(38)
      .height(38)
      .backgroundColor($r('app.color.ag_accent_soft'))
      .enabled(this.store.issue !== undefined && this.store.issue.htmlUrl.length > 0)
      .onClick(() => {
        this.openWeb();
      })
      .id('issue_open_web')
    }
    .width('100%')
    .padding({ left: Dimens.lg, right: Dimens.lg, top: Dimens.md, bottom: Dimens.sm })
    .opacity(this.appeared ? 1 : 0)
    .translate({ y: this.appeared ? 0 : 8 })
  }

  @Builder
  issueCard(issue: IssueDetail): void {
    GlassCard({ radius: Radius.card }) {
      Column({ space: Dimens.md }) {
        Row({ space: Dimens.sm }) {
          Text(this.statusLabel(issue.state))
            .fontSize(FontSize.caption)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.statusColor(issue.state))
            .padding({ left: Dimens.sm, right: Dimens.sm, top: 4, bottom: 4 })
            .borderRadius(Radius.chip)
            .backgroundColor($r('app.color.ag_accent_soft'))
          Text('@' + issue.author)
            .fontSize(FontSize.caption)
            .fontColor($r('app.color.ag_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.formatTimestamp(issue.updatedAt))
            .fontSize(10)
            .fontColor($r('app.color.ag_text_tertiary'))
        }
        .width('100%')

        Text(issue.title)
          .fontSize(FontSize.headline)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ag_text_primary'))
          .width('100%')

        if (issue.labels.length > 0) {
          Text(issue.labels.join('  ·  '))
            .fontSize(FontSize.caption)
            .fontColor($r('app.color.ag_accent'))
            .width('100%')
        }

        Divider()
          .color($r('app.color.ag_separator'))

        Text(issue.body.length > 0 ? issue.body : 'No description provided.')
          .fontSize(FontSize.bodyLarge)
          .lineHeight(22)
          .fontColor(issue.body.length > 0
            ? $r('app.color.ag_text_primary')
            : $r('app.color.ag_text_tertiary'))
          .width('100%')
          .id('issue_body')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  commentCard(comment: CollaborationComment): void {
    GlassCard({ radius: Radius.card, elevated: false }) {
      Column({ space: Dimens.sm }) {
        Row({ space: Dimens.sm }) {
          Text('@' + comment.author)
            .fontSize(FontSize.body)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ag_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (comment.commentType.length > 0) {
            Text(this.commentTypeLabel(comment.commentType))
              .fontSize(10)
              .fontColor($r('app.color.ag_accent'))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(Radius.chip)
              .backgroundColor($r('app.color.ag_accent_soft'))
          }
          Blank()
          Text(this.formatTimestamp(comment.createdAt))
            .fontSize(10)
            .fontColor($r('app.color.ag_text_tertiary'))
        }
        .width('100%')

        Text(comment.body.length > 0 ? comment.body : 'No comment text.')
          .fontSize(FontSize.body)
          .lineHeight(21)
          .fontColor(comment.body.length > 0
            ? $r('app.color.ag_text_primary')
            : $r('app.color.ag_text_tertiary'))
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  commentsSection(): void {
    Column({ space: Dimens.sm }) {
      Row({ space: Dimens.sm }) {
        Text('Comments')
          .fontSize(FontSize.title)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ag_text_primary'))
        Text(this.store.comments.length.toString())
          .fontSize(FontSize.caption)
          .fontColor($r('app.color.ag_text_tertiary'))
        Blank()
        if (this.store.loadingMore) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color($r('app.color.ag_accent'))
        }
      }
      .width('100%')
      .padding({ top: Dimens.sm })

      if (this.store.commentError.length > 0) {
        Column({ space: Dimens.sm }) {
          ErrorView({ message: this.store.commentError, retryable: false })
          Button('Retry comments')
            .fontSize(FontSize.caption)
            .height(34)
            .backgroundColor($r('app.color.ag_accent_soft'))
            .fontColor($r('app.color.ag_accent'))
            .onClick(() => {
              this.store.retryComments();
            })
            .id('issue_comments_retry')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      if (this.store.comments.length === 0 && this.store.state === LoadState.Ready
        && this.store.commentError.length === 0) {
        EmptyView({
          text: 'No comments yet',
          symbol: $r('sys.symbol.doc_text'),
          viewId: 'issue_comments_empty'
        })
      } else {
        ForEach(this.store.comments, (comment: CollaborationComment) => {
          this.commentCard(comment)
        }, (comment: CollaborationComment) => comment.id)

        if (this.store.hasMore) {
          Button(this.store.loadingMore ? 'Loading more' : 'Load more comments')
            .fontSize(FontSize.caption)
            .height(36)
            .backgroundColor($r('app.color.ag_accent_soft'))
            .fontColor($r('app.color.ag_accent'))
            .enabled(!this.store.loadingMore)
            .onClick(() => {
              this.loadMore();
            })
            .id('issue_comments_load_more')
        }
      }
    }
    .width('100%')
  }

  @Builder
  content(): void {
    if (this.store.state === LoadState.Loading && this.store.issue === undefined) {
      LoadingView({ text: 'Loading issue' })
    } else if (this.store.state === LoadState.Error && this.store.issue === undefined) {
      Column({ space: Dimens.md }) {
        ErrorView({ message: this.store.errorMessage, retryable: false })
        Button('Retry')
          .fontSize(FontSize.body)
          .height(38)
          .backgroundColor($r('app.color.ag_accent'))
          .fontColor($r('app.color.ag_text_on_accent'))
          .onClick(() => {
            this.store.retry();
          })
          .id('issue_retry')
      }
      .width('100%')
      .padding(Dimens.lg)
    } else if (this.store.issue === undefined) {
      EmptyView({
        text: 'Issue unavailable',
        symbol: $r('sys.symbol.doc_text'),
        viewId: 'issue_empty'
      })
    } else {
      Column({ space: Dimens.md }) {
        if (this.store.errorMessage.length > 0) {
          ErrorView({ message: this.store.errorMessage, retryable: false })
        }
        this.issueCard(this.store.issue)
        this.commentsSection()
      }
      .width('100%')
    }
  }

  @Builder
  composer(): void {
    GlassCard({
      radius: Radius.card,
      cardPadding: {
        left: Dimens.lg, right: Dimens.lg, top: Dimens.md, bottom: Dimens.md
      }
    }) {
      Column({ space: Dimens.sm }) {
        TextArea({ placeholder: 'Write a comment', text: this.store.draft })
          .fontSize(FontSize.body)
          .height(88)
          .maxLength(10000)
          .borderRadius(Radius.chip)
          .backgroundColor($r('app.color.ag_surface_sunken'))
          .border({ width: 1, color: $r('app.color.ag_card_border') })
          .padding(Dimens.md)
          .enabled(!this.store.sending)
          .onChange((value: string) => {
            this.store.updateDraft(value);
          })
          .id('issue_comment_input')

        if (this.store.sendErrorMessage.length > 0) {
          Text(this.store.sendErrorMessage)
            .fontSize(FontSize.caption)
            .fontColor($r('app.color.ag_error'))
            .width('100%')
            .id('issue_comment_error')
        }

        if (this.store.successMessage.length > 0) {
          Text(this.store.successMessage)
            .fontSize(FontSize.caption)
            .fontColor($r('app.color.ag_success'))
            .width('100%')
            .id('issue_comment_success')
        }

        Row({ space: Dimens.sm }) {
          Text(this.store.draft.trim().length === 0 ? 'Comment text is required' : 'Markdown supported')
            .fontSize(10)
            .fontColor($r('app.color.ag_text_tertiary'))
            .layoutWeight(1)
          Button() {
            Row({ space: Dimens.xs }) {
              if (this.store.sending) {
                LoadingProgress()
                  .width(16)
                  .height(16)
                  .color($r('app.color.ag_text_on_accent'))
              }
              Text(this.store.sending ? 'Posting' : 'Post comment')
                .fontSize(FontSize.caption)
                .fontColor($r('app.color.ag_text_on_accent'))
            }
            .justifyContent(FlexAlign.Center)
          }
          .height(38)
          .padding({ left: Dimens.md, right: Dimens.md })
          .borderRadius(Radius.chip)
          .backgroundColor($r('app.color.ag_accent'))
          .enabled(this.store.canSubmit())
          .onClick(() => {
            this.submit();
          })
          .id('issue_comment_submit')
        }
        .width('100%')
      }
      .width('100%')
    }
  }

  build() {
    Column() {
      this.header()

      Scroll() {
        Column({ space: Dimens.md }) {
          this.content()
        }
        .width('100%')
        .padding({ left: Dimens.lg, right: Dimens.lg, bottom: Dimens.md })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onReachEnd(() => {
        this.loadMore();
      })
      .id('issue_detail_scroll')

      Column() {
        this.composer()
      }
      .width('100%')
      .padding({ left: Dimens.lg, right: Dimens.lg, bottom: Dimens.sm })
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.metrics.topInsetVp,
      bottom: this.metrics.bottomInsetVp
    })
    .linearGradient({
      angle: 180,
      colors: [[$r('app.color.ag_hero_start'), 0], [$r('app.color.ag_background'), 0.45]]
    })
    .id('issue_detail_page')
  }
}

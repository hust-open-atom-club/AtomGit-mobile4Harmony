import { Dimens, FontSize, Radius } from '../../components/DesignTokens';
import { GlassCard } from '../../components/GlassCard';
import { EmptyView, ErrorView, LoadingView } from '../../components/StatusViews';
import {
  ApprovalReviewer,
  CollaborationComment,
  PullRequestDetail,
  PullRequestFile,
  RepositoryItemRef
} from '../../model/CollaborationEntities';
import {
  ApprovalUiState,
  EmptyPullRequestDetailStore,
  PullRequestDetailStore
} from '../../viewmodel/PullRequestDetailStore';

@ComponentV2
export struct PullRequestDetailPage {
  @Param ref: RepositoryItemRef = new RepositoryItemRef('', '', 0);
  @Param store: PullRequestDetailStore = new EmptyPullRequestDetailStore();
  @Param onBack: () => void = () => {};
  @Param onOpenWeb: (url: string) => void = () => {};

  @Local selectedFileIndex: number = 0;

  aboutToAppear(): void {
    this.store.open(this.ref).then(() => {
      this.clampFileSelection();
    });
  }

  aboutToDisappear(): void {
    this.store.cancelPending();
  }

  private clampFileSelection(): void {
    if (this.store.files.length === 0) {
      this.selectedFileIndex = 0;
    } else if (this.selectedFileIndex >= this.store.files.length) {
      this.selectedFileIndex = this.store.files.length - 1;
    }
  }

  private selectedFile(): PullRequestFile | undefined {
    if (this.store.files.length === 0) {
      return undefined;
    }
    const index = Math.max(0, Math.min(this.selectedFileIndex, this.store.files.length - 1));
    return this.store.files[index];
  }

  private shortSha(value: string): string {
    if (value.length <= 12) {
      return value.length === 0 ? 'Unknown' : value;
    }
    return value.substring(0, 12);
  }

  private reviewerLabel(reviewer: ApprovalReviewer): string {
    const status = reviewer.acceptStatus.trim().toLowerCase();
    if (status === 'true' || status === 'accept' || status === 'accepted' || status === 'approved') {
      return 'Approved';
    }
    if (status === 'reject' || status === 'rejected') {
      return 'Rejected';
    }
    return 'Pending';
  }

  private reviewerColor(reviewer: ApprovalReviewer): ResourceColor {
    const label = this.reviewerLabel(reviewer);
    if (label === 'Approved') {
      return $r('app.color.ag_success');
    }
    if (label === 'Rejected') {
      return $r('app.color.ag_error');
    }
    return $r('app.color.ag_warning');
  }

  private fileStatus(file: PullRequestFile): string {
    if (file.tooLarge || file.status === 'too_large') {
      return 'Too large';
    }
    if (file.status === 'binary') {
      return 'Binary';
    }
    if (file.status === 'added') {
      return 'Added';
    }
    if (file.status === 'deleted') {
      return 'Deleted';
    }
    if (file.status === 'renamed') {
      return 'Renamed';
    }
    return 'Modified';
  }

  private fileStatusColor(file: PullRequestFile): ResourceColor {
    if (file.status === 'added') {
      return $r('app.color.ag_success');
    }
    if (file.status === 'deleted' || file.tooLarge || file.status === 'too_large') {
      return $r('app.color.ag_error');
    }
    if (file.status === 'renamed' || file.status === 'binary') {
      return $r('app.color.ag_warning');
    }
    return $r('app.color.ag_accent');
  }

  private patchFallback(file: PullRequestFile): string {
    if (file.tooLarge || file.status === 'too_large') {
      return 'Patch unavailable because AtomGit marked this file as too large. Open the pull request on the web.';
    }
    if (file.status === 'binary') {
      return 'Binary file. A text diff is unavailable.';
    }
    return 'Patch unavailable for this file. Open the pull request on the web to inspect the change.';
  }

  private prLabel(detail: PullRequestDetail): string {
    return detail.ref.owner + '/' + detail.ref.repo + '#' + detail.ref.number.toString();
  }

  private approvalDescription(detail: PullRequestDetail): string {
    if (detail.merged) {
      return 'This pull request is already merged.';
    }
    if (detail.state.toLowerCase() !== 'open') {
      return 'Approval is available only while the pull request is open.';
    }
    return 'Approve only after reviewing the current head, comments, and changed files.';
  }

  private commentMeta(comment: CollaborationComment): string {
    const parts: string[] = [];
    if (comment.commentType.length > 0) {
      parts.push(comment.commentType === 'diff_comment' ? 'Review comment' : 'Comment');
    }
    if (comment.createdAt.length > 0) {
      parts.push(comment.createdAt);
    }
    if (comment.resolved) {
      parts.push('Resolved');
    }
    return parts.join(' · ');
  }

  @Builder
  pageHeader(): void {
    Row({ space: Dimens.md }) {
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([$r('app.color.ag_text_primary')])
      }
      .width(40)
      .height(40)
      .backgroundColor($r('app.color.ag_surface'))
      .border({ width: 1, color: $r('app.color.ag_card_border') })
      .onClick(() => {
        this.onBack();
      })
      .id('pr_detail_back')

      Column({ space: 2 }) {
        Text('Pull request')
          .fontSize(FontSize.headline)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ag_text_primary'))
        Text(this.store.detail === undefined
          ? this.ref.owner + '/' + this.ref.repo + '#' + this.ref.number.toString()
          : this.prLabel(this.store.detail))
          .fontSize(FontSize.caption)
          .fontColor($r('app.color.ag_text_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('Open on web')
        .height(36)
        .fontSize(FontSize.caption)
        .fontColor($r('app.color.ag_accent'))
        .backgroundColor($r('app.color.ag_accent_soft'))
        .enabled(this.store.detail !== undefined && this.store.detail.htmlUrl.length > 0)
        .onClick(() => {
          if (this.store.detail !== undefined && this.store.detail.htmlUrl.length > 0) {
            this.onOpenWeb(this.store.detail.htmlUrl);
          }
        })
        .id('pr_detail_open_web')
    }
    .width('100%')
    .padding({ left: Dimens.lg, right: Dimens.lg, top: Dimens.md, bottom: Dimens.sm })
  }

  @Builder
  detailCard(detail: PullRequestDetail): void {
    GlassCard() {
      Column({ space: Dimens.md }) {
        Row({ space: Dimens.sm }) {
          Text(detail.state.length === 0 ? 'unknown' : detail.state.toUpperCase())
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor(detail.state.toLowerCase() === 'open'
              ? $r('app.color.ag_success') : $r('app.color.ag_text_secondary'))
            .padding({ left: Dimens.sm, right: Dimens.sm, top: 4, bottom: 4 })
            .borderRadius(Radius.chip)
            .backgroundColor($r('app.color.ag_surface_sunken'))
          if (detail.merged) {
            Text('MERGED')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ag_text_on_accent'))
              .padding({ left: Dimens.sm, right: Dimens.sm, top: 4, bottom: 4 })
              .borderRadius(Radius.chip)
              .backgroundColor($r('app.color.ag_warning'))
          }
          Blank()
          Text(detail.mergeable ? 'Mergeable' : 'Not mergeable')
            .fontSize(FontSize.caption)
            .fontColor(detail.mergeable
              ? $r('app.color.ag_success') : $r('app.color.ag_error'))
        }
        .width('100%')

        Text(detail.title.length === 0 ? 'Untitled pull request' : detail.title)
          .fontSize(FontSize.headline)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.ag_text_primary'))
          .width('100%')

        Text('by @' + (detail.author.length === 0 ? 'unknown' : detail.author)
          + ' · Updated ' + (detail.updatedAt.length === 0 ? 'unknown' : detail.updatedAt))
          .fontSize(FontSize.caption)
          .fontColor($r('app.color.ag_text_secondary'))
          .width('100%')

        Row({ space: Dimens.sm }) {
          Column({ space: 2 }) {
            Text('HEAD SHA')
              .fontSize(9)
              .fontColor($r('app.color.ag_text_tertiary'))
            Text(this.shortSha(detail.headSha))
              .fontSize(FontSize.caption)
              .fontColor($r('app.color.ag_text_primary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column({ space: 2 }) {
            Text('BASE SHA')
              .fontSize(9)
              .fontColor($r('app.color.ag_text_tertiary'))
            Text(this.shortSha(detail.baseSha))
              .fontSize(FontSize.caption)
              .fontColor($r('app.color.ag_text_primary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(Dimens.md)
        .borderRadius(Radius.chip)
        .backgroundColor($r('app.color.ag_surface_sunken'))

        Divider().color($r('app.color.ag_separator'))

        Text('DESCRIPTION')
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ag_text_tertiary'))
          .width('100%')
        Text(detail.body.length === 0 ? 'No description provided.' : detail.body)
          .fontSize(FontSize.bodyLarge)
          .lineHeight(22)
          .fontColor($r('app.color.ag_text_primary'))
          .width('100%')
      }
      .width('100%')
    }
  }

  @Builder
  approvalCard(detail: PullRequestDetail): void {
    GlassCard() {
      Column({ space: Dimens.md }) {
        Row() {
          Text('Approval')
            .fontSize(FontSize.title)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ag_text_primary'))
          Blank()
          if (this.store.approvalReadbackConfirmed) {
            Text('CONFIRMED')
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ag_success'))
          }
        }
        .width('100%')

        Text(this.approvalDescription(detail))
          .fontSize(FontSize.body)
          .fontColor($r('app.color.ag_text_secondary'))
          .width('100%')

        if (detail.approvalReviewers.length === 0) {
          Text('No approval reviewers were returned for this pull request.')
            .fontSize(FontSize.caption)
            .fontColor($r('app.color.ag_text_tertiary'))
            .width('100%')
        } else {
          Column({ space: Dimens.sm }) {
            ForEach(detail.approvalReviewers, (reviewer: ApprovalReviewer) => {
              Row({ space: Dimens.sm }) {
                SymbolGlyph($r('sys.symbol.person_crop_circle_fill'))
                  .fontSize(18)
                  .fontColor([$r('app.color.ag_accent')])
                Column({ space: 2 }) {
                  Text(reviewer.name.length === 0 ? reviewer.login : reviewer.name)
                    .fontSize(FontSize.body)
                    .fontColor($r('app.color.ag_text_primary'))
                  Text('@' + reviewer.login)
                    .fontSize(10)
                    .fontColor($r('app.color.ag_text_tertiary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Text(this.reviewerLabel(reviewer))
                  .fontSize(FontSize.caption)
                  .fontColor(this.reviewerColor(reviewer))
              }
              .width('100%')
            }, (reviewer: ApprovalReviewer) => reviewer.login)
          }
          .width('100%')
        }

        if (this.store.approvalErrorMessage.length > 0) {
          Text(this.store.approvalErrorMessage)
            .fontSize(FontSize.caption)
            .fontColor($r('app.color.ag_error'))
            .width('100%')
            .id('pr_approval_error')
        }

        if (this.store.approvalMessage.length > 0
          && this.store.approvalErrorMessage.length === 0) {
          Text(this.store.approvalMessage)
            .fontSize(FontSize.caption)
            .fontColor(this.store.approvalReadbackConfirmed
              ? $r('app.color.ag_success') : $r('app.color.ag_warning'))
            .width('100%')
            .id('pr_approval_status')
        }

        if (this.store.approving) {
          Row({ space: Dimens.sm }) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color($r('app.color.ag_accent'))
            Text('Checking the latest head and submitting approval')
              .fontSize(FontSize.caption)
              .fontColor($r('app.color.ag_text_secondary'))
          }
          .width('100%')
        } else if (this.store.approvalReadbackConfirmed) {
          Text('Your approval was confirmed by rereading the pull request.')
            .fontSize(FontSize.caption)
            .fontColor($r('app.color.ag_success'))
            .width('100%')
        } else if (this.store.approvalNeedsReview) {
          Button('Review latest head')
            .width('100%')
            .height(44)
            .borderRadius(Radius.chip + 2)
            .backgroundColor($r('app.color.ag_warning'))
            .fontColor($r('app.color.ag_text_on_accent'))
            .onClick(() => {
              this.store.markLatestHeadReviewed();
            })
            .id('pr_review_latest_head')
        } else {
          Button('Approve pull request')
            .width('100%')
            .height(44)
            .borderRadius(Radius.chip + 2)
            .backgroundColor($r('app.color.ag_accent'))
            .fontColor($r('app.color.ag_text_on_accent'))
            .enabled(this.store.canApprove())
            .onClick(() => {
              this.store.approve();
            })
            .id('pr_approve')
        }
      }
      .width('100%')
    }
  }

  @Builder
  filesCard(): void {
    GlassCard() {
      Column({ space: Dimens.md }) {
        Row() {
          Text('Changed files')
            .fontSize(FontSize.title)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ag_text_primary'))
          Blank()
          if (this.store.loadingFiles) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color($r('app.color.ag_accent'))
          } else {
            Text(this.store.files.length.toString() + ' loaded')
              .fontSize(FontSize.caption)
              .fontColor($r('app.color.ag_text_tertiary'))
          }
        }
        .width('100%')

        if (this.store.filesErrorMessage.length > 0) {
          ErrorView({
            message: this.store.filesErrorMessage,
            retryable: false,
            fontSize: FontSize.caption,
            padH: 0,
            padV: 0,
            viewId: 'pr_files_error'
          })
          Button('Retry files')
            .height(34)
            .fontSize(FontSize.caption)
            .fontColor($r('app.color.ag_accent'))
            .backgroundColor($r('app.color.ag_accent_soft'))
            .onClick(() => {
              this.store.refreshFiles();
            })
        }

        if (this.store.files.length === 0) {
          EmptyView({
            text: this.store.loadingFiles ? 'Loading changed files' : 'No changed files were returned.',
            symbol: $r('sys.symbol.doc_text'),
            viewId: 'pr_files_empty'
          })
        } else {
          if (this.store.filesAtLimit) {
            Text('The file list may be limited by the client cap. Open the pull request on the web for the complete set.')
              .fontSize(10)
              .fontColor($r('app.color.ag_warning'))
              .width('100%')
          }

          Scroll() {
            Row({ space: Dimens.sm }) {
              ForEach(this.store.files, (file: PullRequestFile, index: number) => {
                Text(file.path)
                  .fontSize(FontSize.caption)
                  .fontColor(this.selectedFileIndex === index
                    ? $r('app.color.ag_accent') : $r('app.color.ag_text_secondary'))
                  .fontWeight(this.selectedFileIndex === index
                    ? FontWeight.Medium : FontWeight.Regular)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .padding({ left: Dimens.md, right: Dimens.md, top: 7, bottom: 7 })
                  .borderRadius(Radius.chip)
                  .backgroundColor(this.selectedFileIndex === index
                    ? $r('app.color.ag_accent_soft') : $r('app.color.ag_surface_sunken'))
                  .onClick(() => {
                    this.selectedFileIndex = index;
                  })
                  .id('pr_file_' + index.toString())
              }, (file: PullRequestFile, index: number) => file.path + '#' + index.toString())
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
          .height(38)

          if (this.selectedFile() !== undefined) {
            Column({ space: Dimens.sm }) {
              Row({ space: Dimens.sm }) {
                Text(this.selectedFile()?.path ?? '')
                  .fontSize(FontSize.body)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.ag_text_primary'))
                  .layoutWeight(1)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.fileStatus(this.selectedFile() as PullRequestFile))
                  .fontSize(10)
                  .fontColor(this.fileStatusColor(this.selectedFile() as PullRequestFile))
              }
              .width('100%')

              if (this.selectedFile() !== undefined) {
                if ((this.selectedFile() as PullRequestFile).oldPath.length > 0
                  && (this.selectedFile() as PullRequestFile).oldPath
                    !== (this.selectedFile() as PullRequestFile).path) {
                  Text((this.selectedFile() as PullRequestFile).oldPath + ' → '
                    + (this.selectedFile() as PullRequestFile).path)
                    .fontSize(10)
                    .fontColor($r('app.color.ag_text_tertiary'))
                    .width('100%')
                }
                Row({ space: Dimens.md }) {
                  Text('+' + (this.selectedFile() as PullRequestFile).additions.toString())
                    .fontSize(10)
                    .fontColor($r('app.color.ag_success'))
                  Text('-' + (this.selectedFile() as PullRequestFile).deletions.toString())
                    .fontSize(10)
                    .fontColor($r('app.color.ag_error'))
                }
                .width('100%')

                if ((this.selectedFile() as PullRequestFile).patch !== undefined) {
                  Text((this.selectedFile() as PullRequestFile).patch)
                    .fontSize(11)
                    .lineHeight(17)
                    .fontColor($r('app.color.ag_text_primary'))
                    .width('100%')
                    .padding(Dimens.md)
                    .borderRadius(Radius.chip)
                    .backgroundColor($r('app.color.ag_surface_sunken'))
                    .textSelectable(TextSelectableMode.SELECTABLE_UNFOCUSABLE)
                    .id('pr_selected_patch')
                  if ((this.selectedFile() as PullRequestFile).truncated) {
                    Text('Diff truncated by the client size limit. Open the pull request on the web for the full diff.')
                      .fontSize(10)
                      .fontColor($r('app.color.ag_warning'))
                      .width('100%')
                      .id('pr_patch_truncated')
                  }
                } else {
                  Text(this.patchFallback(this.selectedFile() as PullRequestFile))
                    .fontSize(FontSize.caption)
                    .fontColor($r('app.color.ag_text_secondary'))
                    .width('100%')
                    .padding(Dimens.md)
                    .borderRadius(Radius.chip)
                    .backgroundColor($r('app.color.ag_surface_sunken'))
                    .id('pr_patch_unavailable')
                }
              }
            }
            .width('100%')
            .padding({ top: Dimens.sm })
          }
        }
      }
      .width('100%')
    }
  }

  @Builder
  commentsCard(): void {
    GlassCard() {
      Column({ space: Dimens.md }) {
        Row() {
          Text('Comments')
            .fontSize(FontSize.title)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ag_text_primary'))
          Blank()
          if (this.store.loadingComments) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color($r('app.color.ag_accent'))
          }
        }
        .width('100%')

        if (this.store.commentsErrorMessage.length > 0) {
          ErrorView({
            message: this.store.commentsErrorMessage,
            retryable: false,
            fontSize: FontSize.caption,
            padH: 0,
            padV: 0,
            viewId: 'pr_comments_error'
          })
          Button('Retry comments')
            .height(34)
            .fontSize(FontSize.caption)
            .fontColor($r('app.color.ag_accent'))
            .backgroundColor($r('app.color.ag_accent_soft'))
            .onClick(() => {
              this.store.refreshComments();
            })
        }

        if (this.store.comments.length === 0) {
          EmptyView({
            text: this.store.loadingComments ? 'Loading comments' : 'No comments yet.',
            viewId: 'pr_comments_empty'
          })
        } else {
          Column({ space: Dimens.sm }) {
            ForEach(this.store.comments, (comment: CollaborationComment) => {
              Column({ space: 5 }) {
                Row({ space: Dimens.sm }) {
                  Text('@' + (comment.author.length === 0 ? 'unknown' : comment.author))
                    .fontSize(FontSize.caption)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.ag_text_primary'))
                  if (comment.parentId.length > 0) {
                    Text('Reply')
                      .fontSize(9)
                      .fontColor($r('app.color.ag_accent'))
                  }
                  Blank()
                  Text(this.commentMeta(comment))
                    .fontSize(9)
                    .fontColor($r('app.color.ag_text_tertiary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')

                Text(comment.body)
                  .fontSize(FontSize.body)
                  .lineHeight(21)
                  .fontColor($r('app.color.ag_text_primary'))
                  .width('100%')
              }
              .width('100%')
              .padding(Dimens.md)
              .borderRadius(Radius.chip)
              .backgroundColor($r('app.color.ag_surface_sunken'))
            }, (comment: CollaborationComment) => comment.id + '|' + comment.parentId + '|' + comment.createdAt)
          }
          .width('100%')

          if (this.store.commentsHasMore) {
            Button(this.store.loadingMoreComments ? 'Loading more comments' : 'Load more comments')
              .height(36)
              .fontSize(FontSize.caption)
              .fontColor($r('app.color.ag_accent'))
              .backgroundColor($r('app.color.ag_accent_soft'))
              .enabled(!this.store.loadingMoreComments)
              .onClick(() => {
                this.store.loadMoreComments();
              })
              .id('pr_comments_load_more')
          }
        }

        Divider().color($r('app.color.ag_separator'))

        TextArea({
          text: this.store.commentDraft,
          placeholder: 'Write a comment. Drafts remain available after a failed send.'
        })
          .height(112)
          .width('100%')
          .fontSize(FontSize.body)
          .fontColor($r('app.color.ag_text_primary'))
          .backgroundColor($r('app.color.ag_surface_sunken'))
          .borderRadius(Radius.chip)
          .border({ width: 1, color: $r('app.color.ag_card_border') })
          .enabled(!this.store.sendingComment)
          .onChange((value: string) => {
            this.store.setCommentDraft(value);
          })
          .id('pr_comment_input')

        if (this.store.commentErrorMessage.length > 0) {
          ErrorView({
            message: this.store.commentErrorMessage,
            retryable: false,
            fontSize: FontSize.caption,
            padH: 0,
            padV: 0,
            viewId: 'pr_comment_send_error'
          })
        }

        if (this.store.commentSubmissionConfirmed) {
          Text('Comment confirmed after reloading comments.')
            .fontSize(10)
            .fontColor($r('app.color.ag_success'))
            .width('100%')
            .id('pr_comment_confirmed')
        }

        Button() {
          Row({ space: Dimens.sm }) {
            if (this.store.sendingComment) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color($r('app.color.ag_text_on_accent'))
            }
            Text(this.store.sendingComment ? 'Sending and checking comments' : 'Send comment')
              .fontSize(FontSize.body)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ag_text_on_accent'))
          }
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height(44)
        .borderRadius(Radius.chip + 2)
        .backgroundColor($r('app.color.ag_accent'))
        .enabled(!this.store.sendingComment && this.store.commentDraft.trim().length > 0)
        .onClick(() => {
          this.store.sendComment();
        })
        .id('pr_comment_send')
      }
      .width('100%')
    }
  }

  @Builder
  detailContent(detail: PullRequestDetail): void {
    Column({ space: Dimens.md }) {
      this.detailCard(detail)
      this.approvalCard(detail)
      this.filesCard()
      this.commentsCard()
    }
    .width('100%')
  }

  build() {
    Column() {
      this.pageHeader()

      if (this.store.loadingDetail && this.store.detail === undefined) {
        LoadingView({ text: 'Loading pull request details' })
      } else if (this.store.detail === undefined) {
        Column({ space: Dimens.sm }) {
          ErrorView({
            message: this.store.detailErrorMessage.length > 0
              ? this.store.detailErrorMessage : 'The pull request could not be loaded.',
            retryable: false,
            viewId: 'pr_detail_error'
          })
          Button('Retry pull request')
            .height(36)
            .fontSize(FontSize.caption)
            .fontColor($r('app.color.ag_accent'))
            .backgroundColor($r('app.color.ag_accent_soft'))
            .onClick(() => {
              this.store.refreshAll();
            })
        }
        .width('100%')
        .padding(Dimens.lg)
      } else {
        Refresh({ refreshing: this.store.refreshing }) {
          Scroll() {
            Column({ space: Dimens.md }) {
              if (this.store.detailErrorMessage.length > 0) {
                ErrorView({
                  message: this.store.detailErrorMessage,
                  retryable: false,
                  fontSize: FontSize.caption,
                  padH: 0,
                  padV: 0,
                  viewId: 'pr_detail_partial_error'
                })
              }
              this.detailContent(this.store.detail)
            }
            .width('100%')
            .padding({ left: Dimens.lg, right: Dimens.lg, bottom: Dimens.xxl })
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .id('pr_detail_scroll')
        }
        .layoutWeight(1)
        .width('100%')
        .onRefreshing(() => {
          this.store.refreshAll();
        })
        .id('pr_detail_refresh')
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: [[$r('app.color.ag_hero_start'), 0], [$r('app.color.ag_background'), 0.4]]
    })
    .id('pr_detail_page')
  }
}

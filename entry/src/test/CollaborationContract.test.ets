import { describe, it, expect } from '@ohos/hypium';

import {
  ActivityDto,
  ActivityPageDto,
  CommentDto,
  IssueDto,
  NotificationDto,
  PullRequestDto,
  PullRequestFileDto
} from '../main/ets/model/CollaborationDtos';
import {
  ActivityItem,
  ApprovalReviewer,
  CollaborationComment,
  IssueDetail,
  NotificationItem,
  PullRequestDetail,
  PullRequestFile,
  RepositoryItemKind,
  RepositoryItemRef
} from '../main/ets/model/CollaborationEntities';
import {
  ApprovePullRequestOptions,
  DEFAULT_MAX_PATCH_CHARS,
  DEFAULT_MAX_PR_FILES,
  PullRequestFilesOptions,
  PullRequestTodoScope
} from '../main/ets/repository/Ports';

// Samples follow the AtomGit payloads recorded in the research baseline
// (atomgit-cli 138a070) so the shared contracts cannot drift from the API shape.
export default function collaborationContractTest() {
  describe('CollaborationContracts', () => {
    it('notification_sample_keeps_content_and_update_time', 0, () => {
      const d: NotificationDto = {
        id: '292ecbec857e4f27b426d66f2157938c',
        content: 'fix: normalize unauthenticated error handling',
        type: 'merge_requests_open',
        unread: true,
        update_at: '2026-08-14T23:30:20+08:00',
        html_url: 'https://gitcode.com/hust-open-atom-club/atomgit-cli/merge_requests/78',
        actor: { id: 6403465, login: 'mudongliang', name: 'mudongliang' },
        repository: {
          id: 10342125,
          full_name: 'hust-open-atom-club/atomgit-cli',
          human_name: 'HUST / atomgit-cli',
          url: 'https://gitcode.com/hust-open-atom-club/atomgit-cli'
        }
      };
      const repo = d.repository === undefined ? '' : (d.repository.full_name ?? '');
      const item = new NotificationItem('292ecbec857e4f27b426d66f2157938c', repo,
        d.type ?? '', d.content ?? '', d.unread === true, d.update_at ?? '',
        new RepositoryItemRef('hust-open-atom-club', 'atomgit-cli', 78),
        RepositoryItemKind.PullRequest);
      expect(d.content).assertEqual('fix: normalize unauthenticated error handling');
      expect(d.update_at).assertEqual('2026-08-14T23:30:20+08:00');
      expect(item.updatedAt.length > 0).assertTrue();
      expect(item.targetKind).assertEqual(RepositoryItemKind.PullRequest);
    });

    it('activity_sample_keeps_date_bucket_and_target_type', 0, () => {
      const page: ActivityPageDto = {
        events: {
          '2026-08-14': [{
            action: 1,
            action_name: 'opened',
            author: { login: 'mudongliang', name: 'mudongliang' },
            created_at: '2026-08-14T23:30:20+08:00',
            project_name: 'hust-open-atom-club/atomgit-cli',
            target_id: 78,
            target_iid: 78,
            target_title: 'fix: normalize unauthenticated error handling',
            target_type: 'pull_request',
            target_type_format: 'PR'
          }]
        },
        next: 'cursor-1'
      };
      const day = page.events === undefined ? undefined : page.events['2026-08-14'];
      const event: ActivityDto | undefined =
        day === undefined || day.length === 0 ? undefined : day[0];
      expect(event === undefined ? '' : (event.target_type ?? '')).assertEqual('pull_request');
      expect(page.next).assertEqual('cursor-1');
      const item = new ActivityItem('78', event === undefined ? '' : (event.action_name ?? ''),
        event === undefined ? '' : (event.target_title ?? ''),
        event === undefined ? '' : (event.author_username ?? ''),
        event === undefined ? '' : (event.project_name ?? ''),
        event === undefined ? '' : (event.created_at ?? ''),
        new RepositoryItemRef('hust-open-atom-club', 'atomgit-cli', 78),
        RepositoryItemKind.PullRequest);
      expect(item.targetKind).assertEqual(RepositoryItemKind.PullRequest);
    });

    it('pull_request_file_keeps_rename_and_truncation', 0, () => {
      const d: PullRequestFileDto = {
        sha: 'abc123',
        filename: 'new.go',
        status: 'renamed',
        additions: 5,
        deletions: 3,
        too_large: false,
        patch: {
          old_path: 'old.go',
          new_path: 'new.go',
          added_lines: 5,
          removed_lines: 3,
          too_large: false,
          new_file: false,
          renamed_file: true,
          deleted_file: false
        }
      };
      const patch = d.patch;
      expect(patch === undefined ? '' : (patch.old_path ?? '')).assertEqual('old.go');
      const file = new PullRequestFile('new.go', 'renamed', 5, 3,
        'diff --git a/old.go b/new.go', 'old.go', false, true);
      expect(file.oldPath).assertEqual('old.go');
      expect(file.truncated).assertTrue();
      const binary = new PullRequestFile('image.png', 'added', 0, 0, undefined, '', true);
      expect(binary.patch === undefined).assertTrue();
      expect(binary.tooLarge).assertTrue();
    });

    it('pull_request_detail_carries_head_and_approval_readback', 0, () => {
      const d: PullRequestDto = {
        id: 1,
        number: 78,
        title: 'Normalize error handling',
        body: 'PR body',
        state: 'open',
        html_url: 'https://gitcode.com/hust-open-atom-club/atomgit-cli/merge_requests/78',
        created_at: '2026-08-14T23:30:20+08:00',
        updated_at: '2026-08-15T08:00:00+08:00',
        user: { login: 'author' },
        merged: false,
        merged_at: '',
        mergeable: true,
        head: { ref: 'feature', sha: 'head-sha' },
        base: { ref: 'main', sha: 'base-sha' },
        approval_reviewers: [{ login: 'reviewer', name: 'Reviewer', accept_status: 'accept' }]
      };
      const reviewers = d.approval_reviewers;
      expect(reviewers === undefined || reviewers.length === 0
        ? '' : (reviewers[0].accept_status ?? '')).assertEqual('accept');
      expect(d.head === undefined ? '' : (d.head.sha ?? '')).assertEqual('head-sha');
      const detail = new PullRequestDetail(new RepositoryItemRef('o', 'r', 78),
        'Normalize error handling', 'PR body', 'open', false, '', true, 'head-sha', 'base-sha',
        'https://gitcode.com/hust-open-atom-club/atomgit-cli/merge_requests/78',
        '2026-08-15T08:00:00+08:00', 'author',
        [new ApprovalReviewer('reviewer', 'Reviewer', 'accept')]);
      expect(detail.headSha).assertEqual('head-sha');
      expect(detail.mergeable).assertTrue();
      expect(detail.approvalReviewers.length).assertEqual(1);
      expect(detail.approvalReviewers[0].acceptStatus).assertEqual('accept');
    });

    it('issue_detail_carries_body_author_and_labels', 0, () => {
      const d: IssueDto = {
        id: 2,
        number: '12',
        title: 'Login fails',
        body: 'Issue body',
        state: 'open',
        html_url: 'https://gitcode.com/o/r/issues/12',
        created_at: '2026-08-14T23:30:20+08:00',
        updated_at: '2026-08-15T08:00:00+08:00',
        user: { login: 'author' },
        labels: [{ name: 'bug' }]
      };
      expect(d.number).assertEqual('12');
      expect(d.body).assertEqual('Issue body');
      const detail = new IssueDetail(new RepositoryItemRef('o', 'r', 12), 'Login fails',
        'Issue body', 'open', 'https://gitcode.com/o/r/issues/12',
        '2026-08-14T23:30:20+08:00', '2026-08-15T08:00:00+08:00', 'author', ['bug']);
      expect(detail.body).assertEqual('Issue body');
      expect(detail.author).assertEqual('author');
      expect(detail.labels.length).assertEqual(1);
    });

    it('comment_keeps_discussion_and_reply_metadata', 0, () => {
      const d: CommentDto = {
        id: 'c1',
        body: 'Looks good',
        comment_type: 'pr_comment',
        discussion_id: 'd1',
        parent_id: 'p1',
        resolved: false,
        reply: [{ id: 'c2', body: 'Thanks' }]
      };
      expect(d.reply === undefined ? 0 : d.reply.length).assertEqual(1);
      const comment = new CollaborationComment('c1', 'Looks good', 'reviewer',
        'https://gitcode.com/o/r/merge_requests/78#note_1', '2026-08-15T08:00:00+08:00',
        'pr_comment', 'd1', 'p1', false);
      expect(comment.commentType).assertEqual('pr_comment');
      expect(comment.discussionId).assertEqual('d1');
      expect(comment.parentId).assertEqual('p1');
    });

    it('approval_and_file_options_are_explicit', 0, () => {
      const approve = new ApprovePullRequestOptions(true, 'head-sha');
      expect(approve.force).assertTrue();
      expect(approve.expectedHeadSha).assertEqual('head-sha');
      const files = new PullRequestFilesOptions();
      expect(files.maxFiles).assertEqual(DEFAULT_MAX_PR_FILES);
      expect(files.maxPatchChars).assertEqual(DEFAULT_MAX_PATCH_CHARS);
      const fallback = new PullRequestFilesOptions(0, -1);
      expect(fallback.maxFiles).assertEqual(DEFAULT_MAX_PR_FILES);
      expect(fallback.maxPatchChars).assertEqual(DEFAULT_MAX_PATCH_CHARS);
    });

    it('todo_scopes_match_verified_query_values', 0, () => {
      expect(PullRequestTodoScope.NeedsApproval).assertEqual('need_my_approve');
      expect(PullRequestTodoScope.NeedsReview).assertEqual('need_my_review');
      expect(PullRequestTodoScope.AssignedToMe).assertEqual('assigned_to_me');
      expect(PullRequestTodoScope.CreatedByMe).assertEqual('created_by_me');
    });
  });
}

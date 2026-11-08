# Activity API Verification

This record captures the API evidence used by the Activity feature. It contains no
credentials or private repository data.

**Verified:** 2026-11-05 (Asia/Shanghai)

## Evidence Legend

| Mark | Meaning |
| --- | --- |
| D | Official AtomGit API documentation |
| L | Live read against `https://api.atomgit.com` |
| M | Manual end-to-end verification with a personal PAT |
| S | Local fixture or automated test |

## Endpoints

| Source | Endpoint | Auth | Evidence |
| --- | --- | --- | --- |
| Personal activity | `GET /api/v5/users/{username}/events` | Required | D, L, M, S |
| Repository activity | `GET /api/v5/repos/{owner}/{repo}/events` | Optional; a token adds private-repository access | D, L, S |

Official references:

- [Personal activity](https://atomgit-api-doc.atomgit.com/10.users/177.get_user_personal_dynamics.html)
- [Repository activity](https://atomgit-api-doc.atomgit.com/1.repositories/37.get_repository_activity.html)

## Personal Activity

An anonymous request returned `401`, confirming that this endpoint is not public. A
personal PAT was then used to complete the application login and personal activity flow
end to end. The PAT was entered locally and is not stored in this repository.

Documented response shape:

```json
{
  "events": {
    "2026-08-27": [
      {
        "action": 5,
        "action_name": "pushed to",
        "author_username": "example",
        "created_at": "2026-08-27T10:34:05.093Z",
        "project_name": "owner/repo",
        "push_data": {
          "commit_count": 1,
          "ref": "main",
          "commit_to": "abc123",
          "commit_title": "Update docs"
        }
      }
    ]
  },
  "next": "2026-08-01T10:10:40.370Z"
}
```

Important behavior:

- `events` is keyed by date, not a flat array.
- `next` is an opaque time cursor.
- A repeated or missing `next` cursor terminates pagination.
- The endpoint must receive the current username in the path.
- Authentication uses the shared `Authorization: Bearer` transport; the token is not
  placed in the query string.

## Repository Activity

A live anonymous request to the public `hust-open-atom-club/atomgit-cli` repository
returned `200`. The experiment covered pages 1 and 2, `per_page=3`, `filter=push`, and an
`author` filter. The response uses this envelope:

```json
{
  "events": [
    {
      "action": 33,
      "action_name": "opened",
      "author": {
        "username": "example",
        "name": "Example",
        "avatar_url": "https://cdn.example/avatar.png"
      },
      "created_at": "2026-11-04T08:36:13.234Z",
      "project_name": "owner/repo",
      "target_title": "Stabilize activity feed",
      "target_type": "Note",
      "note": {
        "id": 198227526,
        "noteable_iid": 349,
        "noteable_type": "MergeRequest"
      },
      "_links": {
        "project": "https://atomgit.com/owner/repo",
        "action_type": "https://atomgit.com/owner/repo/merge_requests/349#note_198227526"
      }
    }
  ],
  "has_next_page": true
}
```

Observed differences from the documentation:

- The documentation declares `has_next_page` as an integer, while the live endpoint
  returned a boolean. The DTO and adapter accept both forms.
- Actual events can contain `note`, `target_*`, `push_data`, and `_links` fields that are
  not present in the smaller documented example.
- A comment's `target_iid` can identify the comment rather than the pull request. The
  adapter parses the `/merge_requests/{number}` or `/issues/{number}` path from
  `_links.action_type` first and uses `note.noteable_iid` only as a fallback.

## Mapping and Pagination Decisions

- Personal activity uses `CursorPageRequest`; repository activity uses
  `OffsetPageRequest`.
- Both endpoints map into the shared `Page<ActivityItem>` and preserve `ApiError`.
- Events are deduplicated with the action, actor, repository, timestamp, target, note ID,
  and push destination because the API does not provide a reliable event ID.
- Unknown event types retain a generic label and do not fail the entire page.
- The first Activity version selects one project at a time. It does not claim that a
  single project's feed covers all selected projects.

## Remaining Live Checks

- Sort order for events sharing the same `created_at` value.
- Whether `next` can overlap with the previous date bucket across several pages.
- Private repository behavior with valid and insufficient tokens.
- Device-level pull-to-refresh, list restoration, and avatar loading.

# AtomGit Mobile for HarmonyOS

AtomGit (atomgit.com) provides repository hosting, issue tracking, pull requests and CI pipelines. This project is its native HarmonyOS client: an OpenAPI-backed mobile workspace that focuses on two things, following the recent activity of yourself and selected projects, and handling the todos assigned to you.

## Basic information

| Item | Value |
| --- | --- |
| Bundle name | `com.atomgit.mobile` |
| Stack | ArkTS + ArkUI, Stage model, MVVM + Repository |
| Target | HarmonyOS phones, tablets and 2-in-1, HarmonyOS SDK 6.1.1 (API 24) |
| Runtime fallbacks | Immersive materials and `PATCH` requests need API 26; below that the app draws blurred glass surfaces and rejects `PATCH` with `405` |
| API | AtomGit OpenAPI v5 (`https://api.atomgit.com/api/v5`), Actions v8 |
| API docs | [AtomGit OpenAPI](https://docs.atomgit.com/docs/apis/) |
| Status | Project skeleton initialized, feature development not started |

## License

BSD-2-Clause, see [LICENSE](LICENSE).

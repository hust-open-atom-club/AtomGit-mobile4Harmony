# Agents Guidelines for AtomGit Mobile for HarmonyOS

A native HarmonyOS client for [AtomGit](https://atomgit.com), written in ArkTS with ArkUI on
the Stage model. It reads the AtomGit OpenAPI and focuses on two things: the recent activity
of the current user and of selected projects, and the todos assigned to the current user.
The authoritative description of the work is the task document in
[`opensource-intern`](https://github.com/hust-open-atom-club/opensource-intern/blob/main/openatom_club_atomgit_mobile_harmonyos.md).

## Build and Test

Development uses DevEco Studio 6.x with the HarmonyOS SDK 6.1.1 (API 24).

| Command | What it does |
| --- | --- |
| Run in DevEco Studio | Build, sign and install on a device or emulator |
| Test in DevEco Studio | Run the local unit tests and the instrumented tests |
| `hvigorw assembleHap` | Command-line build; needs the DevEco Studio toolchain and `DEVECO_SDK_HOME` |

Signing is never stored in the repository: `signingConfigs` in `build-profile.json5` is empty
and signing is configured locally in DevEco Studio. The hvigor wrapper (`hvigorw`,
`hvigor/hvigor-wrapper.js`) is not vendored yet, so a command-line build currently requires
the DevEco Studio installation.

## Language

Everything in this repository is written in English: code, identifiers, comments, resource
strings, documentation, commit messages, and pull request titles and descriptions.

## Commit Style

Adapted from [Asterinas](https://github.com/asterinas/asterinas), see its
[process guidelines](https://github.com/asterinas/asterinas/blob/main/book/src/to-contribute/coding-guidelines/for-maintainability/process.md).

- Imperative subject, at most 72 characters, no type prefix and no trailing period; wrap
  identifiers in backticks: `` Fix color mode setup in `EntryAbility` ``.
- Frequent openers: `Fix`, `Add`, `Remove`, `Refactor`, `Rename`, `Implement`, `Enable`,
  `Clean up`, `Bump`.
- Add a blank line and a short body explaining the *why* when the change needs it.
- One logical change per commit; keep preparatory refactoring in its own commit.
- Fix review findings by amending or rebasing the commit that introduced them, not by
  appending fixup commits.

## Pull Requests and Merging

Also adapted from Asterinas. Work happens in a personal fork; the upstream repository is only
a target for pull requests.

- One topic per pull request, titled and described in English, in the imperative mood.
- Build and tests pass before requesting review; mention unrelated failures in the description.
- Merged with **rebase and merge**: `main` stays linear with no merge commits and every commit
  lands individually, so keep the branch history clean.
- Push topic branches to your own fork and open a pull request against `main`; never push to
  `main` directly.

## References

| Project | Use |
| --- | --- |
| [AtomGit CLI](https://atomgit.com/hust-open-atom-club/atomgit-cli) ([mirror](https://github.com/hust-open-atom-club/atomgit-cli)) | Reference command-line client built on the AtomGit API |
| [AtomGit OpenAPI](https://docs.atomgit.com/docs/apis/) | REST API v5 and Actions v8 reference |
| [AtomGit OAuth](https://docs.atomgit.com/docs/apis/oauth/) | OAuth registration and authorization flows |

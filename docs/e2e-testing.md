# End-to-End Testing

The project uses the native HarmonyOS test stack:

- Hypium for test cases, assertions, and lifecycle hooks.
- HarmonyOS UiTest (`@kit.TestKit`) for finding components, entering text, tapping,
  scrolling, and pressing Back.
- The `entry/src/ohosTest` target for tests that move from a host machine to a
  HarmonyOS device or emulator.

## Current Coverage

`entry/src/test` contains local unit and contract tests. It covers repository mapping,
paging, cancellation state, ViewModels, login state, token storage helpers, and Activity
behavior without requiring a device.

`entry/src/ohosTest` now contains a device UI test harness:

1. Render the production `LoginPage`.
2. Enter a deterministic test token into `login_token_input`.
3. Submit through the production `SessionStore`.
4. Verify that the production `ActivityPage` opens and renders the personal activity.
5. Switch to project activity and verify that project events render.

The harness uses fake Repository and credential-storage implementations. It does not
contain a real PAT and does not depend on mutable public AtomGit data.

## Build Locally

Local unit and contract tests:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
--mode module -p module=entry@default -p product=default test
```

Build the device test HAP:

```bash
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
--mode module -p module=entry@ohosTest -p product=default assembleHap
```

The resulting unsigned test package is:

```text
entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap
```

## Run on a Device

1. Connect a HarmonyOS device with USB debugging enabled, or start a matching emulator.
2. Configure a debug signing profile in DevEco Studio.
3. Open the project in DevEco Studio.
4. Run the `entry` `ohosTest` target on the selected device.

The command-line test runner path is:

```text
/ets/testrunner/OpenHarmonyTestRunner
```

Do not place PATs, signing material, or private test data in the repository.

## Test Boundaries

The current UI test host mounts the real Login, Session, Activity Store, and Activity
page components with deterministic dependencies. It does not yet launch the complete
production `EntryAbility` and bottom-tab `Index` shell.

## Device Result

The device suite was executed on the local `Pura 90` emulator running HarmonyOS
6.1.1 (API 24):

```text
Tests run: 2, Failure: 0, Error: 0, Pass: 2, Ignore: 0
```

The real application HAP was also installed and started on the same emulator; the login
page rendered successfully. The emulator accepted the unsigned debug HAPs. Physical
devices and release testing still require a locally configured signing profile.

The next device-enabled steps are:

1. Add the full `EntryAbility` and bottom-tab path once test-mode app composition is
   available.
2. Add real AtomGit smoke tests using a dedicated account and locally supplied PAT.
3. Cover global 401 invalidation, refresh failure, paging overlap, and process restart.

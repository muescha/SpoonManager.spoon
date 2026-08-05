# Network Integration Tests

The regular test suite must not download from the network. Network tests are opt-in
and should use a local JSON config copied from:

```text
tests/integration/network.example.json
```

Suggested local file:

```text
tests/integration/network.local.json
```

`network.local.json` should stay uncommitted. It can contain real repositories,
release assets, and remote ZIP URLs that are stable enough for end-to-end testing.

## Goals

- Test real GitHub archive downloads.
- Test real GitHub release asset downloads.
- Test real remote ZIP downloads.
- Install only into a temporary Hammerspoon config directory.
- Never touch the user's real `~/.hammerspoon`.
- Keep all network examples explicit and opt-in.

## Config Shape

```json
{
  "version": 1,
  "installRoot": "/tmp/spoonmanager-network-test",
  "installPathTemplate": "{installRoot}/testinstalls/{timestamp}/{id}",
  "cleanup": {
    "allTests": {
      "installRootBeforeAllTests": false,
      "installRootAfterAllTests": false
    },
    "test": {
      "installPathBeforeTest": true,
      "installPathAfterTest": false
    }
  },
  "pathTemplates": {
    "explain": "tests/integration/network.test.{timestamp}.{id}.explain.json",
    "result": "tests/integration/network.test.{timestamp}.{id}.result.json",
    "log": "tests/integration/network.test.{timestamp}.{id}.log.json"
  },
  "tests": []
}
```

`installRoot` is the container for all network test artifacts. It defaults to:

```text
/tmp/spoonmanager-network-test
```

`installPathTemplate` becomes the fake Hammerspoon config directory template for
each network test. The runner expands placeholders before each test and loads
SpoonManager with that test-specific `hs.configdir`.

`pathTemplates.explain` controls the exact JSON snapshot path written for each
network test. It describes the planned SpoonManager command. Relative paths are
resolved from the repository root.

`pathTemplates.result` controls the exact JSON path for the test-run result. It
records whether the test passed, which source and target were used, where the
test installed files, and any error if the run failed.

`pathTemplates.log` controls the exact JSON path for structured log output captured
from the Hammerspoon logger stub. This includes debug messages emitted through
`logger.df(...)`.

Supported placeholders:

```text
{installRoot}
{installPath}
{id}
{sourceType}
{name}
{timestamp}
```

With the example template, installed Spoons land below:

```text
/tmp/spoonmanager-network-test/testinstalls/{timestamp}/{id}/Spoons/{name}.spoon
```

`timestamp` is generated once per runner invocation in a path-friendly UTC form:

```text
YYYY-MM-DD-HH-MM-SS
```

This keeps tests that install the same Spoon name from overwriting each other and
keeps separate network test runs available for inspection.

## Cleanup

Cleanup is split by scope.

`cleanup.allTests.installRootBeforeAllTests` removes the whole `installRoot`
before the first enabled test starts. It defaults to false so older timestamped
runs remain available for inspection.

`cleanup.allTests.installRootAfterAllTests` removes the whole `installRoot` after
the runner finishes. It defaults to false. Enable it for CI-style runs where no
artifacts should remain.

`cleanup.test.installPathBeforeTest` removes the resolved per-test install path
before that test starts. It defaults to true so every enabled test starts from a
fresh fake Hammerspoon config directory.

`cleanup.test.installPathAfterTest` removes the resolved per-test install path
after that test finishes. It defaults to false so the installed files remain
available for inspection.

Each test may override `installPathTemplate`, `pathTemplates.*`, and
`cleanup.test.*` if a specific case should use a different location or cleanup
behavior.

For safety, the runner only accepts install roots below `/tmp/` whose path contains
`spoonmanager`.

Each enabled test writes three JSON artifacts:

```text
tests/integration/network.test.{timestamp}.{test-id}.explain.json
tests/integration/network.test.{timestamp}.{test-id}.result.json
tests/integration/network.test.{timestamp}.{test-id}.log.json
```

These files are run artifacts and are ignored by git.

The result artifact has this general shape:

```json
{
  "id": "github-folder",
  "success": true,
  "timestamp": "2026-08-05-14-30-12",
  "installRoot": "/tmp/spoonmanager-network-test",
  "installPath": "/tmp/spoonmanager-network-test/testinstalls/...",
  "explainPath": "...explain.json",
  "runnerPath": "...result.json",
  "logPath": "...log.json",
  "source": {},
  "target": {},
  "install": {},
  "secondInstall": {}
}
```

On failure, `success` is false and `error` contains the traceback. The runner keeps processing later enabled tests and reports all failures in test order at the end.

The log artifact has this shape:

```json
{
  "id": "github-folder",
  "success": true,
  "timestamp": "2026-08-05-14-30-12",
  "logs": [
    {
      "level": "debug",
      "message": "Inferred Spoon name 'WindowSigils' from source path 'Source/WindowSigils.spoon'"
    }
  ]
}
```

Each test entry has this shape:

```json
{
  "id": "github-folder",
  "enabled": true,
  "description": "Install a Spoon from a folder inside a GitHub repository archive.",
  "source": {},
  "target": {},
  "expect": {
    "files": [
      "init.lua"
    ]
  }
}
```

`enabled` lets a user keep examples in the file without running all of them.

## Source Types

### `github-folder`

Installs one explicit folder from a GitHub repository archive.

```json
{
  "source": {
    "type": "github-folder",
    "repository": "Hammerspoon/Spoons",
    "branch": "master",
    "folder": "Source/WindowSigils.spoon"
  },
  "target": {
    "name": "WindowSigils"
  }
}
```

Equivalent builder:

```lua
spoon.SpoonManager.from.github("Hammerspoon/Spoons", {
    branch = "master",
})
    .folder("Source/WindowSigils.spoon")
    .withName("WindowSigils")
    .install()
```

### `spoon-repo`

Installs a named Spoon from the preferred source-folder convention:

```text
Source/{name}.spoon
```

```json
{
  "source": {
    "type": "spoon-repo",
    "repository": "Hammerspoon/Spoons",
    "branch": "master"
  },
  "target": {
    "spoon": "WindowSigils"
  }
}
```

Equivalent builder:

```lua
spoon.SpoonManager.from.spoonRepo("Hammerspoon/Spoons", {
    branch = "master",
})
    .spoon("WindowSigils")
    .install()
```

### `spoon-repo-zip`

Installs a named Spoon from the legacy ZIP convention:

```text
Spoons/{name}.spoon.zip
```

```json
{
  "source": {
    "type": "spoon-repo-zip",
    "repository": "Hammerspoon/Spoons",
    "branch": "master"
  },
  "target": {
    "spoon": "WindowSigils"
  }
}
```

Equivalent builder:

```lua
spoon.SpoonManager.from.spoonRepoZip("Hammerspoon/Spoons", {
    branch = "master",
})
    .spoon("WindowSigils")
    .install()
```

### `github-repository`

Installs a Spoon where the repository root is the Spoon root.

```json
{
  "source": {
    "type": "github-repository",
    "repository": "owner/TestSpoon.spoon",
    "branch": "main"
  },
  "target": {
    "name": "TestSpoon"
  }
}
```

Equivalent builder:

```lua
spoon.SpoonManager.from.github("owner/TestSpoon.spoon", {
    branch = "main",
})
    .withName("TestSpoon")
    .install()
```

### `github-release`

Installs a GitHub release ZIP asset. The asset must point to a `.zip` file.

```json
{
  "source": {
    "type": "github-release",
    "repository": "owner/TestSpoon.spoon",
    "release": "latest",
    "asset": "TestSpoon.zip"
  },
  "target": {
    "name": "TestSpoon"
  }
}
```

Equivalent builder:

```lua
spoon.SpoonManager.from.github("owner/TestSpoon.spoon")
    .releaseLatest()
    .asset("TestSpoon.zip")
    .withName("TestSpoon")
    .install()
```

For a fixed release:

```json
{
  "source": {
    "type": "github-release",
    "repository": "owner/TestSpoon.spoon",
    "release": "v1.2.3",
    "asset": "TestSpoon.zip"
  }
}
```

Equivalent builder:

```lua
spoon.SpoonManager.from.github("owner/TestSpoon.spoon")
    .release("v1.2.3")
    .asset("TestSpoon.zip")
    .withName("TestSpoon")
    .install()
```

### `remote-zip`

Installs an arbitrary remote ZIP URL. This should be used sparingly because it is
not tied to a known repository provider.

```json
{
  "source": {
    "type": "remote-zip",
    "url": "https://example.com/TestSpoon.zip"
  },
  "target": {
    "name": "TestSpoon"
  }
}
```

Equivalent builder:

```lua
spoon.SpoonManager.from.remoteZip("https://example.com/TestSpoon.zip")
    .withName("TestSpoon")
    .install()
```

## Optional Source Fields

Provider-based source types may include:

```json
{
  "baseUrl": "https://github.example.com",
  "branch": "main",
  "ref": "v1.2.3",
  "defaultBranch": "main"
}
```

`branch` and `ref` are selected revisions. They are mutually exclusive.

`defaultBranch` is only a fallback used when neither `branch` nor `ref` is set.
It should not prevent a test entry from overriding the branch later.

## Target Fields

Use `target.spoon` when the source type uses a Spoon name pattern:

```json
{
  "target": {
    "spoon": "WindowSigils"
  }
}
```

Use `target.name` when the source does not determine the install name clearly,
or when the test should explicitly rename the installed Spoon:

```json
{
  "target": {
    "name": "WindowSigils"
  }
}
```

If both are present, the future runner should apply `.spoon(target.spoon)` first
and `.withName(target.name)` second.

## Expected Checks

Each test can list files that must exist after installation:

```json
{
  "expect": {
    "files": [
      "init.lua",
      "docs.json"
    ]
  }
}
```

Paths are relative to the installed Spoon directory:

```text
{resolvedInstallRoot}/Spoons/{resolvedName}.spoon
```

The first implementation only needs file-existence checks. Later checks can add
result fields, registry checks, and local-change update behavior.

## Runner Usage

The runner is:

```text
tests/integration/network.lua
```

Suggested workflow:

```sh
cp tests/integration/network.example.json tests/integration/network.local.json
```

Then edit `network.local.json`, set one or more tests to:

```json
{
  "enabled": true
}
```

Run:

```sh
/Users/muescha/.local/share/mise/installs/lua/5.4.4/bin/lua \
  tests/integration/network.lua \
  tests/integration/network.local.json
```

The runner:

1. Refuse to run unless a local config path is explicitly passed.
2. Load the JSON config.
3. Optionally clean `installRoot` before all tests.
4. Resolve the test install path from `installPathTemplate`.
5. Optionally clean the test-specific install path before the test.
6. For each `enabled` test, build the corresponding SpoonManager definition.
7. Point the Hammerspoon stub at the test-specific install path.
8. Write the path resolved from `pathTemplates.explain`.
9. Run `definition.install()` synchronously.
10. Verify expected files below the temporary install path.
11. Run the same install again and assert `result.skipped == true`.
12. Write the path resolved from `pathTemplates.result`.
13. Write the path resolved from `pathTemplates.log`.
14. Print the resolved install path.
15. Optionally clean the test-specific install path after the test.
16. Optionally clean `installRoot` after all tests.
17. Print an ordered failure summary and exit with code 1 when any enabled test failed.

The first implementation intentionally does not run update/local-change checks yet.
Those can be added once the happy-path network installs are stable.

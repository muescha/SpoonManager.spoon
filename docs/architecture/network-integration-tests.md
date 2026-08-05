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
  "templateInstallPath": "/tmp/spoonmanager-network-test/testinstalls/{timestamp}/{id}",
  "cleanInstallRoot": true,
  "explainDir": "tests/integration",
  "tests": []
}
```

`templateInstallPath` becomes the fake Hammerspoon config directory template for
each network test. The runner expands placeholders before each test and loads
SpoonManager with that test-specific `hs.configdir`.

Supported placeholders:

```text
{id}
{sourceType}
{name}
{timestamp}
```

With the example template, installed Spoons land below:

```text
/tmp/spoonmanager-network-test/testinstalls/{timestamp}/{id}/Spoons/{name}.spoon
```

`timestamp` is generated once per runner invocation in compact UTC ISO form:

```text
YYYYMMDDTHHMMSSZ
```

This keeps tests that install the same Spoon name from overwriting each other and
keeps separate network test runs available for inspection.

`installRoot` is still accepted for a single shared root, but `templateInstallPath`
is preferred for network tests.

When `cleanInstallRoot` is true, the runner removes each resolved install root
before running that test. The default is true. The runner does not remove the
install root after the test, so files remain available for inspection. Use a
`{timestamp}` segment in `templateInstallPath` when you want each run to keep its
own result folder.

Each test may override `templateInstallPath` and `cleanInstallRoot` if a specific
case should use a different location or force a fresh install.

For safety, the runner only accepts install roots below `/tmp/` whose path contains
`spoonmanager`.

`explainDir` controls where per-test explanation snapshots are written. Relative
paths are resolved from the repository root.

Each enabled test writes:

```text
{explainDir}/network.test.{test-id}.explain.json
```

These files are run artifacts and are ignored by git.

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
3. Resolve the test install root from `templateInstallPath`.
4. For each `enabled` test, build the corresponding SpoonManager definition.
5. Point the Hammerspoon stub at the test-specific install root.
6. Write `network.test.{test-id}.explain.json`.
7. Run `definition.install()` synchronously.
8. Verify expected files below the temporary install root.
9. Run the same install again and assert `result.skipped == true`.
10. Print the resolved install root so the files can be inspected after the run.

The first implementation intentionally does not run update/local-change checks yet.
Those can be added once the happy-path network installs are stable.

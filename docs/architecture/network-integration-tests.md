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
  "tests": []
}
```

`installRoot` becomes the fake Hammerspoon config directory for the network test.
Installed Spoons should land below:

```text
{installRoot}/Spoons/{name}.spoon
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
{installRoot}/Spoons/{resolvedName}.spoon
```

The first implementation only needs file-existence checks. Later checks can add
result fields, registry checks, and local-change update behavior.

## Runner Plan

The future runner should:

1. Refuse to run unless a local config path is explicitly passed.
2. Load the JSON config.
3. Point the Hammerspoon stub at `installRoot`.
4. For each `enabled` test, build the corresponding SpoonManager definition.
5. Run `definition.install()` synchronously.
6. Verify expected files below the temporary install root.
7. Run the same install again and assert `result.skipped == true`.
8. Optionally run `definition.update()` and verify local-change behavior.

Suggested command:

```sh
/Users/muescha/.local/share/mise/installs/lua/5.4.4/bin/lua \
  tests/integration/network.lua \
  tests/integration/network.local.json
```

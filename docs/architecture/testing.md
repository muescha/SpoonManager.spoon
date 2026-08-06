# Testing Strategy

This note describes how SpoonManager should add tests without losing the examples-first feel of the builder API.

## Goals

- Keep tests simple enough to run without a full Hammerspoon app.
- Use tests as executable examples for the public API.
- Protect the builder DSL from accidental behavior changes.
- Test installation behavior without downloading from the network by default.
- Make edge cases readable for humans, agents, and future contributors.

## Test Style

SpoonManager should start with plain Lua tests and a small test harness.

That keeps the project easy to run:

```sh
lua tests/run.lua
```

For version 1, SpoonManager should not use an external test framework. The project should provide its own tiny runner in `tests/run.lua`.

The runner should provide only the small primitives the project needs:

```lua
test(name, fn)
assertEqual(actual, expected)
assertTrue(value)
assertFalse(value)
assertError(fn, expectedMessagePattern)
assertMatchesJson(snapshotPath, actual)
```

A larger Lua test framework can come later if the project outgrows this. For now, the most valuable tests are examples with assertions and golden JSON snapshots.

Use two complementary assertion styles:

- focused field assertions for precise failures
- golden JSON snapshots for complete, readable examples

Focused assertions make it obvious which behavior broke. Golden JSON makes the whole generated explanation visible at once.

Example shape:

```lua
test("default spoon zip", function()
    local definition =
        SpoonManager.from.default
            .spoon("Emojis")
            .toConfig()

    assertEqual(definition.source.type, "github")
    assertEqual(definition.source.revision_branch, "master")
    assertEqual(definition.source.pattern_spoonZipPattern, "Spoons/{name}.spoon.zip")
    assertEqual(definition.target.selection_spoon, "Emojis")
end)
```

This reads almost like documentation, but still fails when the API changes unexpectedly.

The same test can also compare the complete explanation against a golden JSON file:

```lua
test("default spoon zip explanation snapshot", function()
    local explanation =
        SpoonManager.from.default
            .spoon("Emojis")
            .command("install")
            .explain()

    assertMatchesJson("examples/default_spoon.lua.explain.json", explanation)
end)
```

The golden file is readable by itself:

```json
{
  "source": {
    "type": "github",
    "provider": "github",
    "repository": "Hammerspoon/Spoons",
    "baseUrl": "https://github.com",
    "revision_branch": "master",
    "pattern_spoonZipPattern": "Spoons/{name}.spoon.zip"
  },
  "target": {
    "selection_spoon": "Emojis"
  },
  "resolved": {
    "installName": "Emojis",
    "sourceType": "remote-zip",
    "url": "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Emojis.spoon.zip"
  },
  "command": {
    "action": "install",
    "from": {
      "type": "remote-zip",
      "url": "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Emojis.spoon.zip"
    },
    "to": {
      "type": "spoon",
      "name": "Emojis",
      "path": "<spoons>/Emojis.spoon"
    }
  }
}
```

This is useful because a reviewer can see the complete API contract without mentally reconstructing it from many single-field assertions.

## Golden JSON Snapshots

Golden JSON snapshots make sense for stable public or semi-public structures:

- `definition.toConfig()`
- resolver `resolved` output
- resolver `command` output
- `definition.command("install").explain()` output
- selected `installed.json` records after normalizing dynamic values

They are less useful for unstable runtime data unless the test normalizes dynamic fields first.

Examples of fields to normalize before snapshot comparison:

```text
installedAt
updatedAt
path
fingerprints.localHash
temporary directories
```

Snapshot tests should use canonical JSON:

- sorted object keys
- consistent indentation
- no platform-specific temporary paths
- no timestamps unless replaced with placeholders

The same snapshot assertion should support two modes.

Normal mode checks the current result against the committed snapshot:

```sh
lua tests/run.lua
```

Update mode writes or refreshes the snapshot file:

```sh
SPOONMANAGER_UPDATE_SNAPSHOTS=1 lua tests/run.lua
```

This avoids separate "snapshot creation tests". The same test creates or verifies its snapshot depending on the environment.

Conceptual helper:

```lua
function assertMatchesJson(snapshotPath, actual)
    local normalized = normalizeForSnapshot(actual)
    local json = encodeCanonicalJson(normalized)
    local fullPath = pathJoin(repoRoot, "tests", snapshotPath)

    if os.getenv("SPOONMANAGER_UPDATE_SNAPSHOTS") == "1" then
        writeFile(fullPath, json)
        return
    end

    local expected = readFile(fullPath)
    if expected ~= json then
        error("Snapshot mismatch: " .. snapshotPath)
    end
end
```

Updating snapshots should be an explicit developer action. After running update mode, the developer reviews the git diff and commits the snapshot changes only when the new output is intentional.

Example normalized installed snapshot:

```json
{
  "Emojis": {
    "name": "Emojis",
    "installedAt": "<timestamp>",
    "updatedAt": "<timestamp>",
    "path": "<spoons>/Emojis.spoon",
    "definition": {
      "source": {
        "type": "github",
        "provider": "github",
        "repository": "Hammerspoon/Spoons",
        "baseUrl": "https://github.com",
        "revision_branch": "master",
        "pattern_spoonZipPattern": "Spoons/{name}.spoon.zip"
      },
      "target": {
        "selection_spoon": "Emojis"
      }
    },
    "resolved": {
      "installName": "Emojis",
      "sourceType": "remote-zip",
      "url": "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Emojis.spoon.zip"
    },
    "fingerprints": {
      "localHash": "<sha256>"
    }
  }
}
```

The rule of thumb:

```text
assert fields for behavior
snapshot explain JSON for complete examples
```

Do not replace all field assertions with snapshots. A failed snapshot is great for visual review, but a focused assertion usually gives the better failure message. For user-facing example tests, prefer one `explain()` snapshot per example. Unit tests can still assert `toConfig()`, `resolveDefinition()`, and `toCommand()` directly.

## Hammerspoon Stub

Most tests can run in normal Lua if they provide a minimal `hs` stub.

The stub should cover only the APIs SpoonManager actually needs:

```lua
hs = {
    configdir = "/tmp/hammerspoon-test",
    logger = {
        new = function()
            return {
                df = function() end,
                ef = function() end,
                i = function() end,
                w = function() end,
            }
        end,
    },
    spoons = {
        scriptPath = function()
            return repoRoot
        end,
        use = function()
            return true
        end,
    },
    fs = {
        pathToAbsolute = function(path)
            return path:gsub("^~", "/Users/test")
        end,
        attributes = function()
            return nil
        end,
    },
    execute = function()
        return "", true
    end,
}
```

The stub should live in one shared helper so every test starts from the same fake Hammerspoon environment.

## What To Test First

### Builder Definitions

These tests protect the public API.

Examples:

```lua
SpoonManager.from.github("owner/repo")
    .branch("main")
    .folder("Source/A.spoon")
    .withName("BetterA")
    .toConfig()
```

Expected:

```lua
{
    source = {
        type = "github",
        repository = "owner/repo",
        revision_branch = "main",
    },
    target = {
        selection_folder = "Source/A.spoon",
        name_withName = "BetterA",
    },
}
```

Useful cases:

- `from.default.spoon("Emojis")`
- `from.github("owner/repo").folder("Source/A.spoon")`
- `from.github("owner/repo").releaseLatest().asset("A.zip")`
- `from.github("owner/repo").release("v1.2.0").asset("A.zip")`
- `from.remoteZip("https://example.com/A.zip")`
- `from.localZip("~/Downloads/A.zip")`
- `from.localFolder("~/Projects/A.spoon")`
- `from.config(definition).toConfig()`

### Name Inference

Name inference is a perfect test target because it is small, important, and easy to document.

Examples:

```text
name.zip                     -> name
name.spoon.zip               -> name
name.spoon                   -> name
folder/lastfoldername        -> lastfoldername
folder/lastfoldername.spoon  -> lastfoldername
user/reponame                -> reponame
user/reponame.spoon          -> reponame
```

These tests also double as documentation for users who omit `withName(...)`.

### Exclusive Builder Groups

These tests prevent hidden magic from creeping back in.

Useful cases:

```lua
SpoonManager.from.github("owner/repo")
    .branch("main")
    .ref("v1.2.0")
```

Expected error:

```text
branch('main') already set; cannot call ref('v1.2.0').
```

More cases:

- `branch(...)` then `ref(...)`
- `ref(...)` then `branch(...)`
- `spoonZipPattern(...)` then `spoonFolderPattern(...)`
- `spoon(...)` then `folder(...)`
- `folder(...)` then `asset(...)`
- `withName(...)` then `withName(...)`
- source-changing method after final selection, for example `spoon("A").branch("main")`

### Resolver Commands

Resolver tests are the bridge between definitions and executable work.

Examples:

```lua
SpoonManager.from.default
    .spoon("Emojis")
```

Expected command:

```lua
{
    from = {
        type = "remote-zip",
        url = "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Emojis.spoon.zip",
    },
    to = {
        type = "spoon",
        name = "Emojis",
    },
}
```

Useful cases:

- GitHub repository root -> `github-repository`
- GitHub folder -> `github-folder`
- GitHub release latest asset -> `github-release`
- GitHub release tag asset -> `github-release`
- GitHub Spoon ZIP pattern -> `remote-zip`
- GitHub Spoon folder pattern -> `github-folder`
- local folder with `folder(...)` -> joined local path
- local ZIP -> local ZIP command
- remote ZIP -> remote ZIP command

### Installer Behavior

Installer tests should avoid network by using local folders and local ZIPs.

Useful cases:

- install from local folder into a temporary `Spoons` directory
- install from flat local ZIP
- install from ZIP containing `Name.spoon/`
- install from ZIP containing one root folder with `init.lua`
- `install()` skips when target already exists
- `update()` checks the stored checksum
- unmanaged existing Spoon aborts by default
- unmanaged existing Spoon can be backed up
- locally changed managed Spoon aborts by default
- locally changed managed Spoon can be backed up or overwritten
- `use(...)` calls `hs.spoons.use(...)` with the expected options

These tests are more integration-heavy than builder and resolver tests, but they are the ones that protect user data.

### Registry

Registry tests should use a temporary config directory.

Useful cases:

- creates `.config/SpoonManager/installed.json`
- stores original `definition`
- stores `resolved`
- stores effective execution `source`
- stores `fingerprints.localHash`
- preserves `installedAt` and updates `updatedAt`
- reads unknown or missing registry as an empty table

### Validation

Validation tests make error messages stable and helpful.

Useful cases:

- non-string builder arguments are rejected
- remote ZIP URL must end in `.zip`
- local ZIP path must end in `.zip`
- release asset must end in `.zip`
- definition without an inferable name asks for `withName("Name")`
- unsupported source types fail clearly

## Example Tests As Documentation

The test files should be named by user-facing capability, not by internal module only.

Suggested layout:

```text
tests/
├── run.lua
├── helpers/
│   ├── hammerspoon_stub.lua
│   ├── assertions.lua
│   └── fixtures.lua
├── examples/
│   ├── default_spoon.lua
│   ├── default_spoon.lua.explain.json
│   ├── github_folder.lua
│   ├── github_folder.lua.explain.json
│   ├── github_release.lua
│   ├── github_release.lua.latest.explain.json
│   ├── github_release.lua.tag.explain.json
│   ├── local_folder.lua
│   └── local_zip.lua
├── unit/
│   ├── name_resolver_test.lua
│   ├── definition_test.lua
│   ├── resolver_test.lua
│   └── registry_test.lua
└── integration/
    └── installer_test.lua
```

The `tests/examples/` folder is important. Those files should be readable as "things you can do with SpoonManager".

Example:

```lua
return function(test, SpoonManager)
    test("install official Spoon by name", function()
        local definition =
            SpoonManager.from.default
                .spoon("TimeMachineProgress")
                .toConfig()

        assertEqual(definition.target.selection_spoon, "TimeMachineProgress")
    end)
end
```

Later, README examples can be generated or checked against these example tests.

## Network Tests

Network tests should be opt-in.

Default test runs should not call GitHub, GitLab, or any remote host.

Possible opt-in command:

```sh
SPOONMANAGER_NETWORK_TESTS=1 lua tests/run.lua
```

Network tests can verify:

- GitHub latest release URL redirects correctly
- GitHub archive URL exists
- official Spoon ZIP URL exists

They should not be required for normal development.

## Suggested Order

1. Add the tiny test harness and Hammerspoon stub.
2. Add executable example tests for the public builder API.
3. Add name inference tests.
4. Add exclusive group and validation tests.
5. Add resolver command tests.
6. Add local installer integration tests with temporary fixtures.
7. Add registry tests.
8. Add optional network smoke tests.

This order gives the highest value first: the public API gets locked down before the slower install/update behavior is tested.

## Recommendation

Yes, SpoonManager should have tests.

The first version should stay deliberately small: plain Lua, no network by default, and a strong `tests/examples/` section. That gives contributors confidence while also showing users what SpoonManager can do.

# SpoonManager.spoon

SpoonManager is an experimental Hammerspoon Spoon installer with explicit source configs and a small builder API.

## Goals

- Install known Spoons without loading a catalog first.
- Support classic Spoon ZIPs, flat ZIPs, local folders, GitHub repository roots, GitHub folders, and GitHub release assets.
- Keep `install()` synchronous so a Hammerspoon `init.lua` can use the Spoon immediately after installation.
- Keep `install()` idempotent: if the Spoon already exists, skip the download and only apply `.use(...)` options.
- Use `update()` when the external source should be fetched again.
- Protect existing local changes by default.
- Keep catalogs optional for later search, GUI, or SpoonHub-style workflows.

## Examples

Install from the default Hammerspoon Spoons repository:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .install()
```

Install from a Spoon source repository:

```lua
spoon.SpoonManager.from.spoonRepo("muescha/SpoonRepo", {
    branch = "main",
})
    .spoon("DeepFolder")
    .install()
```

Install from a folder inside a GitHub repository:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .branch("main")
    .path("Source/DeepFolder.spoon")
    .install()
```

Install a GitHub repository whose root is the Spoon:

```lua
spoon.SpoonManager.from.github("muescha/DeepFolder.spoon")
    .install()
```

Install from the latest GitHub release asset:

```lua
spoon.SpoonManager.from.github("muescha/DeepFolder.spoon")
    .releaseLatest()
    .zipFile("DeepFolder.zip")
    .install()
```

Install from a tagged GitHub release asset:

```lua
spoon.SpoonManager.from.github("muescha/DeepFolder.spoon")
    .release("v1.2.0")
    .zipFile("DeepFolder.zip")
    .install()
```

Install from a remote ZIP:

```lua
spoon.SpoonManager.from.remoteZip("https://example.com/DeepFolder.zip")
    .install()
```

Install from a local folder:

```lua
spoon.SpoonManager.from.localFolder("~/Projects/DeepFolder.spoon")
    .install()
```

Install from a local ZIP:

```lua
spoon.SpoonManager.from.localZip("~/Downloads/DeepFolder.zip")
    .install()
```

Rename only when the inferred name is not the name you want:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .path("Source/deepfolder")
    .withName("ManagedDeepFolder")
    .install()
```

Use a Spoon after installing it:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .use({
        start = true,
    })
    .install()
```

Add builders and install them together:

```lua
local emojis =
    spoon.SpoonManager.from.default
        .spoon("Emojis")
        .use({
            start = true,
        })

local deepFolder =
    spoon.SpoonManager.from.github("muescha/SpoonRepo")
        .path("Source/DeepFolder.spoon")

spoon.SpoonManager.add(emojis, deepFolder)
spoon.SpoonManager.install()
```

Update explicitly when you want SpoonManager to fetch the external source again:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .update()
```

## Setup

Install or symlink the Spoon into your Hammerspoon Spoons directory:

```sh
ln -s /path/to/SpoonManager.spoon ~/.hammerspoon/Spoons/SpoonManager.spoon
```

For development, use a symlink so changes in the repository are visible after a Hammerspoon reload:

```sh
ln -s /Users/muescha/Work/github.com/muescha/SpoonManager.spoon ~/.hammerspoon/Spoons/SpoonManager.spoon
```

Load SpoonManager in your `~/.hammerspoon/init.lua` before using it:

```lua
hs.loadSpoon("SpoonManager")
```

After `hs.loadSpoon("SpoonManager")`, Hammerspoon stores the returned Spoon object in:

```lua
spoon.SpoonManager
```

That is why the examples use `spoon.SpoonManager`.

Minimal setup:

```lua
hs.loadSpoon("SpoonManager")

spoon.SpoonManager.from.default
    .spoon("Emojis")
    .install()
```

You can also keep a local variable if you prefer shorter code:

```lua
hs.loadSpoon("SpoonManager")

local SpoonManager = spoon.SpoonManager

SpoonManager.from.default
    .spoon("Emojis")
    .install()
```

There is no separate `setup()` call right now. Loading the Spoon is enough.
Configuration is done by setting fields directly, for example:

```lua
hs.loadSpoon("SpoonManager")

spoon.SpoonManager.configDir =
    hs.configdir .. "/.config/SpoonManager"
```

## Local Changes

`install()` skips already installed Spoons.

`update()` fetches the source again. If the target Spoon exists and SpoonManager cannot prove that it is unchanged, update aborts by default.

Override per builder:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .onLocalChanges(spoon.SpoonManager.options.localChanges.backup)
    .install()
```

Allowed values:

- `spoon.SpoonManager.options.localChanges.abort`: default
- `spoon.SpoonManager.options.localChanges.backup`: move the existing Spoon aside first
- `spoon.SpoonManager.options.localChanges.overwrite`: replace the existing Spoon

The plain strings `"abort"`, `"backup"`, and `"overwrite"` also work, but the constants are easier for an LSP server to suggest.

## Name Inference

SpoonManager tries to infer the installed Spoon name when no explicit name is given.

The inferred name is normalized by removing these suffixes:

```text
.zip
.spoon
```

Suffixes are removed in order, so `WindowGrid.spoon.zip` becomes `WindowGrid.spoon` and then `WindowGrid`.

Examples:

| Input | Inferred Spoon name |
|---|---|
| `WindowGrid.zip` | `WindowGrid` |
| `WindowGrid.spoon.zip` | `WindowGrid` |
| `WindowGrid.spoon` | `WindowGrid` |
| `folder/WindowGrid` | `WindowGrid` |
| `folder/WindowGrid.spoon` | `WindowGrid` |
| `user/WindowTools` | `WindowTools` |
| `user/WindowTools.spoon` | `WindowTools` |
| `zipFile("WindowGrid.zip")` | `WindowGrid` |
| `zipFile("WindowGrid.spoon.zip")` | `WindowGrid` |

Remote ZIP URL:

```lua
spoon.SpoonManager.from.remoteZip("https://example.com/WindowGrid.spoon.zip")
    .install()
```

Installs as:

```text
WindowGrid
```

Local ZIP:

```lua
spoon.SpoonManager.from.localZip("~/Downloads/WindowGrid.zip")
    .install()
```

Installs as:

```text
WindowGrid
```

Local folder:

```lua
spoon.SpoonManager.from.localFolder("~/Projects/WindowGrid.spoon")
    .install()
```

Installs as:

```text
WindowGrid
```

GitHub repository root:

```lua
spoon.SpoonManager.from.github("user/WindowTools.spoon")
    .install()
```

Installs as:

```text
WindowTools
```

GitHub folder:

```lua
spoon.SpoonManager.from.github("user/repo")
    .path("Source/deepfolder.spoon")
    .install()
```

Installs as:

```text
deepfolder
```

GitHub release asset:

```lua
spoon.SpoonManager.from.github("user/repo")
    .releaseLatest()
    .zipFile("WindowGrid.spoon.zip")
    .install()
```

Installs as:

```text
WindowGrid
```

Use `.withName(name)` to override the inferred name:

```lua
spoon.SpoonManager.from.github("user/repo")
    .path("Source/deepfolder")
    .withName("BetterName")
    .install()
```

Installs as:

```text
BetterName
```

Name inference and explicit name overrides are logged at debug level. See [Logger](#logger).

## API

The API has two layers:

- `SpoonManager.from.*` factories create builders
- builder and manager actions install or update Spoons

All builder calls use dot notation and do not install anything until `install()` or `update()` is called.

A builder collects the source information, extraction selection, use options, and install options. It can start broad, such as a GitHub repository, and become more specific with calls like `path(...)`, `zipFile(...)`, `useFolder(...)`, or `withName(...)`.

The exported config table keeps user-provided values close to the builder calls:

```lua
{
    source = {
        type = "github",
        repository = "Hammerspoon/Spoons",
        revision_branch = "master",
        pattern_spoonZipPattern = "Spoons/{name}.spoon.zip",
    },
    target = {
        selection_spoon = "Emojis",
    },
}
```

`source` answers where the files come from. `target` answers which Spoon is selected and what local name it should use.

Builder arguments that describe names, paths, refs, URLs, patterns, releases, or assets must be strings. Passing a table, number, or another builder object raises an error instead of being converted with `tostring()`.

Builder methods do not silently overwrite each other. Each group can be set once per builder: revision (`branch`/`ref`), Spoon pattern, selection (`spoon`/`folder`/`asset`), release, target name (`withName`), and local-change behavior.

If you need another Spoon from the same repository, keep the broad base builder and create each selected Spoon from that base:

```lua
local official =
    spoon.SpoonManager.from.spoonRepo("Hammerspoon/Spoons", {
        branch = "master",
    })

local emojis =
    official
        .spoon("Emojis")

local windowSigils =
    official
        .spoon("WindowSigils")
```

Do not try to change the selected Spoon on an already selected builder:

```lua
local emojis =
    official
        .spoon("Emojis")

-- Error: selection_spoon('Emojis') already selected.
local windowSigils =
    emojis
        .spoon("WindowSigils")
```

### `SpoonManager.from.config(config)`

Creates a builder from a plain Lua table.

Use this when a config was previously exported with `builder.toConfig()` or loaded from a future manifest file.

Example:

```lua
local config =
    spoon.SpoonManager.from.default
        .spoon("Emojis")
        .use({
            start = true,
        })
        .toConfig()

spoon.SpoonManager.from.config(config)
    .install()
```

### `SpoonManager.from.github(repository[, options])`

Creates a GitHub repository builder.

`repository` is the GitHub repository in `owner/repo` form.

`options` may contain:

```lua
{
    branch = "main",
    ref = "main",
    defaultBranch = "main",
    baseUrl = "https://github.com",
}
```

If neither `branch` nor `ref` is given, SpoonManager uses `main`.

The default `main` is only applied when building GitHub URLs. It is not stored in exported configs unless you explicitly set `defaultBranch`, call `branch("main")`, or pass `{ branch = "main" }`.

`defaultBranch` is a URL fallback, not a selected branch. It does not block later `.branch(...)` or `.ref(...)` calls.

Example, repository root is the Spoon:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .install()
```

This infers the Spoon name as `MySpoon`.

Example, Spoon is in a subfolder:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo", {
    branch = "main",
})
    .path("Source/MySpoon.spoon")
    .install()
```

### `SpoonManager.from.spoonRepo(repository[, options])`

Creates a GitHub repository builder for the preferred Spoon source layout:

```text
Source/{name}.spoon
```

This is sugar for:

```lua
spoon.SpoonManager.from.github("owner/repo", options)
    .spoonFolderPattern("Source/{name}.spoon")
```

Use this when a repository contains one or more Spoon source folders and you
want to install by Spoon name without creating ZIP files.

Example:

```lua
spoon.SpoonManager.from.spoonRepo("muescha/SpoonRepo", {
    branch = "main",
})
    .spoon("MySpoon")
    .install()
```

This resolves to the folder:

```text
Source/MySpoon.spoon
```

### `SpoonManager.from.spoonRepoZip(repository[, options])`

Creates a GitHub repository builder for the legacy Spoon ZIP layout:

```text
Spoons/{name}.spoon.zip
```

This is sugar for:

```lua
spoon.SpoonManager.from.github("owner/repo", options)
    .spoonZipPattern("Spoons/{name}.spoon.zip")
```

Use this when a repository already publishes installable Spoon ZIP files.
For new repositories, prefer `SpoonManager.from.spoonRepo(...)`.

Example:

```lua
spoon.SpoonManager.from.spoonRepoZip("Hammerspoon/Spoons", {
    branch = "master",
})
    .spoon("Emojis")
    .install()
```

This resolves to:

```text
https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Emojis.spoon.zip
```

### `SpoonManager.from.remoteZip(url)`

Creates a builder from a remote ZIP URL.

Use this when you already know the exact ZIP URL. The ZIP may contain a `.spoon` folder, a single root folder with `init.lua`, or `init.lua` directly at the ZIP root.

In exported configs, this uses `source.type = "remoteZip"`.

The URL must point to a `.zip` file. Other archive formats are rejected.

The Spoon name is inferred from the ZIP URL. Use `.withName(name)` to override it.

Example:

```lua
spoon.SpoonManager.from.remoteZip("https://example.com/MySpoon.zip")
    .install()
```

Example, GitHub latest release asset as a plain ZIP URL:

```lua
spoon.SpoonManager.from.remoteZip(
    "https://github.com/muescha/MySpoon.spoon/releases/latest/download/MySpoon.zip"
)
    .install()
```

### `SpoonManager.from.localZip(path)`

Creates a builder from a local ZIP file.

`path` may use `~` when Hammerspoon can resolve it with `hs.fs.pathToAbsolute()`.

In exported configs, this uses `source.type = "localZip"`.

The path must point to a `.zip` file. Other archive formats are rejected.

The Spoon name is inferred from the ZIP filename. Use `.withName(name)` to override it.

Example:

```lua
spoon.SpoonManager.from.localZip("~/Downloads/MySpoon.zip")
    .install()
```

### `SpoonManager.from.localFolder(path)`

Creates a builder from a local folder.

The folder must contain an `init.lua` file. If the folder name ends in `.spoon`, the Spoon name is inferred automatically.

Example:

```lua
spoon.SpoonManager.from.localFolder("~/Projects/MySpoon.spoon")
    .install()
```

Example, override the installed Spoon name:

Without an explicit name, this installs as `experimental`:

```lua
spoon.SpoonManager.from.localFolder("~/Projects/experimental")
    .install()
```

With an explicit name, the same folder installs as `MySpoon`:

```lua
spoon.SpoonManager.from.localFolder("~/Projects/experimental")
    .withName("MySpoon")
    .install()
```

### `SpoonManager.from.default`

Built-in source alias for the official Hammerspoon/Spoons repository.

It is equivalent to:

```lua
spoon.SpoonManager.from.spoonRepoZip("Hammerspoon/Spoons", {
    defaultBranch = "master",
})
```

That means it points to:

```text
Hammerspoon/Spoons
```

and uses this ZIP convention:

```text
Spoons/{name}.spoon.zip
```

Example:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .install()
```

Example, override the default fallback branch:

```lua
spoon.SpoonManager.from.default
    .branch("main")
    .spoon("Emojis")
    .install()
```

### `builder.branch(name)`

Returns a new builder using the given branch name.

This is a readable shortcut for branch-based GitHub sources.

If no branch or ref is configured, GitHub sources use `main` while resolving URLs.

In exported configs, `branch(name)` uses `source.revision_branch = name`. `ref(name)` uses `source.revision_ref = name`.

`SpoonManager.from.default` has `defaultBranch = "master"` as a fallback for the official repository, but that fallback does not block `.branch(...)` or `.ref(...)`.

Example:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .branch("develop")
    .path("Source/MySpoon.spoon")
    .install()
```

### `builder.ref(name)`

Returns a new builder using a raw GitHub ref.

Use this when the source should point to something more general than a branch. GitHub archive and raw URLs accept branches, tags, and commit SHAs in the same ref position.

For branches, prefer `branch(name)` because it makes the intent clearer. Use `ref(name)` for tags, commits, or unusual refs.

Example, tag:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .ref("v1.2.3")
    .path("Source/MySpoon.spoon")
    .install()
```

Example, commit:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .ref("abc123def456")
    .path("Source/MySpoon.spoon")
    .install()
```

### `builder.spoonZipPattern(pattern)`

Returns a new builder that knows how to turn a Spoon name into a ZIP path.

The pattern may contain `{name}`.

In exported configs, this uses `source.pattern_spoonZipPattern = pattern`.

Example:

```lua
local repo =
    spoon.SpoonManager.from.github("muescha/SpoonRepo")
        .branch("main")
        .spoonZipPattern("dist/{name}.zip")

repo.spoon("MySpoon")
    .install()
```

This resolves to:

```text
https://github.com/muescha/SpoonRepo/raw/main/dist/MySpoon.zip
```

### `builder.spoonFolderPattern(pattern)`

Returns a new builder that knows how to turn a Spoon name into a folder path.

The pattern may contain `{name}`.

In exported configs, this uses `source.pattern_spoonFolderPattern = pattern`.

Example:

```lua
local repo =
    spoon.SpoonManager.from.github("muescha/SpoonRepo")
        .branch("main")
        .spoonFolderPattern("Source/{name}.spoon")

repo.spoon("MySpoon")
    .install()
```

### `builder.spoon(name)`

Creates a Spoon builder from a known Spoon name using a configured Spoon pattern.

In exported configs, this stores the selected Spoon in `target.selection_spoon`.

With `from.default`, this resolves directly to the official Spoon ZIP:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .install()
```

Resolved URL:

```text
https://github.com/Hammerspoon/Spoons/raw/master/Spoons/TimeMachineProgress.spoon.zip
```

With a custom ZIP pattern:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .spoonZipPattern("build/{name}.zip")
    .spoon("MySpoon")
    .install()
```

Without `spoonZipPattern(...)` or `spoonFolderPattern(...)`, `.spoon(name)` is rejected:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .spoon("MySpoon") -- error
```

Use `.path(...)` for an explicit repository folder, or call `.install()` directly
when the repository root itself is the Spoon:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .install()
```

### `builder.path(path)`

Creates a Spoon builder from a folder inside the repository or local folder.

In exported configs, this stores the selected source path in `source.path`.

For GitHub sources, SpoonManager downloads the generated repository archive and extracts only the selected folder.

Example:

```lua
spoon.SpoonManager.from.github("Hammerspoon/Spoons")
    .branch("master")
    .path("Source/TimeMachineProgress.spoon")
    .install()
```

If the folder does not end in `.spoon`, SpoonManager still infers the name from the last folder segment:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .path("Source/deepfolder")
    .install()
```

Inferred Spoon name:

```text
deepfolder
```

Use `withName()` only when the inferred name is not the name you want to install:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .path("Source/deepfolder")
    .withName("ManagedDeepFolder")
    .install()
```

### `builder.releaseLatest()`

Returns a new builder for the latest stable GitHub release.

This does not call the GitHub API. It uses GitHub's stable latest-release download path once `zipFile(name)` is selected.

Example:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .releaseLatest()
    .zipFile("MySpoon.zip")
    .install()
```

Resolved URL:

```text
https://github.com/muescha/MySpoon.spoon/releases/latest/download/MySpoon.zip
```

### `builder.release(name)`

Returns a new builder for a specific GitHub release tag.

Example:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .release("v1.2.0")
    .zipFile("MySpoon.zip")
    .install()
```

Resolved URL:

```text
https://github.com/muescha/MySpoon.spoon/releases/download/v1.2.0/MySpoon.zip
```

### `builder.zipFile(name)`

Selects a ZIP file and returns a Spoon builder.

Usually used after `releaseLatest()` or `release(name)`.

The ZIP file name must end in `.zip`. Other archive formats are rejected.

In exported configs, this stores the selected ZIP file in `source.zipFile`.

Example:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .releaseLatest()
    .zipFile("MySpoon.zip")
    .install()
```

### `builder.withName(name)`

Returns a new builder with a specific installed Spoon name.

This is useful when the inferred name is not the name you want. For example, a folder named `Source/deepfolder` is inferred as `deepfolder`; use `withName("ManagedDeepFolder")` if the installed Spoon should be named `ManagedDeepFolder`.

In exported configs, this uses `target.name_withName = name`.

Example:

```lua
spoon.SpoonManager.from.remoteZip("https://example.com/download.zip")
    .withName("ManagedDownload")
    .install()
```

Example, repository root with a different local name:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .withName("ManagedMySpoon")
    .install()
```

### `builder.use(options)`

Returns a new builder with options that are passed to `hs.spoons.use()` after install, update, or install-skip.

Accepted options are the same style as `hs.spoons.use()`:

```lua
{
    config = {},
    hotkeys = {},
    fn = function(loadedSpoon) end,
    loglevel = "debug",
    start = true,
}
```

Example:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .use({
        start = true,
    })
    .install()
```

Example with config and callback:

```lua
spoon.SpoonManager.from.default
    .spoon("SomeSpoon")
    .use({
        config = {
            enabled = true,
        },
        fn = function(loadedSpoon)
            print("Loaded " .. loadedSpoon.name)
        end,
    })
    .install()
```

### `SpoonManager.options.patterns`

Constants for built-in Spoon repository path conventions.

Using constants avoids duplicate hard-coded strings when you want to build the
same conventions manually.

Values:

```lua
spoon.SpoonManager.options.patterns.spoonRepo
spoon.SpoonManager.options.patterns.spoonRepoZip
```

Current values:

```lua
spoon.SpoonManager.options.patterns.spoonRepo
-- "Source/{name}.spoon"

spoon.SpoonManager.options.patterns.spoonRepoZip
-- "Spoons/{name}.spoon.zip"
```

`from.spoonRepo(...)` uses `options.patterns.spoonRepo`.
`from.spoonRepoZip(...)` and `from.default` use `options.patterns.spoonRepoZip`.

Example:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo", {
    branch = "main",
})
    .spoonFolderPattern(spoon.SpoonManager.options.patterns.spoonRepo)
    .spoon("MySpoon")
    .install()
```

### `SpoonManager.options.localChanges`

Constants for `builder.onLocalChanges(behavior)`.

Using constants avoids typo-prone strings and gives Lua language servers concrete fields to suggest.

Values:

```lua
spoon.SpoonManager.options.localChanges.abort
spoon.SpoonManager.options.localChanges.backup
spoon.SpoonManager.options.localChanges.overwrite
```

Example:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .onLocalChanges(spoon.SpoonManager.options.localChanges.backup)
    .update()
```

### `SpoonManager.onLocalChanges(behavior)`

Sets the default behavior for existing or locally changed Spoons.

This default is used by `install()` and `update()` unless a builder sets its own behavior with `builder.onLocalChanges(behavior)`.

Example, default to backup:

```lua
spoon.SpoonManager.onLocalChanges(
    spoon.SpoonManager.options.localChanges.backup
)

spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .update()
```

Example, builder overrides the manager default:

```lua
spoon.SpoonManager.onLocalChanges(
    spoon.SpoonManager.options.localChanges.backup
)

spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .onLocalChanges(spoon.SpoonManager.options.localChanges.abort)
    .update()
```

### `builder.onLocalChanges(behavior)`

Returns a new builder with explicit behavior for existing or locally changed Spoons.

Accepted values:

```lua
spoon.SpoonManager.options.localChanges.abort
spoon.SpoonManager.options.localChanges.backup
spoon.SpoonManager.options.localChanges.overwrite
```

`abort` is the default.

Example, backup before replacing:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .onLocalChanges(spoon.SpoonManager.options.localChanges.backup)
    .update()
```

Example, force overwrite:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .onLocalChanges(spoon.SpoonManager.options.localChanges.overwrite)
    .update()
```

### `builder.add()`

Adds this builder to SpoonManager's managed list and returns the same builder.

It does not install anything by itself.

Example:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .use({
        start = true,
    })
    .add()

spoon.SpoonManager.install()
```

### `builder.install()`

Installs this builder synchronously.

If the Spoon is already installed, `install()` skips the download and only applies `use()` options.

After a successful install, SpoonManager stores the builder config in its managed list.
That means a later `spoon.SpoonManager.update()` can update it without passing the builder again.

Example:

```lua
local result, err =
    spoon.SpoonManager.from.default
        .spoon("Emojis")
        .install()

if not result then
    print(err)
end

-- Later in the same Hammerspoon session:
spoon.SpoonManager.update()
```

Example with use options:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .use({
        start = true,
    })
    .install()
```

### `builder.update()`

Updates this builder synchronously.

Unlike `install()`, `update()` fetches the external source again. Before replacing an existing Spoon, it checks whether the local files still match the checksum stored from the last SpoonManager install or update.

After a successful update, SpoonManager stores the builder config as a managed builder config.

Example:

```lua
local result, err =
    spoon.SpoonManager.from.default
        .spoon("TimeMachineProgress")
        .update()

if not result then
    print(err)
end
```

Example with backup if local files are unmanaged or changed:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .onLocalChanges(spoon.SpoonManager.options.localChanges.backup)
    .update()
```

### `builder.toConfig()`

Returns the plain config table behind a builder.

This is useful for debugging, storing configs, or generating a future `spoonify.json`.

The returned config contains only values the user declared through the builder:

```text
config.source  = where the Spoon comes from
config.target  = which Spoon is selected and what local name it should have
config.use     = optional post-install hs.spoons.use options
config.options = optional install/update behavior
```

It does not include derived runtime values such as inferred names, download URLs, install paths, or commands. Those are added only when `resolve()`, `command(...)`, `install()`, or `update()` runs.

SpoonManager validates conflicts from the real config fields, for example `source.revision_branch`, `source.revision_ref`, and `source.path`.

Example:

```lua
local builder =
    spoon.SpoonManager.from.default
        .spoon("Emojis")
        .use({
            start = true,
        })

print(hs.inspect(builder.toConfig()))
```

Example output:

```lua
{
    source = {
        type = "github",
        provider = "github",
        repository = "Hammerspoon/Spoons",
        baseUrl = "https://github.com",
        defaultBranch = "master",
        pattern_spoonZipPattern = "Spoons/{name}.spoon.zip",
    },
    target = {
        selection_spoon = "Emojis",
    },
    use = {
        start = true,
    },
}
```

### `builder.resolve()`

Returns a new builder with the `resolved` stage calculated.

You usually do not need this for normal installs. `install()` and `update()` resolve automatically. Use `resolve()` when you want to preview or debug what SpoonManager inferred before it builds an executable command.

The resolved stage contains derived values such as:

```text
resolved.installName    = final Spoon name after inference or withName(...)
resolved.sourceType     = executable source kind, either zip or folder
resolved.url            = direct ZIP URL, when the source resolves to a ZIP
resolved.extractFolder  = folder to extract from an archive
```

Example:

```lua
local resolved =
    spoon.SpoonManager.from.default
        .spoon("Emojis")
        .resolve()
        .explain()

print(hs.inspect(resolved.resolved))
```

Example output:

```lua
{
    installName = "Emojis",
    sourceType = "zip",
    url = "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Emojis.spoon.zip",
}
```

After `resolve()`, the builder is frozen for further builder changes. Start from the base builder when you want another variation:

```lua
local base = spoon.SpoonManager.from.default

local emojis =
    base.spoon("Emojis").resolve()

local windowSigils =
    base.spoon("WindowSigils")
```

### `builder.explain()`

Returns the current builder state without calculating new values.

Use this when you want to inspect what is already stored on a builder:

```lua
local current =
    spoon.SpoonManager.from.default
        .spoon("Emojis")
        .explain()

print(hs.inspect(current))
```

`explain()` is intentionally passive. It does not infer names, build URLs, or create commands.

Before resolving, the output contains only `config`:

```lua
{
    config = {
        source = {
            type = "github",
            repository = "Hammerspoon/Spoons",
            pattern_spoonZipPattern = "Spoons/{name}.spoon.zip",
        },
        target = {
            selection_spoon = "Emojis",
        },
    },
}
```

To inspect later stages, request them explicitly first:

```lua
local resolved =
    spoon.SpoonManager.from.default
        .spoon("Emojis")
        .resolve()
        .explain()

local command =
    spoon.SpoonManager.from.default
        .spoon("Emojis")
        .command("install")
        .explain()
```

After one of these stages has been calculated, the builder is frozen for further builder changes. Start from the base builder when you want a variation:

```lua
local base = spoon.SpoonManager.from.default

local emojis =
    base.spoon("Emojis")

local windowSigils =
    base.spoon("WindowSigils")
```

The stages are only calculated once and then reused:

```text
config
  -> resolved
  -> command
  -> install/update
```

### `SpoonManager.add(builder[, ...])`

Adds one or more builders to SpoonManager's managed list.

It does not install anything by itself.

Example:

```lua
local emojis =
    spoon.SpoonManager.from.default
        .spoon("Emojis")

local timeMachine =
    spoon.SpoonManager.from.default
        .spoon("TimeMachineProgress")
        .use({
            start = true,
        })

spoon.SpoonManager.add(emojis, timeMachine)
spoon.SpoonManager.install()
```

### `SpoonManager.clear()`

`clear()` removes all builders currently stored in SpoonManager's managed list.
It only clears the in-memory list. It does not remove installed
Spoons and it does not delete install metadata from `installed.json`.

Example:

```lua
spoon.SpoonManager.add(
    spoon.SpoonManager.from.default.spoon("Emojis")
)

spoon.SpoonManager.clear()
spoon.SpoonManager.install()
```

In this example, `install()` has nothing to do after `clear()`.

### `SpoonManager.install([builder[, ...]])`

Installs builders synchronously.

With arguments, it installs the passed builders and stores successful builder configs in SpoonManager's managed list.

Without arguments, it installs builders currently stored in SpoonManager's managed list.

Builders are stored by inferred Spoon name. Installing another builder for the same Spoon name replaces the old managed builder config instead of adding a duplicate.

Example with arguments:

```lua
local emojis =
    spoon.SpoonManager.from.default
        .spoon("Emojis")

spoon.SpoonManager.install(emojis)

-- The explicit install above also makes Emojis managed:
spoon.SpoonManager.update()
```

Example with added builders:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .add()

spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .add()

spoon.SpoonManager.install()
```

### `SpoonManager.update([builder[, ...]])`

Updates builders synchronously.

With arguments, it updates the passed builders and stores successful builder configs in SpoonManager's managed list.

Without arguments, it updates builders currently stored in SpoonManager's managed list.

Example:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .add()

spoon.SpoonManager.update()
```

Example with explicit builder:

```lua
local timeMachine =
    spoon.SpoonManager.from.default
        .spoon("TimeMachineProgress")

spoon.SpoonManager.update(timeMachine)
```

### Results

Single builder actions return:

```lua
result, err = builder.install()
result, err = builder.update()
```

On success:

```lua
{
    success = true,
    action = "install",
    skipped = true,
    reason = "already-installed",
    name = "Emojis",
    path = "~/.hammerspoon/Spoons/Emojis.spoon",
    config = {},
    resolved = {},
    command = {},
    use = {},
}
```

Batch actions return:

```lua
{
    success = true,
    action = "install",
    installed = {},
    skipped = {},
    errors = {},
}
```

### Install metadata

After a successful install or update, SpoonManager stores install metadata here:

```text
~/.hammerspoon/.config/SpoonManager/installed.json
```

It contains the original config, the resolved install data, the effective command, and a checksum of the installed Spoon folder. That checksum is used to detect local changes before `update()`.

Shape:

```lua
{
    Emojis = {
        name = "Emojis",
        installedAt = "2026-08-05T03:12:00Z",
        updatedAt = "2026-08-05T03:12:00Z",
        path = "~/.hammerspoon/Spoons/Emojis.spoon",
        config = {},
        resolved = {},
        command = {},
        use = {},
        fingerprints = {
            localHash = "sha256:...",
        },
    },
}
```

The directory can be overridden:

```lua
spoon.SpoonManager.configDir =
    hs.configdir .. "/.config/SpoonManager"
```

## Technical Details

Most users only need the builders above. The internal stages are useful when you
debug SpoonManager itself, inspect generated JSON, or build future manifest
support.

The terms used in debug output and stored metadata are:

```text
config   = the user-provided source, target, use, and options values
resolved = inferred install name, source type, URLs, and archive selection
command  = final executable install/update task
```

SpoonManager calculates each stage once and then reuses it:

```text
config -> resolved -> command -> installed record
```

`builder.toConfig()` returns only the declarative config. Install results and
`installed.json` additionally include `resolved` and `command` data for debugging
and update checks.

### Logger

SpoonManager uses a regular Hammerspoon logger:

```lua
spoon.SpoonManager.logger
```

Enable debug logging after loading the Spoon:

```lua
hs.loadSpoon("SpoonManager")

spoon.SpoonManager.logger.setLogLevel("debug")
```

Debug logging is useful while developing or when checking how SpoonManager
resolved a source. For example, name inference and explicit name overrides are
logged at debug level:

```text
Inferred Spoon name 'TimeMachineProgress' from folder path 'Source/TimeMachineProgress.spoon'
Using explicit Spoon name 'BetterName' from 'BetterName'
```

For quieter output, use:

```lua
spoon.SpoonManager.logger.setLogLevel("info")
```

### Project Structure

`init.lua` is intentionally small. It defines the public Spoon object and wires
the modules in `lib/` together.

```text
SpoonManager.spoon/
├── init.lua
└── lib/
    ├── Archive.lua
    ├── Definition.lua
    ├── GitHub.lua
    ├── Installer.lua
    ├── NameResolver.lua
    ├── Paths.lua
    ├── Registry.lua
    └── Util.lua
```

The modules have narrow responsibilities:

- `Archive.lua`: download and extract ZIP files
- `Definition.lua`: builder methods for one installable Spoon
- `GitHub.lua`: GitHub URL construction
- `Installer.lua`: install, update, local-change checks, and `hs.spoons.use()`
- `NameResolver.lua`: Spoon name inference and name logging
- `Paths.lua`: install and metadata paths
- `Registry.lua`: `installed.json` read/write
- `Util.lua`: small shared helpers

### Tests

Run the plain Lua test runner from the repository root:

```sh
lua tests/run.lua
```

The tests include executable examples for the builder API and golden JSON
snapshots for complete configs and commands.

Update snapshots explicitly when an output change is intentional:

```sh
SPOONMANAGER_UPDATE_SNAPSHOTS=1 lua tests/run.lua
```

After updating snapshots, review the Git diff before committing.

## Notes

`catalog.json` and `spoonify.json` are intentionally not part of the install path yet. They can come later for browsing, generated source configs, and SpoonHub-style discovery.

# SpoonManager.spoon

SpoonManager is an experimental Hammerspoon Spoon installer with explicit source definitions and a small builder API.

## Goals

- Install known Spoons without loading a catalog first.
- Support classic Spoon ZIPs, flat ZIPs, local folders, GitHub repository roots, GitHub folders, and GitHub release assets.
- Keep `install()` synchronous so a Hammerspoon `init.lua` can use the Spoon immediately after installation.
- Keep `install()` idempotent: if the Spoon already exists, skip the download and only apply `.use(...)` options.
- Use `update()` when the external source should be fetched again.
- Protect existing local changes by default.
- Keep catalogs optional for later search, GUI, or SpoonHub-style workflows.

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

## Logger

SpoonManager uses a regular Hammerspoon logger:

```lua
spoon.SpoonManager.logger
```

Enable debug logging after loading the Spoon:

```lua
hs.loadSpoon("SpoonManager")

spoon.SpoonManager.logger.setLogLevel("debug")
```

Debug logging is useful while developing or when checking how SpoonManager resolved a source.
For example, name inference and explicit name overrides are logged at debug level:

```text
Inferred Spoon name 'TimeMachineProgress' from folder path 'Source/TimeMachineProgress.spoon'
Using explicit Spoon name 'BetterName' from 'BetterName'
```

For quieter output, use:

```lua
spoon.SpoonManager.logger.setLogLevel("info")
```

## Project Structure

`init.lua` is intentionally small. It defines the public Spoon object and wires the modules in `lib/` together.

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

## Tests

Run the plain Lua test runner from the repository root:

```sh
lua tests/run.lua
```

The tests include executable examples for the builder API and golden JSON snapshots for complete configs and commands.

Update snapshots explicitly when an output change is intentional:

```sh
SPOONMANAGER_UPDATE_SNAPSHOTS=1 lua tests/run.lua
```

After updating snapshots, review the Git diff before committing.

## Examples

Install from the default Hammerspoon Spoons repository using the classic ZIP convention:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .install()
```

Install a Spoon from a folder inside a GitHub repository:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .branch("main")
    .folder("Source/DeepFolder.spoon")
    .install()
```

Install from the latest GitHub release asset:

```lua
spoon.SpoonManager.from.github("muescha/DeepFolder.spoon")
    .releaseLatest()
    .asset("DeepFolder.zip")
    .install()
```

Install from a local folder:

```lua
spoon.SpoonManager.from.localFolder("~/Projects/DeepFolder.spoon")
    .install()
```

Add definitions and install them together:

```lua
local emojis =
    spoon.SpoonManager.from.default
        .spoon("Emojis")
        .use({
            start = true,
        })

local deepFolder =
    spoon.SpoonManager.from.github("muescha/SpoonRepo")
        .folder("Source/DeepFolder.spoon")

spoon.SpoonManager.add(emojis, deepFolder)
spoon.SpoonManager.install()
```

Update explicitly:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .update()
```

## Local Changes

`install()` skips already installed Spoons.

`update()` fetches the source again. If the target Spoon exists and SpoonManager cannot prove that it is unchanged, update aborts by default.

Override per definition:

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

Suffixes are removed in order, so `name.spoon.zip` becomes `name.spoon` and then `name`.

Examples:

| Input | Inferred Spoon name |
|---|---|
| `name.zip` | `name` |
| `name.spoon.zip` | `name` |
| `name.spoon` | `name` |
| `folder/lastfoldername` | `lastfoldername` |
| `folder/lastfoldername.spoon` | `lastfoldername` |
| `user/reponame` | `reponame` |
| `user/reponame.spoon` | `reponame` |
| `asset("name.zip")` | `name` |
| `asset("name.spoon.zip")` | `name` |

Remote ZIP URL:

```lua
spoon.SpoonManager.from.remoteZip("https://example.com/name.spoon.zip")
    .install()
```

Installs as:

```text
name
```

Local ZIP:

```lua
spoon.SpoonManager.from.localZip("~/Downloads/name.zip")
    .install()
```

Installs as:

```text
name
```

Local folder:

```lua
spoon.SpoonManager.from.localFolder("~/Projects/name.spoon")
    .install()
```

Installs as:

```text
name
```

GitHub repository root:

```lua
spoon.SpoonManager.from.github("user/reponame.spoon")
    .install()
```

Installs as:

```text
reponame
```

GitHub folder:

```lua
spoon.SpoonManager.from.github("user/repo")
    .folder("Source/deepfolder.spoon")
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
    .asset("name.spoon.zip")
    .install()
```

Installs as:

```text
name
```

Use `.withName(name)` to override the inferred name:

```lua
spoon.SpoonManager.from.github("user/repo")
    .folder("Source/deepfolder")
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

- `SpoonManager.from.*` factories create definition builders
- definition and manager actions install or update Spoons

All builder calls use dot notation and do not install anything until `install()` or `update()` is called.

A definition contains the source information, target selection, use options, and install options. It can start broad, such as a GitHub repository, and become more specific with calls like `folder(...)`, `asset(...)`, or `withName(...)`.

The public definition table keeps user-provided values close to the builder calls:

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

Builder methods do not silently overwrite each other. Each group can be set once per definition: revision (`branch`/`ref`), Spoon pattern, selection (`spoon`/`folder`/`asset`), release, target name (`withName`), and local-change behavior.

If you need another Spoon from the same repository, keep the broad base definition and create each selected Spoon from that base:

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

Do not try to change the selected Spoon on an already selected definition:

```lua
local emojis =
    official
        .spoon("Emojis")

-- Error: selection_spoon('Emojis') already selected.
local windowSigils =
    emojis
        .spoon("WindowSigils")
```

Internally, SpoonManager resolves a definition into an executable command at the last moment:

```text
definition -> resolved -> command -> installed record
```

`definition.toConfig()` returns only the declarative definition. Install results and `installed.json` additionally include `resolved` and `command` data for debugging and update checks.

### `SpoonManager.from.config(config)`

Creates a definition builder from a plain Lua table.

Use this when a definition was previously exported with `definition.toConfig()` or loaded from a future manifest file.

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

Creates a GitHub repository definition.

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
    .folder("Source/MySpoon.spoon")
    .install()
```

### `SpoonManager.from.spoonRepo(repository[, options])`

Creates a GitHub repository definition for the preferred Spoon source layout:

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

Creates a GitHub repository definition for the legacy Spoon ZIP layout:

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

Creates a definition builder from a remote ZIP URL.

Use this when you already know the exact ZIP URL. The ZIP may contain a `.spoon` folder, a single root folder with `init.lua`, or `init.lua` directly at the ZIP root.

In exported configs, this uses `source.type = "remote-zip"`.

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

Creates a definition builder from a local ZIP file.

`path` may use `~` when Hammerspoon can resolve it with `hs.fs.pathToAbsolute()`.

In exported configs, this uses `source.type = "local-zip"`.

The path must point to a `.zip` file. Other archive formats are rejected.

The Spoon name is inferred from the ZIP filename. Use `.withName(name)` to override it.

Example:

```lua
spoon.SpoonManager.from.localZip("~/Downloads/MySpoon.zip")
    .install()
```

### `SpoonManager.from.localFolder(path)`

Creates a definition builder from a local folder.

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

### `definition.branch(name)`

Returns a new definition using the given branch name.

This is a readable shortcut for branch-based GitHub sources.

If no branch or ref is configured, GitHub sources use `main` while resolving URLs.

In exported configs, `branch(name)` uses `source.revision_branch = name`. `ref(name)` uses `source.revision_ref = name`.

`SpoonManager.from.default` has `defaultBranch = "master"` as a fallback for the official repository, but that fallback does not block `.branch(...)` or `.ref(...)`.

Example:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .branch("develop")
    .folder("Source/MySpoon.spoon")
    .install()
```

### `definition.ref(name)`

Returns a new definition using a raw GitHub ref.

Use this when the source should point to something more general than a branch. GitHub archive and raw URLs accept branches, tags, and commit SHAs in the same ref position.

For branches, prefer `branch(name)` because it makes the intent clearer. Use `ref(name)` for tags, commits, or unusual refs.

Example, tag:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .ref("v1.2.3")
    .folder("Source/MySpoon.spoon")
    .install()
```

Example, commit:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .ref("abc123def456")
    .folder("Source/MySpoon.spoon")
    .install()
```

### `definition.spoonZipPattern(pattern)`

Returns a new definition that knows how to turn a Spoon name into a ZIP path.

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

### `definition.spoonFolderPattern(pattern)`

Returns a new definition that knows how to turn a Spoon name into a folder path.

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

### `definition.spoon(name)`

Creates a Spoon definition from a known Spoon name using a configured Spoon pattern.

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

Use `.folder(...)` for an explicit repository folder, or call `.install()` directly
when the repository root itself is the Spoon:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .install()
```

### `definition.folder(path)`

Creates a Spoon definition from a folder inside the repository or local folder.

In exported configs, this stores the selected folder in `target.selection_folder`.

For GitHub sources, SpoonManager downloads the generated repository archive and extracts only the selected folder.

Example:

```lua
spoon.SpoonManager.from.github("Hammerspoon/Spoons")
    .branch("master")
    .folder("Source/TimeMachineProgress.spoon")
    .install()
```

If the folder does not end in `.spoon`, SpoonManager still infers the name from the last folder segment:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .folder("Source/deepfolder")
    .install()
```

Inferred Spoon name:

```text
deepfolder
```

Use `withName()` only when the inferred name is not the name you want to install:

```lua
spoon.SpoonManager.from.github("muescha/SpoonRepo")
    .folder("Source/deepfolder")
    .withName("ManagedDeepFolder")
    .install()
```

### `definition.releaseLatest()`

Returns a new GitHub release definition for the latest stable release.

This does not call the GitHub API. It uses GitHub's stable latest-release download path once `asset(name)` is selected.

Example:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .releaseLatest()
    .asset("MySpoon.zip")
    .install()
```

Resolved URL:

```text
https://github.com/muescha/MySpoon.spoon/releases/latest/download/MySpoon.zip
```

### `definition.release(name)`

Returns a new GitHub release definition for a specific release tag.

Example:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .release("v1.2.0")
    .asset("MySpoon.zip")
    .install()
```

Resolved URL:

```text
https://github.com/muescha/MySpoon.spoon/releases/download/v1.2.0/MySpoon.zip
```

### `definition.asset(name)`

Selects a release asset and returns a Spoon definition.

Usually used after `releaseLatest()` or `release(name)`.

The asset name must end in `.zip`. Other archive formats are rejected.

In exported configs, this stores the selected asset in `target.selection_asset`.

Example:

```lua
spoon.SpoonManager.from.github("muescha/MySpoon.spoon")
    .releaseLatest()
    .asset("MySpoon.zip")
    .install()
```

### `definition.withName(name)`

Returns a new definition with a specific installed Spoon name.

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

### `definition.use(options)`

Returns a new definition with options that are passed to `hs.spoons.use()` after install, update, or install-skip.

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

Constants for `definition.onLocalChanges(behavior)`.

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

This default is used by `install()` and `update()` unless a definition sets its own behavior with `definition.onLocalChanges(behavior)`.

Example, default to backup:

```lua
spoon.SpoonManager.onLocalChanges(
    spoon.SpoonManager.options.localChanges.backup
)

spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .update()
```

Example, definition overrides the manager default:

```lua
spoon.SpoonManager.onLocalChanges(
    spoon.SpoonManager.options.localChanges.backup
)

spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .onLocalChanges(spoon.SpoonManager.options.localChanges.abort)
    .update()
```

### `definition.onLocalChanges(behavior)`

Returns a new definition with explicit behavior for existing or locally changed Spoons.

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

### `definition.add()`

Adds this definition to `SpoonManager.definitions` and returns the same definition.

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

### `definition.install()`

Installs this definition synchronously.

If the Spoon is already installed, `install()` skips the download and only applies `use()` options.

After a successful install, SpoonManager stores the definition in `SpoonManager.definitions`.
That means a later `spoon.SpoonManager.update()` can update it without passing the definition again.

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

### `definition.update()`

Updates this definition synchronously.

Unlike `install()`, `update()` fetches the external source again. Before replacing an existing Spoon, it checks whether the local files still match the checksum stored from the last SpoonManager install or update.

After a successful update, SpoonManager stores the definition as a managed definition.

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

### `definition.toConfig()`

Returns the plain config table behind a definition builder.

This is useful for debugging, storing definitions, or generating a future `spoonify.json`.

The returned config contains only values the user declared through the builder:

```text
config.source  = where the Spoon comes from
config.target  = which Spoon is selected and what local name it should have
config.use     = optional post-install hs.spoons.use options
config.options = optional install/update behavior
```

It does not include derived runtime values such as inferred names, download URLs, install paths, or commands. Those are added only when `resolve()`, `command(...)`, `install()`, or `update()` runs.

SpoonManager validates conflicts from the real config fields, for example `source.revision_branch`, `source.revision_ref`, and `target.selection_folder`.

Example:

```lua
local definition =
    spoon.SpoonManager.from.default
        .spoon("Emojis")
        .use({
            start = true,
        })

print(hs.inspect(definition.toConfig()))
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

### `definition.resolve()`

Returns a new definition with the `resolved` stage calculated.

You usually do not need this for normal installs. `install()` and `update()` resolve automatically. Use `resolve()` when you want to preview or debug what SpoonManager inferred before it builds an executable command.

The resolved stage contains derived values such as:

```text
resolved.installName    = final Spoon name after inference or withName(...)
resolved.sourceType     = executable source kind, for example remote-zip or github-folder
resolved.url            = direct ZIP URL, when the source resolves to a ZIP
resolved.archiveUrl     = repository archive URL, when a folder/repository is installed
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
    sourceType = "remote-zip",
    url = "https://github.com/Hammerspoon/Spoons/raw/master/Spoons/Emojis.spoon.zip",
}
```

After `resolve()`, the definition is frozen for further builder changes. Start from the base definition when you want another variation:

```lua
local base = spoon.SpoonManager.from.default

local emojis =
    base.spoon("Emojis").resolve()

local windowSigils =
    base.spoon("WindowSigils")
```

### `definition.explain()`

Returns the current definition state without calculating new values.

Use this when you want to inspect what is already stored on a definition:

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

After one of these stages has been calculated, the definition is frozen for further builder changes. Start from the base definition when you want a variation:

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

### `SpoonManager.add(definition[, ...])`

Adds one or more definitions to `SpoonManager.definitions`.

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

`clear()` removes all definitions currently stored in `SpoonManager.definitions`.
It only clears the in-memory definition list. It does not remove installed
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

### `SpoonManager.install([definition[, ...]])`

Installs definitions synchronously.

With arguments, it installs the passed definitions and stores successful definitions in `SpoonManager.definitions`.

Without arguments, it installs definitions currently stored in `SpoonManager.definitions`.

Definitions are stored by inferred Spoon name. Installing another definition for the same Spoon name replaces the old managed definition instead of adding a duplicate.

Example with arguments:

```lua
local emojis =
    spoon.SpoonManager.from.default
        .spoon("Emojis")

spoon.SpoonManager.install(emojis)

-- The explicit install above also makes Emojis managed:
spoon.SpoonManager.update()
```

Example with added definitions:

```lua
spoon.SpoonManager.from.default
    .spoon("Emojis")
    .add()

spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .add()

spoon.SpoonManager.install()
```

### `SpoonManager.update([definition[, ...]])`

Updates definitions synchronously.

With arguments, it updates the passed definitions and stores successful definitions in `SpoonManager.definitions`.

Without arguments, it updates definitions currently stored in `SpoonManager.definitions`.

Example:

```lua
spoon.SpoonManager.from.default
    .spoon("TimeMachineProgress")
    .add()

spoon.SpoonManager.update()
```

Example with explicit definition:

```lua
local timeMachine =
    spoon.SpoonManager.from.default
        .spoon("TimeMachineProgress")

spoon.SpoonManager.update(timeMachine)
```

### Results

Single definition actions return:

```lua
result, err = definition.install()
result, err = definition.update()
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

## Notes

`catalog.json` and `spoonify.json` are intentionally not part of the install path yet. They can come later for browsing, generated source definitions, and SpoonHub-style discovery.

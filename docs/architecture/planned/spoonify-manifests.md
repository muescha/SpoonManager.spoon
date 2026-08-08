# Spoonify Manifests

This note describes the idea of `spoonify.json` as a declarative manifest format for SpoonManager.

`spoonify.json` should not be a resolved install command. It should describe available Spoons and their source rules. SpoonManager can then resolve the selected entries into install or update commands locally.

Manifest loading should produce the same config shape as the builder. Source
rules use provider `source.type` values such as `github`, `remoteZip`,
`localZip`, or `localFolder`. Manifests should not contain resolved fields such
as `sourceKind`, or executable command fields such as `command.source.kind`.

## Why a Manifest?

A manifest is useful when a repository contains multiple Spoons or when an external index wants to describe Spoons from repositories that do not maintain their own metadata.

Use cases:

- A Spoon repository publishes its own `spoonify.json`.
- A third-party index maintains a manifest for an inactive repository.
- A website such as `example.com` exposes searchable Spoon metadata.
- A GUI reads manifests and lets users select Spoons to install.
- A user copies a generated SpoonManager definition into `init.lua`.

Direct installation should not require a manifest. If a user already knows the exact source, this should work without extra discovery calls:

```lua
SpoonManager.from.github("owner/repo")
    .path("Source/A.spoon")
    .install()
```

## Repository-Level Source Rules

A compact manifest can define source rules once and then list Spoons by name.

Example, ZIP pattern:

```json
{
  "version": 1,
  "source": {
    "type": "github",
    "repository": "Hammerspoon/Spoons",
    "revision_branch": "master",
    "pattern_spoonZipPattern": "Spoons/{name}.spoon.zip"
  },
  "spoons": [
    {
      "name": "Emojis",
      "description": "Emoji chooser"
    },
    {
      "name": "WindowSigils",
      "description": "Window switcher"
    }
  ]
}
```

The `Emojis` entry is equivalent to:

```lua
SpoonManager.from.github("Hammerspoon/Spoons")
    .branch("master")
    .spoonZipPattern("Spoons/{name}.spoon.zip")
    .spoon("Emojis")
```

Example, folder pattern:

```json
{
  "version": 1,
  "source": {
    "type": "github",
    "repository": "muescha/SpoonRepo",
    "revision_branch": "main",
    "pattern_spoonFolderPattern": "Source/{name}.spoon"
  },
  "spoons": [
    {
      "name": "Alpha",
      "description": "First Spoon"
    },
    {
      "name": "Beta",
      "description": "Second Spoon"
    }
  ]
}
```

The `Alpha` entry is equivalent to:

```lua
SpoonManager.from.github("muescha/SpoonRepo")
    .branch("main")
    .spoonFolderPattern("Source/{name}.spoon")
    .spoon("Alpha")
```

## Per-Spoon Overrides

Each manifest entry may override or extend the repository-level source.

Merge rule:

```text
final source = manifest.source + entry.source
```

The `name` field in a manifest entry is a human-friendly shorthand for the default Spoon selection. When the manifest is converted into a definition, it maps to `source.selection_spoon` unless the entry provides a more specific `source.selection_path`, `source.zipFile`, or `extract.useFolder` value. It should not become a separate top-level `definition.name`.

Example:

```json
{
  "version": 1,
  "source": {
    "type": "github",
    "repository": "muescha/SpoonRepo",
    "revision_branch": "main",
    "pattern_spoonFolderPattern": "Source/{name}.spoon"
  },
  "spoons": [
    {
      "name": "Alpha",
      "description": "Uses the default folder pattern"
    },
    {
      "name": "DeepFolder",
      "description": "Uses a custom folder",
      "source": {
        "selection_path": "experimental/deepfolder"
      }
    },
    {
      "name": "ReleaseOnly",
      "description": "Uses a latest release ZIP",
      "source": {
        "selection_releaseLatest": true,
        "zipFile": "ReleaseOnly.zip"
      }
    }
  ]
}
```

## Source Safety

Manifests should avoid direct local filesystem paths. A public or remote `spoonify.json` must not require values such as:

```json
{
  "source": {
    "type": "localFolder",
    "root": "/Users/alice/Projects/Foo.spoon"
  }
}
```

Local paths are machine-specific and should be configured by the user, not by a remote manifest.

Provider-based sources are preferred:

```json
{
  "source": {
    "type": "github",
    "repository": "owner/repo",
    "revision_branch": "main",
    "selection_path": "Source/Foo.spoon"
  }
}
```

For self-hosted providers, use `baseUrl`. This name is preferred over `host` because it includes the scheme.

GitHub Enterprise example:

```json
{
  "source": {
    "type": "github",
    "baseUrl": "https://github.company.com",
    "repository": "team/spoons",
    "revision_branch": "main",
    "pattern_spoonFolderPattern": "Source/{name}.spoon"
  }
}
```

GitLab example:

```json
{
  "source": {
    "type": "gitlab",
    "baseUrl": "https://gitlab.company.com",
    "repository": "team/spoons",
    "revision_branch": "main",
    "pattern_spoonFolderPattern": "Source/{name}.spoon"
  }
}
```

Forgejo or Codeberg example:

```json
{
  "source": {
    "type": "forgejo",
    "baseUrl": "https://codeberg.org",
    "repository": "user/spoons",
    "revision_branch": "main",
    "pattern_spoonFolderPattern": "Source/{name}.spoon"
  }
}
```

Direct remote ZIP URLs inside manifests should be denied by default. They can point to arbitrary hosts, so they should require explicit trust from the user.

Possible API:

```lua
SpoonManager.trustManifestRemoteUrls(
    "https://github.com",
    "https://raw.githubusercontent.com",
    "https://example.com"
)
```

The API accepts URL-like strings but should internally trust only their origins.

```text
https://example.com/releases/Foo.zip -> https://example.com
```

Then this manifest source is allowed:

```json
{
  "source": {
    "type": "remoteZip",
    "url": "https://example.com/downloads/Foo.zip"
  }
}
```

only if the user has trusted:

```lua
SpoonManager.trustManifestRemoteUrls("https://example.com")
```

Provider-based sources such as `github`, `gitlab`, and `forgejo` do not need the remote ZIP allowlist. They are resolved by provider-specific resolver logic.

## External Manifests

`spoonify.json` should be a format, not only a file inside the source repository.

An external manifest can describe a repository that does not provide one itself:

```json
{
  "version": 1,
  "source": {
    "type": "github",
    "repository": "legacy/UsefulSpoon.spoon",
    "revision_branch": "main"
  },
  "spoons": [
    {
      "name": "UsefulSpoon",
      "description": "Maintained externally because the upstream repository has no manifest"
    }
  ]
}
```

Possible API:

```lua
SpoonManager.from.spoonify("https://example.com/manifests/useful-spoon.json")
    .spoon("UsefulSpoon")
    .install()
```

With a local rename:

```lua
SpoonManager.from.spoonify("https://example.com/manifests/useful-spoon.json")
    .spoon("UsefulSpoon")
    .withName("MyUsefulSpoon")
    .install()
```

Installing all entries:

```lua
SpoonManager.from.spoonify("https://example.com/manifests/useful-spoon.json")
    .install()
```

## Index Manifests

A larger index can point to many `spoonify.json` files.

Example:

```json
{
  "version": 1,
  "manifests": [
    {
      "name": "official",
      "url": "https://raw.githubusercontent.com/Hammerspoon/Spoons/master/spoonify.json"
    },
    {
      "name": "muescha",
      "url": "https://raw.githubusercontent.com/muescha/SpoonRepo/main/spoonify.json"
    },
    {
      "name": "legacy-time-machine",
      "url": "https://example.com/manifests/time-machine-progress.json"
    }
  ]
}
```

Possible API:

```lua
SpoonManager.from.spoonifyIndex("https://example.com/index.json")
    .search("TimeMachine")
```

```lua
SpoonManager.from.spoonifyIndex("https://example.com/index.json")
    .spoon("TimeMachineProgress")
    .install()
```

## Manifest Versus Command

The manifest is declarative:

```text
spoonify.json -> definition
```

The manager resolves definitions locally:

```text
definition -> resolved definition -> command -> execute
```

This keeps manifests small and portable. Local values such as the final install path, `hs.configdir`, user-level `withName(...)`, and local-change behavior should be resolved by SpoonManager, not hard-coded into the manifest.

## Future Implementation Scope

Manifest loading is future implementation work, not part of the completed source
provider pipeline migration. When implemented, APIs such as `from.spoonify(...)`
or `from.spoonifyIndex(...)` should parse, validate, and map manifests into the
same normal config shape described above. They should then hand that config to
the existing config -> resolved -> command -> execute pipeline instead of adding
a second execution path.

# Repeated Name Inference During Install

## Observation

The network integration log can show the same inferred Spoon name multiple
times for one test run. For example, `github-folder` currently infers
`WindowSigils` four times.

This is visible in `log.json` because name inference debug messages include a
structured stacktrace.

## Why It Happens

The four calls come from distinct paths:

1. `definition.command("install")`

   The network runner builds an explain artifact before installing. Calling
   `.command("install")` resolves the definition and infers the install name.

2. First `definition.install()`

   The actual install prepares its own definition command. Even if `.command()`
   was called before, the install path currently starts again from config and
   resolves the name again.

3. Second `definition.install()`

   The network runner installs the same definition a second time to verify the
   already-installed skip behavior. This prepares the command again and infers
   the name again.

4. `_rememberDefinition()`

   After install, SpoonManager remembers the managed definition. When replacing
   an existing remembered definition, it calls `definitionInstallName(existing)`
   for comparison, which can resolve an existing stored config again.

## Current Stack Shapes

Typical stacktrace sources:

```text
definition.command("install")
  DefinitionResolver.resolveFromDefinition
  DefinitionResolver.withResolved
  DefinitionResolver.withCommand
  DefinitionBuilder.command

definition.install()
  DefinitionResolver.resolveFromDefinition
  DefinitionResolver.withResolved
  DefinitionResolver.withCommand
  Installer.prepareDefinition
  DefinitionBuilder.install

_rememberDefinition()
  DefinitionResolver.resolveFromDefinition
  definitionInstallName
  _rememberDefinition
  DefinitionBuilder.install
```

## Suspected Design Issue

`definitionConfig(definition)` returns only the declarative config for builder
objects. That keeps persisted definitions clean, but it also means that a
builder that already reached `.command("install")` does not pass its prepared
`resolved` / `command` state into `.install()`.

`_rememberDefinition()` also compares remembered definitions by resolving their
install names again instead of using a stored index or already-known install
name.

## Possible Follow-Up

- Preserve prepared builder state for immediate action calls when the action
  matches, while still persisting only config.
- Pass the known install name through `_rememberDefinition()` more consistently.
- Keep a small internal map from install name to remembered definition index so
  `_rememberDefinition()` does not resolve existing definitions repeatedly.
- Add a focused test that calls `.command("install").install()` and asserts name
  inference is not repeated unnecessarily.

## Non-Goal

Do not remove name inference itself. The goal is to avoid repeated resolution
when the answer is already available in the current flow.

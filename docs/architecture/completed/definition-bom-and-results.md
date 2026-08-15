# Definition BOM and Result Artifacts

**Status: Completed.**

This note records the desired shape for runtime definitions, public results, and
network test artifacts.

The guiding idea: the runtime `definition` should work like a BOM
(Bill of Materials). Each pipeline step adds its own section to the same
definition object. Results and test artifacts should expose those sections 1:1
instead of creating separate mapped formats.

## Handoff

Start a new Codex task with:

```text
Implement docs/architecture/planned/definition-bom-and-results.md.

This is the first step before implementing
docs/architecture/planned/stateless-manager-actions.md. Stabilize the BOM,
result, registry, and network artifact shapes first. The follow-up order is:

1. Definition BOM and result artifacts.
2. Stateless manager actions.
3. SpoonManager.installed registry view and selections.

Work in atomic refactor commits. Keep each commit logically balanced: when a
piece of behavior is removed from one side, wire the replacement on the other
side in the same commit.

Main goals:

1. Treat the runtime definition as the canonical BOM for pipeline state.
2. Add runtime sections to the definition instead of creating parallel result
   formats.
3. Persist installed.json as a map from installed name to the full BOM snapshot.
4. Make explain/network artifacts record snapshots of the actual definition at
   that point in time.
5. Remove unnecessary publicResult-style field mapping.
6. Keep tests away from manager-only shortcuts such as _prepareDefinition when a
   resolver/stage helper is the better owner.

Run the normal Lua test suite after each meaningful refactor slice:
/Users/muescha/.local/share/mise/installs/lua/5.4.4/bin/lua tests/run.lua
```

## Problem

Several places currently shape the same information differently:

1. The installer prepares a runtime definition with `config`, `resolved`,
   `command`, and `task`.

2. `Installer.publicResult()` creates a public table that copies some of that
   information into a separate `task` section.

3. Network tests write `explain.json`, `result.json`, and event output that can
   represent the same definition at different stages.

4. Tests use internal manager helpers such as `_prepareDefinition()` to build
   intermediate views, even though this is conceptually stage/resolver work.

This makes it harder to answer simple debugging questions:

- What exactly did this step know at this point?
- Was this field present on the runtime definition, or was it mapped into a
  result only for display?
- Did the explain artifact snapshot the current pipeline state, or did it
  calculate a second explanation?

## Decisions

1. The runtime definition is the canonical BOM.

   A definition starts from declarative `config`. Each pipeline step adds its
   own section to the same object:

   ```lua
   {
       config = { ... },
       resolved = { ... },
       command = { ... },
       task = { ... },
       registryMeta = { ... },
       result = { ... },
   }
   ```

   The exact section names can still be refined, but the shape should stay
   additive. Do not create a second unrelated result schema that drops or
   renames the pipeline sections.

2. The installed registry should store the full BOM definition.

   `installed.json` should be a map from installed name to the complete
   definition/BOM snapshot:

   ```lua
   {
       Emojis = {
           config = { ... },
           resolved = { ... },
           command = { ... },
           task = { ... },
           stage = { ... },
           registryMeta = { ... },
           result = { ... },
       },
   }
   ```

   Do not store a curated durable subset and do not wrap the definition in an
   extra `definition = { ... }` section. The registry entry itself is the saved
   BOM.

   The registry should intentionally keep everything that helps explain what
   happened, including temporary paths and runtime/debug details. This makes
   persistence simpler, makes later debugging easier, and lets future features
   extract the durable parts they need from the saved BOM instead of requiring
   today to predict every future consumer.

3. `registryMeta` should be a definition section.

   Registry-related metadata belongs on the runtime definition as a section, not
   as loose top-level result fields and not as a separate mapped structure.

   It can contain values such as:

   ```lua
   registryMeta = {
       installedAt = "...",
       updatedAt = "...",
       previousFingerprints = { ... },
       persistedFingerprints = { ... },
   }
   ```

4. Explain artifacts are snapshots.

   An explain event should record the definition exactly as it exists at that
   point in the pipeline. It should not trigger a second resolve/command
   calculation just to manufacture an explain artifact.

   If the current definition only has `config`, explain records only `config`.
   If the current definition has `config`, `resolved`, and `command`, explain
   records those sections. This keeps explain passive and honest.

5. Result artifacts should show the full run flow.

   Network `result.json` should make the sequence of events understandable. It
   should include the full install/update output for each step, not only a
   reduced final status.

   Preferred shape:

   ```lua
   {
       success = true,
       test = { ... },
       paths = { ... },
       events = {
           {
               step = "prepare",
               definition = { config = { ... }, resolved = { ... } },
           },
           {
               step = "install",
               output = {
                   definition = {
                       config = { ... },
                       resolved = { ... },
                       command = { ... },
                       task = { ... },
                       registryMeta = { ... },
                       result = { ... },
                   },
               },
               checks = { ... },
           },
       },
   }
   ```

   The artifact may add test-only metadata such as `paths`, `checks`, and
   `events`, but it should not remap SpoonManager output into a different shape.

6. Public action results should expose the definition 1:1.

   `publicResult()` or its replacement should not remove `resolved`, `command`,
   `task`, or future sections such as `registryMeta`.

   Instead of:

   ```lua
   {
       success = true,
       task = {
           config = definition.config,
           resolved = definition.resolved,
           command = command,
       },
       result = { ... },
   }
   ```

   prefer:

   ```lua
   {
       success = true,
       definition = definition,
   }
   ```

   or, when the surrounding stateless batch result is implemented:

   ```lua
   {
       success = true,
       action = "install",
       runs = {
           {
               success = true,
               definition = definition,
           },
       },
   }
   ```

   The important rule is not the wrapper name. The important rule is that the
   prepared definition comes out intact.

7. Stage helpers should live at the owner boundary.

   Tests and network artifacts should not need to call manager-only helpers such
   as `_prepareDefinition()` just to inspect a pipeline stage.

   Better ownership options:

   - `DefinitionResolver.prepare(definition, action)` if preparation is mainly
     resolve/command construction.
   - `Installer.prepareDefinition(config, action)` if preparation is considered
     part of executable install/update setup.
   - A small dedicated internal stage helper if neither owner is clean.

   The chosen helper should accept config or a definition, return a definition
   with added sections, and avoid side effects.

## Implementation Cut

1. Add tests around the desired result shape.

   First lock down that install/update output includes the full prepared
   definition. This makes later mapping removal visible.

2. Replace `publicResult()` mapping with definition passthrough.

   Keep the wrapper minimal and return the prepared definition intact.

3. Persist the full BOM definition in `installed.json`.

   Replace curated registry writes with storing the complete definition snapshot
   under the installed name. Keep `registryMeta` as one section inside that
   definition.

4. Update network result artifacts.

   Make each event record the actual definition/output at that stage. Do not
   run an extra explain calculation for explain events.

5. Replace `_prepareDefinition()` usage in tests.

   Move stage preparation to the chosen owner and update tests to call that
   owner directly.

6. Update docs and snapshots.

   Refresh network artifact docs and test snapshots only after the code shape is
   stable.

## Non-Goals

1. Do not change source fetching or staging behavior.

2. Do not remove the installed registry.

3. Do not introduce history storage yet. This note is about the current action
   definition and current run artifacts.

4. Do not make explain active. Explain remains a passive snapshot.

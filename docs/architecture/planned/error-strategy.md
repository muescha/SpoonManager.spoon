# Configurable error strategy (throw / graceful / silent)

**Status: Planned — deliberately deferred (YAGNI).**

Today every validation and resolve error **throws** and aborts the operation.
For the current usage (hand-written `init.lua` scripts) that is the right
behavior: fail fast, at the exact call, with a clear message. This document
records a design to make the behavior *switchable* — to build only once a real
consumer needs it.

## When this becomes worth building

Build it when a consumer exists that must **not** hard-abort on a single bad
input, i.e. one of:

- **A GUI** (planned in `discovery-website-and-gui.md`) that should show an error
  in the UI instead of raising a Lua error.
- **Batch / manifest installs** (planned in `spoonify-manifests.md`): installing
  a list of Spoons where one malformed entry should be skipped-and-reported, not
  abort the whole run.

Until then, the switch has no caller and would be infrastructure on spec.

## Proposed design

A strategy switch applied at the **boundary**, not at the error site.

- **`SM.options.errorStrategy`** — enum of valid modes (mirrors
  `SM.options.conflictStrategy`): `{ throw, graceful, silent }`.
- **`SM.errorStrategy`** — the active mode, a global manager field. Default
  `throw` (= today's behavior, zero change). Set by the host/GUI, **not** a
  per-Spoon option and **not** a builder method.
- **`SM._isErrorStrategy(value)`** — validator (mirrors `_isConflictStrategy`);
  the boundary asserts the active mode is valid.
- **`Util.raise(message, source)`** — a **stateless, context-free** helper that
  throws a *tagged* error carrying structured context:

  ```lua
  function Util.raise(message, source)
      error(setmetatable(
          { smError = true, message = message, source = source },
          { __tostring = function(e) return e.message end }
      ))
  end
  ```

  `__tostring` returns the message so existing `assertError(fn, pattern)` tests
  keep matching on text.

- **The boundary** — the entry points that run resolve/install
  (`.install()`, `.update()`), which *do* have
  manager access — wrap the call in `pcall` and, on a tagged error, act per
  `SM.errorStrategy`:

  ```lua
  local ok, err = pcall(...)
  if not ok and type(err) == "table" and err.smError then
      SM._recordRaisedIssue({ timestamp = os.time(), error = err.message, source = err.source })
      if SM.errorStrategy == "throw"    then error(err) end     -- propagate, loud
      if SM.errorStrategy == "graceful" then return nil, err.message end
      if SM.errorStrategy == "silent"   then return nil end      -- swallow, but logged
  end
  -- untagged errors (genuine bugs) always propagate, in every mode
  ```

- **`SM._raisedIssues` / `SM.errorsToList()`** — an observability log the
  boundary populates when it catches a tagged error. Useful for the GUI and for
  tests (`assert(#SM.errorsToList() == 1 and ... source == ...)`).

## Key constraints (why it must be this shape)

1. **`Util` is context-free** (`local Util = {}`, no `context`). The low-level
   validators (`requireSafeRelPath`, `requireSafeFileName`, `requireZipPath`)
   live there and cannot reach the manager. So the throw primitive must live in
   `Util` and stay **stateless** — it only tags and throws. The manager-side
   list is filled at the **boundary**, not by `raise`. Hence `Util.raise` +
   `SM.errorsToList()`, **not** an `SM._internal.errors.raise()` that the deep
   validators could not call.

2. **Lua errors unwind the stack.** `error()` does not return, and the builder
   is chained (`.path("../x").install()`). So graceful/silent **cannot** be a
   `return` at the error site — every layer would have to check-and-propagate.
   The only clean mechanism is a `pcall` at the boundary.

3. **Tagging separates expected errors from bugs.** Only `Util.raise` errors are
   tagged; genuine internal bugs (e.g. the `resolvePathWithoutZip` invariant)
   use raw `error()` and therefore **always** propagate, even in `graceful` /
   `silent`. That separation falls out for free.

4. **`raise` always stops execution.** There is no "collect and keep going": the
   code after a `raise` assumes the operation aborted, so continuing would work
   with invalid values. `silent` means "the boundary swallows and logs it", not
   "accumulate multiple errors per run". A true accumulate-and-continue mode
   would be a larger refactor (validators would have to accumulate rather than
   abort) and is out of scope for this note.

5. **Builder-time errors always throw.** The chained builder API cannot be made
   graceful; the switch only governs the resolve/install path.

## Open naming decisions (parked)

- `Util.raise` vs `Util.fail` vs `Util.error` (avoid shadowing the Lua builtin).
- `SM._raisedIssues` + `SM.errorsToList()` (matches the current `_`-prefix
  convention) vs introducing an `SM._internal.*` namespace. The codebase today
  uses the `_`-prefix (`_isConflictStrategy`, `_installAndRememberDefinition`); a
  dedicated `_internal.errors.*` sub-API is only worth it as a deliberate,
  project-wide convention change, not for this one feature.

## Decision

Do **not** implement now. Revisit when a GUI or batch/manifest consumer both
exists and requires non-aborting error handling. Current abort-on-error behavior
is intentional and correct for scripted use.

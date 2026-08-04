# AGENTS

## Hammerspoon / Lua Rules

- Use `SpoonManager.spoon` as the Spoon root. The main entry point is `init.lua`.
- Prefer the regular Spoon shape:
  - `local obj = {}`
  - `obj.__index = obj`
  - metadata on `obj.name`, `obj.version`, `obj.author`, `obj.homepage`, `obj.license`
  - `obj.logger = hs.logger.new("SpoonName")`
  - `return obj`
- Public SpoonManager builder APIs use dot notation, not colon notation.
- Builder calls should be side-effect free until an action is called.
- `install()` is synchronous and should return only after the Spoon is available or an error happened.
- `installAsync()` may be added later, but async behavior must be explicit.
- Direct install paths must not require a catalog or discovery call when the source is already known.
- `catalog.json` is optional and only for browsing/search/GUI-style workflows.
- `spoonify.json` may be used later as an optional JSON version of builder definitions.
- Protect local user changes before overwriting an installed Spoon. Default behavior is abort.
- Persist install metadata separately from builder definitions so future updates know the source.

## Syntax Check

- Lua is installed via `mise`, not necessarily on `PATH`.
- Use:

```sh
/Users/muescha/.local/share/mise/installs/lua/5.4.4/bin/lua -e 'assert(loadfile("/Users/muescha/Work/github.com/muescha/SpoonManager.spoon/init.lua"))'
```

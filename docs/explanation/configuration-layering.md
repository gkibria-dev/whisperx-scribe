# Why configuration is layered

## The problem

Three kinds of value end up in the same configuration:

- values that are right for everyone, such as "the default model is `medium`";
- values that are right for one computer, such as "my environment is on drive E, because drive C
  is full";
- values that are right for one run, such as "this recording is in German".

Putting all three in one committed file means every machine-specific edit shows up as a
modified file in Git, and sooner or later someone commits their own paths.

## The layers

Each layer overrides the one before it, key by key:

```text
built-in defaults  →  settings.json  →  settings.local.json  →  command-line argument
(settings.ps1)        (committed)       (gitignored)            (this run only)
```

Each layer matches one kind of value:

- **Built-in defaults** in `Get-DefaultProjectSettings` mean the project works even if the
  settings file is missing or partial. Deleting `settings.json` is not a broken state.
- **`settings.json`** is committed, and holds what is true for the project rather than for a
  person. It uses `%LOCALAPPDATA%` instead of a real path, so the same file works on any Windows
  computer.
- **`settings.local.json`** is gitignored, and is where a person's own paths and preferences go.
  It is optional, and it only names the keys it changes.
- **Command-line arguments** win over all of it, for the case that is different this once.

This is the same pattern as `settings.json` plus a local override in VS Code, or user settings
plus project settings in Claude Code. It is familiar, and it keeps personal values and shared
values in separate files rather than in separate branches.

## Merging one key at a time

The override merges per key, not per section. If `settings.json` sets both `venvPath` and
`pythonCommand`, and a local file sets only `venvPath`, then `pythonCommand` still comes from
`settings.json`.

Whole-section replacement would be simpler to implement and much worse to use: overriding one
path would silently reset every sibling key to a built-in default, and the resulting value
would appear nowhere in any file the user had written. `tests\test-settings.ps1` asserts the
per-key behavior directly, including the sibling case.

## Why `null` does not clear a value

A key set to `null` leaves the previous layer's value in place, because the merge treats `null`
as "not supplied". JSON has no way to express "explicitly unset" that is distinguishable from
"absent" without inventing a sentinel value, and the alternative reading would make every
`null` in a settings file into a hidden reset.

The practical consequence: to stop using an inherited value, delete the key rather than setting
it to `null`.

## Why secrets are excluded

`HF_TOKEN` is deliberately not a setting. `settings.json` is committed, and `settings.local.json`
sits in the same folder as a file that is committed, one `.gitignore` mistake away from being
published. Environment variables have neither problem, and the token then flows to child
processes without any script having to pass it around or print it.

`test-settings.ps1` scans both files for anything token-shaped, so this stays true rather than
being a convention people remember.

## Related

- [Reference: settings](../reference/settings.md)
- [How-to: change the defaults on one computer](../how-to/change-machine-defaults.md)
- [Explanation: runtime outside the repository](runtime-outside-the-repository.md)

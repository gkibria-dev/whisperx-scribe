# Plan: `test-pipeline.ps1` takes its defaults from settings

| | |
|---|---|
| **Status** | **Implemented** 2026-09-17 (see §6 for what was verified) |
| **Date** | 2026-09-17 |
| **Scope** | `tests/test-pipeline.ps1`, `settings.ps1`, `settings.json`, `tests/test-settings.ps1`, `docs/reference/settings.md`, `docs/reference/test-scripts.md`, `README-testing.md` |
| **Explicitly out of scope** | How `-Language` is resolved (§3, D4). Why the pipeline test fails on this machine. |

## 1. Current state — the problem

Every script except one gets its defaults from `settings.ps1` (`Get-ProjectSettings`).
`tests/test-pipeline.ps1` is the exception: its `param()` block hard-codes `-Model "medium"`,
`-Device "cpu"` and `-ComputeType "int8"`. The test already loads the settings for
`test.outputDirectory`, `test.keepOutput` and `environment.venvPath`. Only these three values skip
the loader. So a machine that needs different values, such as a GPU machine running `cuda` /
`float16`, has to pass them on every run. This was deferred from
[user-documentation-plan.md](user-documentation-plan.md) §8.

## 2. Target state

- `test-pipeline.ps1` gets the model, device and compute type from the argument when it is not
  empty. Otherwise it uses the new settings `test.model`, `test.device` and `test.computeType`.
  Their defaults are `medium` / `cpu` / `int8`, so nothing changes unless a machine sets them.
- The resolved values are printed in the test header.
- `-MinSpeakers 2 -MaxSpeakers 2` stays fixed.
- The reference docs say where each value comes from.

## 3. Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Read `test.*`, not `pipeline.*` | `pipeline.*` says how this machine's *real* transcriptions should run. If the test followed it, a local `pipeline.model = "large-v3"` would make every test run much slower without warning, and whether the test passes would depend on each person's preferences. |
| D2 | Make the values settings rather than keep them hard-coded | A machine can have a real reason to change them (GPU: `cuda` / `float16`). The `test` section already exists for test-only machine settings. |
| D3 | All three come from the same section | The compute type has to match the device. If some values came from `pipeline.*` and some from `test.*`, the combination might not work. |
| D4 | The speaker count stays fixed at 2, with no setting and no parameter | It belongs to the sample, not to the machine. The assertions (`SPEAKER_00` and `SPEAKER_01`) depend on it. Passing it explicitly already stops `run_pipeline.ps1` from falling back to `pipeline.minSpeakers` / `pipeline.maxSpeakers`. |
| D5 | `-Language` is unchanged | When it is empty, `run_pipeline.ps1` still uses `pipeline.language`. That is the one machine setting that still reaches the test. The reasoning in D1 applies to it too, but it wasn't part of this change. Possible follow-up. |

## 4. Implementation steps

1. `settings.ps1` `Get-DefaultProjectSettings` and `settings.json`: add `test.model`,
   `test.device`, `test.computeType` (`medium`, `cpu`, `int8`).
2. `tests/test-pipeline.ps1`: parameter defaults become `""`. After `Get-ProjectSettings`,
   empty values are filled from `$Settings.test.*`, following the pattern in `run_pipeline.ps1`.
   Add header lines for the resolved values, and update the comment-based help.
3. `tests/test-settings.ps1`: assert that `test.model` falls back to its built-in default, and
   that `test-pipeline.ps1` reads `Settings.test.<key>` and not `Settings.pipeline.<key>` for all
   three keys.
4. `docs/reference/settings.md`: add the keys to the default file block, plus three new
   `### test.*` headings.
5. `docs/reference/test-scripts.md`: add settings table rows, a table showing where each value
   comes from before the parameter list, and new `-Model` / `-Device` / `-ComputeType` defaults.
6. `README-testing.md`: mention the new keys. `user-documentation-plan.md` §8: mark the
   follow-up as done.

## 5. Validation criteria

1. `tests/test-settings.ps1` and `tests/test-docs.ps1` pass.
2. The defaults in the reference docs match `settings.ps1` and `settings.json`. Check this by
   hand, because `test-docs.ps1` only compares names.
3. The arguments `test-pipeline.ps1` passes to `run_pipeline.ps1` are the resolved values. The
   pipeline test passing is not the criterion, because it fails on this machine for unrelated
   reasons (user-documentation-plan.md §7).

## 6. Verification record (2026-09-17)

| Criterion | Result |
|---|---|
| 1 | **Pass.** `test-settings.ps1`: 59 assertions. `test-docs.ps1`: 15 assertions. |
| 2 | **Pass.** Checked by hand: `medium` / `cpu` / `int8` in `settings.ps1`, `settings.json`, `settings.md` and `test-scripts.md`. |
| 3 | **Pass.** A scratch copy of `settings.ps1`, `test-pipeline.ps1`, `run_pipeline.ps1` and the sample, with a fake `Scripts\python.exe` and a `powershell.exe` function that captures the child call's arguments. (a) No `test.*` keys: `-Model medium -Device cpu -ComputeType int8 -MinSpeakers 2 -MaxSpeakers 2`. (b) `settings.json` with `pipeline` = `large-v3` / `cuda` / `float16` / min 1 / max 5, and `settings.local.json` with `test.model = tiny`, `test.device = cuda`: `-Model tiny -Device cuda -ComputeType int8 -MinSpeakers 2 -MaxSpeakers 2`. (c) As (b) plus `-Model small`: `-Model small`. No `pipeline.*` value appeared in any case. |

The real pipeline test was not run for this change.

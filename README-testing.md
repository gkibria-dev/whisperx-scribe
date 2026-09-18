# WhisperX Scribe — Automated Testing

This project has four automated PowerShell tests. Run them from the repository root.

| Test | What it covers | Needs an environment? |
|---|---|---|
| `tests\test-settings.ps1` | Configuration layering and Git hygiene | No — runs in seconds, offline |
| `tests\test-docs.ps1` | Every script option and setting is documented in `docs\reference\` | No — runs in seconds, offline |
| `tests\test-clean-install.ps1` | Fresh clone → working environment | Builds its own, isolated |
| `tests\test-pipeline.ps1` | End-to-end transcription | Yes |

Run the two fast tests first: they catch configuration and documentation mistakes before the
two slow tests spend minutes on model downloads and CPU inference.

```powershell
.\tests\test-settings.ps1
.\tests\test-docs.ps1
.\tests\test-pipeline.ps1
.\tests\test-clean-install.ps1
```

No test writes anything inside the repository, and `git status` should be clean after any of
them. The slow tests use the external locations configured in `settings.json`
(`test.outputDirectory`, `test.environmentPath`, `test.keepOutput`), and the pipeline test takes
its model, device and compute type from `test.model`, `test.device` and `test.computeType`.

## Documentation

| You want to | Go to |
|---|---|
| Run a test for a particular kind of change | [How-to: run the tests](docs/how-to/run-the-tests.md) |
| Look up a test's parameters, assertions or isolation rules | [Reference: test scripts](docs/reference/test-scripts.md) |
| Fix a `test-docs.ps1` failure | [Reference: `test-docs.ps1`](docs/reference/test-scripts.md#test-docsps1) |
| Understand why the tests stay out of the real environment | [Explanation](docs/explanation/runtime-outside-the-repository.md) |

## What each test does

**`test-settings.ps1`** verifies the layering that every other script depends on — built-in
defaults, then `settings.json`, then `settings.local.json` — including that a partial override
replaces only the keys it names. It also checks path expansion, that neither settings file
contains anything token-shaped, and that `settings.local.json` is gitignored and untracked.
Layering assertions run against synthetic files in a temporary directory, so your real
`settings.local.json` is never read or written.

**`test-docs.ps1`** reads the parameters of every PowerShell script, the `add_argument` names of
every stage script, and the keys of `Get-DefaultProjectSettings`, then checks them against the
headings in `docs\reference\`. It fails both when an option is undocumented and when a
documented option no longer exists.

**`test-clean-install.ps1`** copies the repository to a temporary folder and runs the public
`01-Environment-Setup\setup.ps1` against its **own** environment, then verifies WhisperX and
`DiarizationPipeline` in it. Two mechanisms keep it away from the environment you work with: it
passes an explicit `-EnvironmentPath`, and it excludes `settings.local.json` from the copy. It
aborts if the test environment would overlap the normal one. On failure, both the copy and the
test environment are kept, and their paths are printed.

**`test-pipeline.ps1`** runs the production `02-Transcription-Pipeline\run_pipeline.ps1` against
`tests\data\sample-2-speakers.wav` with `-MinSpeakers 2 -MaxSpeakers 2`, then checks that all
four outputs exist and are non-empty, that each JSON has segments, and that both `SPEAKER_00`
and `SPEAKER_01` appear in the diarized output and the final transcript. Each run writes to its
own timestamped folder under `test.outputDirectory`, which is deleted after a successful run and
kept after a failure.

## Test philosophy

The tests call the project's real entry points rather than reimplementing the setup, the
pipeline or the settings loader.

That helps catch broken repository paths, missing files, setup regressions, dependency and
import problems, pipeline stage failures, missing or empty outputs, speaker diarization
regressions, and documentation that has drifted from the code.

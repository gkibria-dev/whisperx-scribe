# WhisperX Transcription — Automated Testing

This project has three automated PowerShell tests.

| Test | What it covers | Needs an environment? |
|---|---|---|
| `tests\test-settings.ps1` | Configuration layering and Git hygiene | No — runs in seconds, offline |
| `tests\test-clean-install.ps1` | Fresh clone → working environment | Builds its own, isolated |
| `tests\test-pipeline.ps1` | End-to-end transcription | Yes |

Run the settings test first: it is fast and catches configuration mistakes before the two slow
tests spend minutes on model downloads and CPU inference.

No test writes anything inside the repository. They use the external locations configured in
`settings.json`:

| Setting | Used for |
|---|---|
| `test.outputDirectory` | Per-run folders holding the pipeline test's generated transcripts |
| `test.environmentPath` | The clean-install test's own throwaway Python environment |
| `test.keepOutput` | Keep pipeline test artifacts after a successful run |

After any of them finishes, `git status` should be clean.

## 1. Settings test

Run from the repository root:

```powershell
.\tests\test-settings.ps1
```

This test verifies the configuration layering that every other script depends on:

```text
built-in defaults  ->  settings.json  ->  settings.local.json
```

It asserts that:

- the built-in defaults apply when no settings file exists;
- `settings.json` overrides those defaults;
- `settings.local.json` is recognised when present and overrides matching values;
- **a partial override replaces only the keys it names** — a sibling key in the same section,
  and every unrelated section, still come from `settings.json`;
- `%LOCALAPPDATA%` and other environment variables expand, and the resolved environment path
  is absolute and outside the repository;
- neither settings file contains anything resembling a token, secret or credential;
- `settings.local.json` is ignored by Git and untracked, while `settings.json` is not ignored;
- `setup.ps1` and `run_pipeline.ps1` both resolve the environment through the settings loader
  and contain no repository-local fallback.

Layering assertions run against synthetic settings files in a temporary directory, so the test
never reads or writes your real `settings.local.json`. It needs no WhisperX environment,
downloads nothing, and finishes in seconds.

If `settings.local.json` is absent, the assertions specific to it are skipped and reported as
skipped — the file is optional.

## 2. Clean-install test

Run from the repository root:

```powershell
.\tests\test-clean-install.ps1
```

This test:

- validates the repository structure
- creates an isolated temporary repository copy
- runs the public `01-Environment-Setup\setup.ps1` against its **own** environment
- verifies the newly created environment
- verifies WhisperX and `DiarizationPipeline`
- removes the temporary repository copy and the test environment when finished

### Isolation

The test must never build on, or overwrite, the environment you use day to day. Two
mechanisms enforce that:

1. It passes an explicit `-EnvironmentPath` to the copied `setup.ps1`, pointing at a unique
   folder under `test.environmentPath`. Without this the copied setup would read the copied
   `settings.json` and resolve your real environment.
2. It excludes `settings.local.json` when copying the repository, so a local override cannot
   follow the copy and redirect the test.

The test also aborts up front if the configured test environment resolves to the same path as
the normal one.

On failure, both the temporary repository copy and the test environment are retained for
diagnosis, and their paths are printed.

### Troubleshooting

Keep the temporary test repository:

```powershell
.\tests\test-clean-install.ps1 -KeepTemp
```

Use a different Python command:

```powershell
.\tests\test-clean-install.ps1 -PythonCommand py
```

The setup script is responsible for checking/installing FFmpeg. The clean-install test therefore does not require FFmpeg to already be on PATH.

## 3. Pipeline integration test

Run:

```powershell
.\tests\test-pipeline.ps1
```

This test executes the **same production**:

```text
02-Transcription-Pipeline\run_pipeline.ps1
```

against:

```text
tests\data\sample-2-speakers.wav
```

It then verifies:

1. raw JSON was created
2. aligned JSON was created
3. diarized JSON was created
4. final TXT was created
5. raw transcription contains segments
6. alignment contains segments
7. diarization contains segments
8. at least two speakers were detected
9. `SPEAKER_00` exists
10. `SPEAKER_01` exists
11. final transcript contains both speakers

The test uses `-MinSpeakers 2 -MaxSpeakers 2` for the two-speaker sample.

### Where the output goes

Each run writes to its own timestamped folder under `test.outputDirectory`, for example:

```text
%LOCALAPPDATA%\WhisperX-Transcription\test-output\sample-2-speakers-20260912-143005\
```

The folder is deleted after a successful run. A **failed** run always keeps its folder — those
artifacts are the evidence needed to diagnose the failure — and prints the path.

### Keep pipeline test output

```powershell
.\tests\test-pipeline.ps1 -KeepOutput
```

Set `test.keepOutput` to `true` in `settings.json` to make this the default.

### Use another audio file

```powershell
.\tests\test-pipeline.ps1 -Audio ".\tests\data\another-sample.wav"
```

The default assertions expect two speakers, so a one-speaker file should be tested with a separate test configuration or assertion strategy.

## Test philosophy

The tests intentionally call the project's real entry points rather than reimplementing the setup or transcription pipeline.

That helps catch:

- broken repository paths
- missing files
- environment/setup regressions
- dependency/import problems
- pipeline stage failures
- missing output files
- empty results
- speaker diarization regressions


# WhisperX Transcription — Automated Testing

This project has two automated PowerShell tests.

## 1. Clean-install test

Run from the repository root:

```powershell
.\tests\test-clean-install.ps1
```

This test:

- validates the repository structure
- creates an isolated temporary repository copy
- excludes the existing `.venv`
- runs the public `01-Environment-Setup\setup.ps1`
- verifies the newly created environment
- verifies WhisperX and `DiarizationPipeline`
- removes the temporary test environment when finished

It does **not** depend on the existing repository `.venv`.

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

## 2. Pipeline integration test

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

### Keep pipeline test output

```powershell
.\tests\test-pipeline.ps1 -KeepOutput
```

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

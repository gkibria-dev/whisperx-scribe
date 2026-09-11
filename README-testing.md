# Automated Testing

The repository contains a clean-install test that validates the environment setup without using the developer's existing virtual environment.

## Clean-install test

From the repository root:

```powershell
.\tests\test-clean-install.ps1
```

The test automatically:

1. Validates the required Phase 1 files.
2. Checks that Python and FFmpeg are available.
3. Creates an isolated temporary copy of the repository.
4. Runs all four Phase 1 setup scripts against that copy.
5. Verifies the newly created `.venv`.
6. Independently imports PyTorch, TorchCodec, WhisperX, and `DiarizationPipeline`.
7. Deletes the temporary test environment when finished.

It does **not** modify or depend on the developer's existing `.venv`/`env`.

### Keep the temporary copy

For troubleshooting:

```powershell
.\tests\test-clean-install.ps1 -KeepTemp
```

### Optional pip upgrade

```powershell
.\tests\test-clean-install.ps1 -UpgradePip
```

## What this test does not automate

Hugging Face account creation, acceptance of model terms, and creation of an access token are account-level actions and are not performed by the repository test.

The token is only needed for the speaker-diarization stage of the transcription pipeline.

# WhisperX Transcription — Testing Guide

This document describes the automated tests for the WhisperX Transcription project.

The purpose of these tests is to verify that a fresh clone of the repository can prepare its own environment and that the installed WhisperX components are usable.

---

## Test Structure

The testing files are located under:

```text
tests/
```

The test suite is separate from the normal transcription pipeline.

```text
WhisperX-Transcription/
│
├── 01-Environment-Setup/
│
├── 02-Transcription-Pipeline/
│
├── tests/
│   └── test-clean-install.ps1
│
├── README.md
├── README-testing.md
├── requirements.txt
└── .gitignore
```

---

## Clean-Install Test

The clean-install test is designed to test the environment setup without using or modifying the existing project virtual environment.

From the repository root, run:

```powershell
.\tests\test-clean-install.ps1
```

The test automatically:

1. Validates the required Phase 1 setup files.
2. Checks that Python and FFmpeg are available.
3. Creates an isolated temporary copy of the repository.
4. Runs the Phase 1 `setup.ps1` entry point against that copy.
5. Verifies that a new `.venv` was created.
6. Verifies the important WhisperX dependencies.
7. Imports WhisperX successfully.
8. Verifies the `DiarizationPipeline` API.
9. Removes the temporary test environment when the test finishes.

The test does **not** use or modify the developer's existing `.venv` or other local Python environment.

---

## Why Use a Clean Installation?

A project may work on the developer's machine simply because the required packages have already been installed manually.

That does not prove that a new user can clone the repository and set it up successfully.

The clean-install test addresses this by creating a temporary copy of the repository and running the setup process there.

Conceptually:

```text
Existing Development Environment
        │
        │  NOT USED
        ▼
   ┌─────────────┐
   │ Test Script │
   └──────┬──────┘
          │
          ▼
 Temporary Repository
          │
          ├── setup.ps1
          │
          ▼
 Temporary .venv
          │
          ├── WhisperX
          ├── PyTorch
          ├── TorchCodec
          └── DiarizationPipeline
          │
          ▼
       Verify
          │
          ▼
       Cleanup
```

This makes the test much closer to what happens when someone clones the project on a new PC.

---

## What the Test Does Not Verify

Some parts of the environment setup cannot be fully automated because they require interaction with Hugging Face.

In particular, the test does not attempt to:

- Create a Hugging Face account.
- Log in to Hugging Face.
- Accept Hugging Face model terms on behalf of the user.
- Generate or obtain a Hugging Face access token.
- Store a user's private token.

Those steps remain user responsibilities.

The setup script can request the Hugging Face token when required.

---

## Phase 1 vs Phase 2

The project has two major phases.

### Phase 1 — Environment Setup

The normal entry point is:

```powershell
.\01-Environment-Setup\setup.ps1
```

This prepares the computer for WhisperX.

The numbered scripts inside `01-Environment-Setup` are the individual implementation steps used by the setup process.

Normally, a user should not need to execute them individually.

### Phase 2 — Transcription

Once the environment has been successfully prepared, the user runs:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"
```

The transcription pipeline produces:

```text
*_raw.json
*_aligned.json
*_diarized.json
*_final.txt
```

---

## Recommended Testing Workflow

For development or before pushing changes to GitHub:

### 1. Run the clean-install test

From the repository root:

```powershell
.\tests\test-clean-install.ps1
```

Confirm that it finishes successfully.

### 2. Run a short transcription test

Use a short audio file rather than a long recording.

For example:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "E:\AI\WhisperX\test\pipeline-test-30s.wav"
```

A short test file is useful because WhisperX processing on CPU can take considerably longer for longer recordings.

### 3. Verify the generated files

The expected outputs are:

```text
pipeline-test-30s_raw.json
pipeline-test-30s_aligned.json
pipeline-test-30s_diarized.json
pipeline-test-30s_final.txt
```

The final human-readable transcript is:

```text
pipeline-test-30s_final.txt
```

---

## What Success Looks Like

A successful clean-install test should confirm that:

```text
Python
   ↓
Virtual Environment
   ↓
Dependencies
   ↓
WhisperX
   ↓
DiarizationPipeline
```

are all available and usable.

A successful transcription test should confirm:

```text
Audio
   ↓
Raw transcription
   ↓
Alignment
   ↓
Speaker diarization
   ↓
Final transcript
```

---

## Troubleshooting

If the clean-install test fails, read the first error reported by the script.

Common causes include:

### Python unavailable

Verify:

```powershell
python --version
```

### FFmpeg unavailable

Verify:

```powershell
ffmpeg -version
```

### WhisperX installation failure

Check the output from the dependency installation step.

### Hugging Face authentication failure

Make sure:

- A Hugging Face account exists.
- The required model access/terms have been accepted.
- A valid Hugging Face access token is available.

### Existing environment works but clean-install test fails

This is exactly the type of problem the clean-install test is intended to detect.

Do not assume that because the existing `.venv` works, a fresh clone will work.

---

## Important

The automated clean-install test creates a temporary environment.

It should **not** be used as the normal way to prepare the developer's working environment.

For normal setup use:

```powershell
.\01-Environment-Setup\setup.ps1
```

For normal transcription use:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\path\to\audio.wav"
```

The test is primarily for validating that the repository remains usable for a new user.

---

## Maintenance

Whenever changes are made to:

- `01-Environment-Setup`
- `requirements.txt`
- WhisperX installation logic
- Python dependency versions
- Hugging Face/diarization configuration

the clean-install test should be run again.

This helps ensure that the repository can still be set up from a clean state.

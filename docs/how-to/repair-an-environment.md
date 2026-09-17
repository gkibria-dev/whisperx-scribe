# How to repair a broken environment

Fix an environment where setup or the pipeline fails with an import or package error.

## Find the failing part

1. Check Python and FFmpeg:

   ```powershell
   .\01-Environment-Setup\01-check-prerequisites.ps1
   ```

2. Check the installed packages:

   ```powershell
   .\01-Environment-Setup\04-verify-installation.ps1
   ```

   This changes your PowerShell location to the repository root.
3. Note the first check that fails.

| First failure | Go to |
|---|---|
| `Python was not found on PATH` | Install Python 3.10–3.13, reopen PowerShell, then run `setup.ps1` |
| `FFmpeg was not found on PATH` | Run `setup.ps1`, which installs FFmpeg |
| FFmpeg 8 or newer warning, with `TorchCodec verification failed.` | [Use FFmpeg 7](#use-ffmpeg-7) |
| `Virtual environment not found` | [Rebuild the environment](#rebuild-the-environment) |
| `PyTorch`, `WhisperX` or `DiarizationPipeline` verification failed | [Reinstall packages](#reinstall-packages) |

## Reinstall packages

1. Reinstall the pinned CPU PyTorch and the requirements:

   ```powershell
   .\01-Environment-Setup\03-install-whisperx.ps1 -UpgradePip
   ```

2. Run `.\01-Environment-Setup\04-verify-installation.ps1` again.
3. If it still fails, [rebuild the environment](#rebuild-the-environment).

## Rebuild the environment

1. Delete the environment directory. The default is:

   ```powershell
   Remove-Item -LiteralPath "$env:LOCALAPPDATA\WhisperX-Transcription\venv" -Recurse -Force
   ```

   If you changed `environment.venvPath`, delete that directory instead.
2. Run setup:

   ```powershell
   .\01-Environment-Setup\setup.ps1
   ```

## Use FFmpeg 7

1. Uninstall FFmpeg 8 or newer, or remove it from `PATH`.
2. Install an FFmpeg **7.x shared** build and add its `bin` directory to `PATH`.
3. Reopen PowerShell and check the version:

   ```powershell
   ffmpeg -version
   ```

4. Run `.\01-Environment-Setup\04-verify-installation.ps1`.

## Related

- [Reference: setup scripts](../reference/setup-scripts.md)

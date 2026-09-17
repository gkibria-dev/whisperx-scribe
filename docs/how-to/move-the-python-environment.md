# How to move the Python environment to another location

Put the environment on another drive, for example one with more free space.

A virtual environment can't be moved safely, so this guide builds a new one at the new location.

1. Choose the new directory, for example `E:\envs\whisperx`.
2. Set it in `settings.local.json` in the repository root:

   ```json
   {
     "environment": { "venvPath": "E:\\envs\\whisperx" }
   }
   ```

3. Run setup:

   ```powershell
   .\01-Environment-Setup\setup.ps1
   ```

   The `Environment:` line near the start of the output must show the new path.
4. Run the pipeline once to confirm that it works:

   ```powershell
   .\02-Transcription-Pipeline\run_pipeline.ps1 ".\tests\data\sample-2-speakers.wav" -OutputDirectory "$env:TEMP\wx-check"
   ```

5. Delete the old environment directory, by default `%LOCALAPPDATA%\WhisperX-Transcription\venv`.

Setup also reports any old `.venv`, `env` or `whisperx-env` folder inside the repository. You
can delete these once the new environment works.

Downloaded models are not stored in the environment and are not affected by this change.

## Related

- [Reference: `environment.venvPath`](../reference/settings.md#environmentvenvpath)
- [Reference: `setup.ps1 -EnvironmentPath`](../reference/setup-scripts.md#-environmentpath)
- [Explanation: runtime outside the repository](../explanation/runtime-outside-the-repository.md)

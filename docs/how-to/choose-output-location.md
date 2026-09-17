# How to choose where transcripts are written

By default, the four output files are written next to the audio file.

## Redirect one run

1. Pass an absolute directory path:

   ```powershell
   .\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\interview.wav" -OutputDirectory "D:\Transcripts"
   ```

   The directory is created if it doesn't exist.

## Collect every run in one folder

1. Add an `output` section to `settings.local.json` in the repository root:

   ```json
   {
     "output": {
       "mode": "directory",
       "directory": "D:\\Transcripts"
     }
   }
   ```

   Escape backslashes as `\\`. Leave out `directory` to use
   `%LOCALAPPDATA%\WhisperX-Transcription\output`.
2. Run the pipeline without `-OutputDirectory`.
3. Check the `Output:` line printed at the start of the run.

## Go back to writing next to the audio

1. Delete the `output` section from `settings.local.json`, or set `"mode": "beside-audio"`.

## Related

- [Reference: `-OutputDirectory`](../reference/run-pipeline.md#-outputdirectory)
- Reference: [`output.mode`](../reference/settings.md#outputmode), [`output.directory`](../reference/settings.md#outputdirectory)
- [Reference: output files](../reference/output-files.md)

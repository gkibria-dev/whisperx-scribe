# How to run a single pipeline stage

Re-run or debug one stage without repeating the stages before it.

**Before you start:** the output of the previous stage exists. For stage 3, for example, you
need `<stem>_aligned.json`.

1. Store the environment's Python path in a variable:

   ```powershell
   $py = "$env:LOCALAPPDATA\WhisperX-Transcription\venv\Scripts\python.exe"
   ```

   If you changed `environment.venvPath`, use that path instead.
2. Run the stage you need from the repository root:

   | Stage | Command |
   |---|---|
   | 1 Transcribe | `& $py .\02-Transcription-Pipeline\scripts\transcribe.py "C:\Rec\interview.wav" --language en` |
   | 2 Align | `& $py .\02-Transcription-Pipeline\scripts\align_and_merge.py "C:\Rec\interview.wav" "C:\Rec\interview_raw.json"` |
   | 3 Diarize | `& $py .\02-Transcription-Pipeline\scripts\diarize.py "C:\Rec\interview.wav" "C:\Rec\interview_aligned.json" --min-speakers 2 --max-speakers 2` |
   | 4 Finalize | `& $py .\02-Transcription-Pipeline\scripts\finalize.py "C:\Rec\interview_diarized.json"` |

   Each stage writes beside its input unless you pass `--output`.
3. Check the exit code:

   ```powershell
   $LASTEXITCODE
   ```

   `0` means success. Otherwise, read the `ERROR:` line or the traceback above it.
4. Re-run the later stages in order, so the files after the one you changed are rebuilt.

Stage 3 needs the Hugging Face token ([how-to](configure-hugging-face-token.md)).

## Related

- [Reference: pipeline stage scripts](../reference/pipeline-stage-scripts.md)
- [Reference: output files](../reference/output-files.md)

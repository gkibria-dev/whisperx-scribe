# How to transcribe a language without a default alignment model

Transcribe audio in a language such as Bengali (`bn`), where stage 2 fails with
`ERROR: Could not load an alignment model for language '<code>'.`

**Before you start:**

- Find the language code for the audio. Use the code (`bn`), not the name (`bengali`).
- Find a wav2vec2 CTC model fine-tuned on that language on
  [Hugging Face](https://huggingface.co/models?pipeline_tag=automatic-speech-recognition).
  This guide uses `arijitx/wav2vec2-xls-r-300m-bengali` as the example.

## For one run

1. Pass both `-Language` and `-AlignModel`:

   ```powershell
   .\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\call.m4a" `
       -Language bn -AlignModel arijitx/wav2vec2-xls-r-300m-bengali
   ```

2. Check that stage 2 prints
   `Loading alignment model for language: bn (arijitx/wav2vec2-xls-r-300m-bengali)...` and then
   `Alignment complete.`

## Resume after stage 2 failed

Stage 1 output is kept, so you can skip the transcription.

1. Set the paths:

   ```powershell
   $py = "$env:LOCALAPPDATA\WhisperX-Transcription\venv\Scripts\python.exe"
   $s  = ".\02-Transcription-Pipeline\scripts"
   $a  = "C:\Recordings\call"   # the audio path without its extension
   ```

   Replace `$py` with `<environment.venvPath>\Scripts\python.exe` if you moved the environment.

2. Run stages 2 to 4:

   ```powershell
   & $py "$s\align_and_merge.py" "$a.m4a" "${a}_raw.json" --align-model arijitx/wav2vec2-xls-r-300m-bengali
   & $py "$s\diarize.py" "$a.m4a" "${a}_aligned.json"
   & $py "$s\finalize.py" "${a}_diarized.json"
   ```

3. Open `<stem>_final.txt`.

## For every run on this computer

1. Open `settings.local.json` in the repository root. Create it if it does not exist.
2. Add both keys to the `pipeline` section:

   ```json
   {
     "pipeline": {
       "language": "bn",
       "alignModel": "arijitx/wav2vec2-xls-r-300m-bengali"
     }
   }
   ```

3. Save the file.
4. Run the pipeline without `-Language` or `-AlignModel`.

To go back to the defaults, remove both keys.

## Related

- [Reference: `-AlignModel`](../reference/run-pipeline.md#-alignmodel)
- [Reference: `pipeline.alignModel`](../reference/settings.md#pipelinealignmodel)
- [How to set the transcription language](set-transcription-language.md)
- [How to run a single stage](run-a-single-stage.md)

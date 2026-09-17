# How to set the transcription language

Set the spoken language explicitly, so the pipeline doesn't have to detect it.

**Before you start:** find the language code for the audio in the list under
[`-Language`](../reference/run-pipeline.md#-language). Use the code (`en`), not the name (`english`).

## For one run

1. Add `-Language` to the command:

   ```powershell
   .\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\interview.wav" -Language en
   ```

2. Check that the output contains no line starting with `Detected language:`.

   Stage 1 still prints `No language specified, language will be detected for each audio file`
   while the model loads. Ignore it. Only a `Detected language:` line means detection ran.

## For every run on this computer

1. Open `settings.local.json` in the repository root. Create it if it does not exist.
2. Add the `pipeline` section, or add the key to your existing `pipeline` section:

   ```json
   {
     "pipeline": { "language": "en" }
   }
   ```

3. Save the file.
4. Run the pipeline without `-Language`:

   ```powershell
   .\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\interview.wav"
   ```

To override this setting for one run, pass a different `-Language`.

## Go back to automatic detection

1. Remove `"language"` from `settings.local.json`, or set it to `""`.
2. Run the pipeline without `-Language`.

## Related

- [Reference: `-Language`](../reference/run-pipeline.md#-language)
- [Reference: `pipeline.language`](../reference/settings.md#pipelinelanguage)
- [Explanation: accuracy and speed trade-offs](../explanation/accuracy-and-speed-trade-offs.md)

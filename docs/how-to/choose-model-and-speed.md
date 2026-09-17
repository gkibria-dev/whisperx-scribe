# How to choose the model, device and compute type

Make a run faster, or more accurate.

**Before you start:** the environment is set up and a normal run works.

## Run faster on CPU

1. Choose a smaller model: `small` or `base`. For English-only audio, use `small.en` or `base.en`.
2. Set the language, so no detection runs ([how-to](set-transcription-language.md)).
3. Run:

   ```powershell
   .\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\interview.wav" -Model small -Language en
   ```

## Get a more accurate transcript

1. Choose a larger model: `large-v3`, or `turbo` for a faster large model.
2. Run:

   ```powershell
   .\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\interview.wav" -Model large-v3
   ```

   The first run downloads the model, which takes several minutes. Later runs use the cached copy.

## Run on an NVIDIA GPU

1. Check whether the environment can use the GPU:

   ```powershell
   .\01-Environment-Setup\04-verify-installation.ps1
   ```

2. Find the `CUDA available:` line.
   - `True`: go to step 3.
   - `False`: the installed PyTorch is CPU-only. Install a CUDA-enabled PyTorch build that matches
     `torch 2.8.0` into the environment first. This project's setup does not do that.
3. List the compute types your GPU supports:

   ```powershell
   & "$env:LOCALAPPDATA\WhisperX-Transcription\venv\Scripts\python.exe" -c "import ctranslate2; print(ctranslate2.get_supported_compute_types('cuda'))"
   ```

   If you changed `environment.venvPath`, use that path instead.
4. Run with `-Device cuda` and one of the listed compute types:

   ```powershell
   .\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\interview.wav" -Device cuda -ComputeType float16
   ```

## Make a choice the default

1. Add the values to `settings.local.json` in the repository root:

   ```json
   {
     "pipeline": { "model": "large-v3", "device": "cpu", "computeType": "int8" }
   }
   ```

2. Run the pipeline without those arguments.

## Related

- Reference: [`-Model`](../reference/run-pipeline.md#-model), [`-Device`](../reference/run-pipeline.md#-device), [`-ComputeType`](../reference/run-pipeline.md#-computetype)
- [Explanation: accuracy and speed trade-offs](../explanation/accuracy-and-speed-trade-offs.md)

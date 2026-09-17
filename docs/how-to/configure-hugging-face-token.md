# How to configure the Hugging Face token

Speaker diarization downloads a model from Hugging Face, which needs an access token.

## Create a token

1. Sign in at <https://huggingface.co>.
2. Open <https://huggingface.co/pyannote/speaker-diarization-community-1>. If the page asks you
   to accept conditions, accept them.
3. Open <https://huggingface.co/settings/tokens> and create a token with **Read** access.
4. Copy the token, which starts with `hf_`.

## Save it for your Windows user

1. Run setup with the token:

   ```powershell
   .\01-Environment-Setup\setup.ps1 -HFToken "hf_..."
   ```

   Or run `.\01-Environment-Setup\setup.ps1` without it, and paste the token when prompted.
2. Close and reopen PowerShell.
3. Check that the token is available, without printing it:

   ```powershell
   [bool]$env:HF_TOKEN
   ```

   The result must be `True`.

## Replace a saved token

1. Run:

   ```powershell
   .\01-Environment-Setup\setup.ps1 -HFToken "hf_new..."
   ```

2. Close and reopen PowerShell.

Running `setup.ps1` without `-HFToken` does not replace an existing token.

## Use a token for one run only

1. Pass it to the pipeline:

   ```powershell
   .\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\interview.wav" -HFToken "hf_..."
   ```

   The token stays in `$env:HF_TOKEN` until the PowerShell window is closed.

Or run the pipeline with no token configured, and paste the token when prompted. A prompted
token is removed when the run ends.

## Remove a saved token

1. Run:

   ```powershell
   [Environment]::SetEnvironmentVariable("HF_TOKEN", $null, "User")
   ```

2. Close and reopen PowerShell.

Never put the token in `settings.json`, `settings.local.json`, a script, or a commit.

## Related

- [Reference: `HF_TOKEN`](../reference/environment-variables.md#hf_token)
- [Reference: `setup.ps1 -HFToken`](../reference/setup-scripts.md#-hftoken)

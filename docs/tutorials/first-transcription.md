# Tutorial: your first transcript

In this tutorial you will set up the project on a Windows computer and produce a
speaker-labeled transcript of a short sample recording that ships with the repository.

You will:

1. check that you have what you need;
2. set up the environment, once per computer;
3. transcribe the sample;
4. read the result, and learn what each file is for.

It takes about 15 minutes of your attention. The setup step and the first transcription each
spend several minutes downloading and computing, so plan for around an hour in total on a
laptop without a graphics card.

You don't need to know Python. You will type commands into PowerShell, and this tutorial shows
you every one of them.

## What you need

- Windows 10 or 11.
- The repository, cloned or downloaded to a folder on your computer.
- **Python 3.10 or newer.** Type `python --version` in PowerShell. If you see a version number
  such as `Python 3.12.4`, you have it. If not, install Python from <https://www.python.org/downloads/>
  and select **Add python.exe to PATH** during installation.
- About 5 GB of free disk space: roughly 2 GB for the Python packages and 2 GB for the downloaded models.
- An internet connection.
- A free Hugging Face account. You will create an access token in step 2.

## Step 1: open PowerShell in the project folder

1. Open the project folder in File Explorer.
2. Click the address bar, type `powershell`, and press Enter.

A blue window opens, showing your project path. Every command in this tutorial is typed here.

Check that you are in the right place:

```powershell
dir
```

You should see `settings.json`, `README.md`, and the folders `01-Environment-Setup` and
`02-Transcription-Pipeline`.

## Step 2: get a Hugging Face token

The speaker-detection model is downloaded from Hugging Face, which requires a free account and
an access token.

1. Go to <https://huggingface.co/join> and create an account, or sign in.
2. Open <https://huggingface.co/pyannote/speaker-diarization-community-1>. If the page shows a
   form asking you to accept the conditions, fill it in and accept. Without this, the model
   cannot be downloaded.
3. Open <https://huggingface.co/settings/tokens> and select **Create new token**.
4. Give it any name, choose the **Read** type, and create it.
5. Copy the token. It starts with `hf_`.

Keep the token in your clipboard for the next step. Treat it like a password.

## Step 3: set up the environment

Run:

```powershell
.\01-Environment-Setup\setup.ps1
```

If Windows refuses to run the script, allow local scripts for this window only, then run it again:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\01-Environment-Setup\setup.ps1
```

The script works through six steps and prints each one:

```text
[1/6] Checking Python...
[2/6] Checking FFmpeg...
[3/6] Creating virtual environment...
[4/6] Installing dependencies...
[5/6] Checking Hugging Face authentication...
[6/6] Verifying WhisperX...
```

Two steps need your attention:

- **Step 2** installs FFmpeg, which decodes audio, if you don't have it. Accept any Windows
  prompt that appears.
- **Step 5** asks for your Hugging Face token. Paste it and press Enter. Nothing appears as you
  paste, because the input is hidden. That is expected.

Step 4 takes the longest, because it installs about 2 GB of packages.

When it finishes you see:

```text
==============================================
 Environment setup completed successfully!
==============================================
```

You have now done everything that is needed once per computer. The Python environment is
installed outside the project folder, at `%LOCALAPPDATA%\WhisperX-Scribe\venv`.

## Step 4: transcribe the sample recording

The repository includes a 19-second recording of two speakers, for exactly this purpose.

Run the pipeline on it, and write the results into a new `my-first-transcript` folder:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 ".\tests\data\sample-2-speakers.wav" -Language en -MinSpeakers 2 -MaxSpeakers 2 -OutputDirectory ".\my-first-transcript"
```

Beyond the file name, you have told the pipeline two things: the recording is English, and it
has exactly two speakers.

The run prints a heading for each of its four stages:

```text
=== transcribe.py ===
=== align_and_merge.py ===
=== diarize.py ===
=== finalize.py ===
```

The first run downloads three models, roughly 1.8 GB in total, so it takes several minutes. Later
runs reuse them and are much faster.

You are finished when you see:

```text
=== Pipeline complete ===
```

If the run stops with an error instead, go to [When something goes wrong](#when-something-goes-wrong).

## Step 5: read your transcript

Open the transcript:

```powershell
notepad .\my-first-transcript\sample-2-speakers_final.txt
```

You will see something close to this:

```text
[00:00:00 - 00:00:08] SPEAKER_00
Hello, this is a short test of the WhisperX transcription pipeline. We are checking
transcription, alignment, and speaker diarization.

[00:00:09 - 00:00:18] SPEAKER_01
Great. The sample contains two speakers, clear pauses, and ordinary English sentences.
This should make the pipeline easy to verify.
```

Each block is one speaker turn: the time it starts and ends, a speaker label, and what was
said. `SPEAKER_00` and `SPEAKER_01` are the two voices. The model does not know anyone's name,
so it numbers the speakers in the order it hears them.

Your wording may differ slightly from the example. Speech recognition is a prediction, not a
lookup, and a small model on a short sample makes occasional mistakes.

## Step 6: look at what else was produced

List the folder:

```powershell
dir .\my-first-transcript
```

There are four files, one per stage:

| File | What it holds |
|---|---|
| `sample-2-speakers_raw.json` | The text, in rough chunks, with a start and end time each |
| `sample-2-speakers_aligned.json` | The same text with a start and end time for **every word** |
| `sample-2-speakers_diarized.json` | The aligned words, each labeled with a speaker |
| `sample-2-speakers_final.txt` | The readable transcript you just opened |

Each stage reads the file before it and writes the next one. The intermediate files are kept
on purpose: when a transcript looks wrong, they show you which stage caused it.

Have a look inside one:

```powershell
notepad .\my-first-transcript\sample-2-speakers_aligned.json
```

Every word has a `start`, an `end` and a `score`, which is how confident the alignment is.

## Step 7: transcribe your own recording

Use any recording you have, such as a `.wav`, `.mp3` or `.m4a` file:

```powershell
.\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Users\you\Music\meeting.m4a" -Language en
```

This time the output files are written next to your recording, because you didn't pass
`-OutputDirectory`. Leave out `-MinSpeakers` and `-MaxSpeakers` when you don't know how many
people are speaking, and the model will work it out.

On a computer without a graphics card, expect roughly the length of the recording again in
processing time, sometimes more.

## Clean up

The practice transcript can be deleted:

```powershell
Remove-Item -LiteralPath ".\my-first-transcript" -Recurse
```

Keep the environment. It is what makes every later run quick to start.

## When something goes wrong

| Message | What to do |
|---|---|
| `running scripts is disabled on this system` | Run the `Set-ExecutionPolicy` command from step 3, in this window, then try again |
| `Python was not found` | Install Python, tick **Add python.exe to PATH**, then open a new PowerShell window |
| `WhisperX environment was not found` | Step 3 did not finish. Run `.\01-Environment-Setup\setup.ps1` again. |
| Anything about `401`, `403` or gated access during the `diarize.py` stage | Accept the model conditions in step 2, check that your token has read access, then run `.\01-Environment-Setup\setup.ps1 -HFToken "hf_..."` |
| `No default align-model for language` | The language you passed has no alignment model. Check the supported codes in [the reference](../reference/run-pipeline.md#-language). |

## What next

- Change how a run works: the [how-to guides](../how-to/) cover language, model, speed, speakers
  and output location.
- Look up an option: [the reference](../reference/).
- Understand why the pipeline is built this way: [the explanations](../explanation/).

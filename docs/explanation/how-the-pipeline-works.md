# How the pipeline works

## Four models, not one

Turning a recording into a speaker-labeled transcript is not one task. It is four, and each
needs a different model:

1. **What was said.** Whisper converts speech into text. It works on chunks of audio and gives
   each chunk a rough start and end time. Whisper's timings come from the same prediction that
   produces the text, so they drift: a chunk boundary is close to the truth, but not exact.
2. **When each word was said.** A wav2vec2 model already knows the words, because stage 1 found
   them. Its job is to line them up with the audio signal, which gives a start and end time per
   word rather than per chunk.
3. **Who said it.** A pyannote model listens for changes of voice and splits the recording into
   speaker segments. It works purely on voice characteristics and never sees the text.
4. **A readable result.** The words now carry both timings and speaker labels, which is enough
   to group them into turns without a model at all.

The order matters. Alignment needs the text. Speaker assignment needs word timings, because a
speaker change often falls inside a Whisper chunk. Running them in this order is what makes the
final transcript both correctly worded and correctly attributed.

## Files as the interface

Each stage is a separate program, run one after another, that reads files and writes files:

```text
audio.wav ──▶ transcribe.py ──▶ _raw.json ──▶ align_and_merge.py ──▶ _aligned.json
                                                                          │
              _final.txt ◀── finalize.py ◀── _diarized.json ◀── diarize.py ┘
```

The scripts never import each other. A stage's output schema is the next stage's input
contract, and nothing else is shared.

This costs something. Each of the first three stages loads the audio from disk again, and each
starts a new Python process, which means loading PyTorch again. One long-running process would
avoid that.

What it buys is worth more here:

- **The intermediate files are a debugging surface.** When a transcript names the wrong speaker,
  you can look at `_aligned.json` and `_diarized.json` and see whether the words were timed
  wrongly or attributed wrongly. In a single process, that state would exist only in memory.
- **A stage can be re-run on its own.** Diarization is the stage most often re-run with
  different speaker counts, and it doesn't need transcription repeating.
- **Failures are isolated.** A crash in one model's dependencies cannot take down the others,
  and the work already done stays on disk.
- **Each stage stays readable.** A stage is one file with one job, and none of them needs to
  know how the others work.

For a pipeline measured in minutes, a few seconds of reloading per stage is a good trade.

## One orchestrator

`run_pipeline.ps1` is the only piece that knows the pipeline exists as a whole. It resolves the
settings, derives all four file names from the audio file stem, resolves the Hugging Face token
before the slow stages start, and runs each stage in turn, stopping at the first non-zero exit
code.

The stage scripts stay unaware of all of this. They read no settings files, and each has its
own `argparse` defaults, so they can be run by hand for debugging exactly as the orchestrator
runs them.

Resolving the token first is a deliberate ordering choice: diarization is the only stage that
needs it, but it is the third stage. Discovering a missing token after several minutes of
transcription would waste the work.

## Where the language is decided

Stage 1 either uses the language you supply or detects one from the first 30 seconds, and it
writes that language into `_raw.json`. Stage 2 reads it back and loads the matching alignment
model. Nothing else carries the language between stages, which is why `_raw.json` is the only
file with a `language` key and why stage 2 fails without it.

This is also why a language choice that Whisper supports can still fail later. WhisperX ships
default alignment models for 41 of Whisper's 100 languages. Whisper will happily transcribe the
other 59, and stage 2 then has nothing to align with.

## Related

- [Reference: pipeline stage scripts](../reference/pipeline-stage-scripts.md)
- [Reference: output files](../reference/output-files.md)
- [Explanation: accuracy and speed trade-offs](accuracy-and-speed-trade-offs.md)

# Accuracy and speed trade-offs

Four choices change how long a run takes and how good the result is: the model, the device, the
compute type, and whether you supply the language. They are not equally important, and the
order above is roughly the order of their effect.

## Model size dominates

Whisper comes in sizes from `tiny` to `large-v3`. Larger models have more parameters, so they
make fewer transcription errors, and every second of audio costs more computation. This is the
choice that matters most, in both directions.

The defaults in this project settle on `medium` because it is the size that is usually good
enough on a CPU without being painful to wait for. There is nothing special about it beyond that.

Two variants are worth knowing:

- **`.en` models** are trained on English only. For English audio they are usually more accurate
  than the multilingual model of the same size, and they cannot do anything else.
- **`turbo` and the `distil-*` models** are distilled or pruned versions of large models. They aim
  to keep most of the accuracy of a large model at a fraction of the cost. They are a reasonable
  answer when `medium` is not accurate enough and `large-v3` is too slow.

Whichever you choose, the model is downloaded once and cached, so the first run with a new model
is much slower than every later one.

## Device changes the scale, not the settings

A GPU does not transcribe better than a CPU. It transcribes the same thing far faster, because
these models are mostly large matrix multiplications, which is what a GPU exists to do.

That makes `-Device cuda` the one change that can move a run from tens of minutes to a few, and
it is also the one this project cannot arrange for you: it needs a CUDA-enabled PyTorch build,
which the setup does not install. The environment it builds is CPU-only by design, because CPU
is the baseline that works on every Windows machine.

Only transcription and alignment benefit substantially. Diarization on a short recording is a
small part of the total either way.

## Compute type trades precision for speed

A compute type says how numbers are stored during inference. `float32` keeps full precision.
`int8` quantizes weights to 8-bit integers, which makes the model smaller in memory and faster
to run, at the cost of a small, usually unnoticeable, loss of accuracy.

The default is `int8` because on CPU it is a clear win: it is the difference between a run you
wait for and a run you abandon. `float32` is the option to try when you suspect quantization is
costing you accuracy on difficult audio, and `int8_float32` sits between them.

Precision also costs memory, not just time. A `float32` model needs several times the RAM of the
same model at `int8`, and on a machine without that much free memory the run fails while loading
the model rather than running slowly.

On a GPU the useful types are different, and which ones exist depends on the card. The
supported list is what CTranslate2 reports for the device, not a fixed set.

## Language detection is cheap; the wrong language is not

With no language given, Whisper runs one encoder pass over the first 30 seconds and picks the
most likely language. That is a single pass over half a minute of audio, against a transcription
pass over the whole recording, so as a share of the run it is small. Supplying `-Language` saves
seconds, not minutes.

The real reason to supply it is correctness. Detection reports a probability, and on a short,
noisy or accented opening it can be low, for example `Detected language: en (0.35)`. A
misidentified language does not produce a slightly worse transcript, it produces a wrong one,
and it also selects the wrong alignment model for stage 2. When you know what language the
recording is in, saying so removes a failure mode rather than an expense.

## Speaker hints

`-MinSpeakers` and `-MaxSpeakers` do not make diarization faster. They constrain the clustering,
which is a correctness aid: when you know a recording is an interview with two people, fixing
both bounds to 2 stops the model from splitting one voice into two speakers or merging two into
one. When you don't know, leave them out, because a wrong constraint is worse than none.

## A practical order

1. Set the language if you know it. It costs nothing and removes a failure mode.
2. Set the speaker count if you know it. Same reasoning.
3. Pick the smallest model that gives you an acceptable transcript, and test it on a few minutes
   of typical audio rather than the whole recording.
4. Change the compute type only if accuracy looks quantization-limited.
5. If runs are still too slow, the answer is a GPU, not more tuning.

## Related

- Reference: [`-Model`](../reference/run-pipeline.md#-model), [`-Device`](../reference/run-pipeline.md#-device), [`-ComputeType`](../reference/run-pipeline.md#-computetype), [`-Language`](../reference/run-pipeline.md#-language)
- [How-to: choose the model, device and compute type](../how-to/choose-model-and-speed.md)

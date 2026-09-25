# Design Doc: scribe-works — On-Demand Cloud GPU Transcription

| | |
|---|---|
| **Document type** | Design doc / project brief — **not** an implementation plan. It exists to brief a brand-new, not-yet-created repository's first working session: background, requirements, alternatives considered, proposed architecture, and — deliberately — a set of unresolved open questions. The first job of that session is to work through §5 with the operator; only after that should an actual implementation plan (in that repo's own `docs/plans/`, following whatever convention it adopts) be written. |
| **Status** | Draft. Captures a design conversation; no code exists yet; open questions in §5 are unresolved. |
| **Date** | 2026-09-20 |
| **Project name** | `scribe-works` — decided, see §5 item 10 |
| **Scope** | A **new, separate project (`scribe-works`)** — an asynchronous job/worker service that runs the existing WhisperX pipeline on rented cloud GPUs, plus a thin client/API layer to submit jobs and collect results. The backend and system architecture are designed here; the **client is scoped but deliberately not designed** — see §4.7. |
| **Explicitly out of scope** | This repository (`whisperx-scribe`) itself. Its PowerShell orchestration, Python scripts, and local-machine workflow are not modified by this document and continue to work exactly as they do today. This document is stored here for now, directly under `docs/` rather than `docs/plans/`, since it is not a plan by this repo's own convention — purely as a handoff artifact until it's copied into the new repository. This repo's Diátaxis docs convention (tutorial/how-to/explanation/reference under `docs/`) doesn't quite fit it either; treat its location as a pragmatic exception, not a new category. |

This document is self-contained: it records the requirements as they were established, the
research questions raised during design and the answers reached, the proposed architecture and
its rationale, and — as its main deliverable — the open questions that still need a decision
before real implementation planning can start. A future session with no memory of the
conversation that produced this document should be able to read it top to bottom and pick up the
open questions in §5 as its starting agenda, not treat §6's implementation sequence as ready to
execute.

---

## Contents

0. [Summary and how to use this document](#summary-and-how-to-use-this-document)
1. [Background and origin](#1-background-and-origin)
2. [Requirements](#2-requirements)
   - [2.1 Functional](#21-functional-requirements) 
   -  [2.2 Non-functional](#22-non-functional-requirements)
   -  [2.3 Non-goals](#23-explicit-non-goals-considered-and-rejected-during-design)
3. [Research questions and findings](#3-research-questions-and-findings)
   - [3.1 C# interop](#31-can-the-whisperx-core-be-called-from-c-without-rewriting-it) 
   -  [3.2 Managed APIs](#32-is-a-managed-transcription-api-eg-azures-whisper-endpoint-a-viable-substitute-for-self-hosting)
   -  [3.3 Track A vs. B](#33-serverless-gpu-platform-track-a-vs-self-built-awsazure-track-b) 
   -  [3.4 Cost and performance](#34-cost-and-performance-estimate--1-hour-of-audio-best-quality-settings)
4. [Architecture decision](#4-architecture-decision)
   - [4.1 Worker](#41-worker-containerize-the-pipeline-as-is) 
   - [4.2 Queue and API](#42-job-queue--async-api) 
   - [4.3 Compute tier](#43-compute-tier)
   - [4.4 Weight caching](#44-model-weight-caching) 
   - [4.5 Storage](#45-storage)
   - [4.6 Secrets](#46-secrets)
   - [4.7 Client scope](#47-frontend-client-scope)
5. [Open questions](#5-open-questions)
6. [Possible implementation sequence](#6-possible-implementation-sequence)
7. [Validation criteria](#7-validation-criteria)
8. [References](#8-references)
9. [Appendix A: Kickoff checklist](#appendix-a-kickoff-checklist) — 
   - A. [Create repo](#a-create-the-github-repository) 
   - B. [Clone](#b-clone-it-locally) 
   - C. [Copy doc](#c-copy-this-design-doc-in-and-commit) 
   - D. [Vendoring](#d-should-the-new-project-copy-code-from-whisperx-scribe-or-start-from-scratch-answered) 
   - E. [Granularity](#e-task-and-session-granularity--not-one-branch-not-one-session) - F. [Workflow](#f-the-agentic-coding-workflow-refined) 
   - G. [Start Claude Code](#g-start-claude-code)

---

## Summary and how to use this document

This is a reference to come back to, not something to read once. Read this section first; jump to
the rest through the contents above or the lookup table below.

**What it is.** The brief for `scribe-works`, a new private project that runs the WhisperX
pipeline from `whisperx-scribe` on rented cloud GPUs. You submit a job (audio plus settings)
through a thin client, it runs on an autoscaled GPU worker that scales to zero when idle, and you
collect the transcript later. Target: 1 hour of audio in 30–60 minutes for about $0.20–$0.40.

**Where things stand.** Design only; no code exists. Last revised 2026-09-25.

| | Decided | Not decided |
|---|---|---|
| Shape | Async job queue in front of autoscaled GPU workers running the existing pipeline unmodified (§4) | Cloud (AWS/Azure), orchestration service, queue technology (§5 items 1–3) |
| Compute | T4-class baseline, A10G as the faster tier (§4.3) | Spot vs. on-demand policy and spot-reclaim handling (§5 item 6) |
| Project | Name `scribe-works`; private repo; copy only the four pipeline scripts (Appendix A) | API framework and language (§5 item 4) |
| Client | Scope and boundaries (§4.7) | Technology, UI design, auth mechanism (§5 items 7–9); the client design doc itself |
| Model | Best-quality target is a large Whisper model | Exact identifier, `large-v2` vs. `large-v3` (§5 item 11) |

**Where to look when a question comes up.**

| If you are wondering… | Go to |
|---|---|
| Why not rewrite it in C#, or use Azure's Whisper API? | §1, §3.1, §3.2 |
| Why AWS/Azure and not RunPod or Modal? | §3.3 |
| What will it cost, and how long will a job take? | §3.4, NFR3, NFR4 |
| What must the system do, and what must it never become? | §2 (especially NFR2, NFR7, NFR8, §2.3) |
| What is still undecided? | §5 |
| What should I build first? | §6 (provisional), then Appendix A §E–F |
| How do I know it works? | §7 |
| What does the client have to do, and when do I design it? | §4.7 |
| How do I start the new repo and the first session? | Appendix A |
| What does the local `whisperx-scribe` tool do, and what is copied from it? | §1, §8, Appendix A §D |

**Keeping this document honest.** When an open question in §5 gets decided, mark it resolved in
place (as item 10 is) and update the "Decided" column above. Once the new repo exists, this
document is copied into it and that copy is the live one; this repository's copy becomes a
historical handoff artifact.

---

## 1. Background and origin

`whisperx-scribe` (this repository) is a Windows/PowerShell tool that turns an audio file into a
time-aligned, speaker-labeled transcript using WhisperX, run entirely on one local machine. Its
architecture is documented in this repo's `CLAUDE.md` and `docs/reference/pipeline-stage-scripts.md`:
four standalone Python CLIs, each reading input from disk and writing output to disk, invoked in
sequence by `run_pipeline.ps1`:

```
audio.wav → transcribe.py      → <stem>_raw.json       (Whisper transcription, faster-whisper)
          → align_and_merge.py → <stem>_aligned.json   (word-level timing, wav2vec2 forced alignment)
          → diarize.py         → <stem>_diarized.json  (speaker labels, pyannote/speaker-diarization-community-1)
          → finalize.py        → <stem>_final.txt      (human-readable speaker turns)
```

This document originated from a single question — *"is it feasible to convert this to C#/.NET?"* —
and narrowed through several rounds of design conversation into a concrete, much smaller target.
The reasoning chain, in order:

1. **Full .NET/C# rewrite of the ML core was evaluated and rejected.** Whisper transcription,
   wav2vec2 forced alignment, and pyannote diarization are Python/PyTorch-native. No mature .NET
   equivalent reproduces WhisperX's forced-alignment step or pyannote's segmentation → embedding →
   clustering diarization pipeline; matching them would mean re-deriving both pipelines from
   scratch in C#, a multi-week research-grade effort for uncertain accuracy parity. Only the
   orchestration layer (settings, invocation, file-passing) would port cleanly, and that has no
   independent value.
2. **A hybrid was proposed instead:** keep the Python pipeline exactly as-is, and call it from a
   C# client. Three interop mechanisms were compared — subprocess exec (what `run_pipeline.ps1`
   already does), a resident local HTTP microservice, and in-process embedding via Python.NET.
   Python.NET was rejected (GIL, packaging a full PyTorch runtime inside a .NET process, fights
   the pipeline's intentional process-isolation design for no real gain over the other two
   options). The HTTP microservice pattern was preferred because it generalizes cleanly to a
   networked/cloud deployment.
3. **The intended client was reconsidered.** A desktop GUI against the *local* pipeline was
   explicitly ruled out — the existing PowerShell pipeline already serves that need adequately;
   building a GUI for it has no independent value.
4. **The real motivating use case was identified:** the local machine cannot run the largest
   models, or takes too long, for occasional heavier jobs. The actual want is on-demand access to
   a bigger/faster GPU than the local machine has, without paying for standing infrastructure.
5. **Managed transcription APIs (e.g. Azure's Whisper endpoint) were evaluated as an alternative
   to self-hosting** and found not to be a substitute: they provide transcription only, not
   WhisperX's forced alignment or pyannote-equivalent diarization with tunable min/max speaker
   counts, and the audio would leave the user's control to a third party. Self-hosting the
   existing pipeline was kept.
6. **Two implementation tracks for "rent a GPU on demand" were compared:**
   - **Track A — serverless GPU job platforms** (RunPod Serverless, Modal, Beam): built-in queue,
     autoscaling, and submit/status API; near-zero ops, but platform lock-in and less
     infrastructure control.
   - **Track B — self-built on a general cloud** (AWS or Azure): full control over compute,
     queueing, spot pricing, and storage, at the cost of building and operating the queue,
     autoscaler, and API layer yourself.

   **Track B was chosen**, specifically because the intended operator already has working
   professional experience on both AWS and Azure and explicitly accepted the additional setup
   effort in exchange for the control and familiarity — the usual argument for Track A (avoiding
   an ops learning curve) doesn't apply here.
7. **The requirement was refined into its final shape:** no need to build against the local
   pipeline at all; the goal is a deployable worker that runs on rented GPU compute, reachable
   through some UI (web or otherwise), where a job can be submitted asynchronously, its progress
   checked, its result collected later, and multiple jobs can run in parallel — a standard
   **async job queue on autoscaled GPU workers** pattern.
8. **A cost/performance estimate was produced** for the concrete target case (1 hour of audio,
   best-quality settings, 30–60 minutes of processing time considered acceptable) and confirmed
   acceptable. See §3.4.

---

## 2. Requirements

### 2.1 Functional requirements

| # | Requirement |
|---|---|
| FR1 | The worker must reproduce the existing WhisperX pipeline's behavior and output exactly — same four stages, same output schema — packaged to run unattended on a rented GPU instance. No changes to the scripts' internal alignment or diarization logic, and no new model options beyond what `transcribe.py --model` etc. already accept. This does not conflict with FR7: which already-supported model a given job uses is still a per-job setting, not fixed by the worker. |
| FR2 | A client (web UI or otherwise) can submit a transcription job asynchronously: upload/reference an audio file and receive a job identifier immediately, without blocking on completion. |
| FR3 | A client can query job status/progress after submission (queued, running — ideally per-stage progress — completed, failed). |
| FR4 | A client can retrieve the job's result artifacts after completion, at any later time (submission and collection are decoupled in time). |
| FR5 | Multiple jobs can run concurrently/in parallel rather than being serialized through a single worker. |
| FR6 | The operator can trade cost against turnaround time per job or globally (e.g. choice of GPU tier, or worker concurrency), matching the "how much do I want to spend for how fast a result" requirement. |
| FR7 | "Best quality" settings — the largest available Whisper model (`large-v2`/`large-v3`; exact identifier is an implementation choice, not pinned here), full forced alignment, full diarization — must be supported as the primary target configuration, while remaining able to run cheaper/faster configurations (e.g. this repository's own default is `medium`) — mirroring this repository's existing `settings.json` layering philosophy (defaults → committed config → local override → explicit argument), even though this is a separate codebase. |

### 2.2 Non-functional requirements

| # | Requirement |
|---|---|
| NFR1 | No standing GPU cost while idle. Compute must scale to zero between jobs (occasional/personal usage pattern, not a continuously-loaded service). |
| NFR2 | This is a single-operator tool, not a multi-tenant product. There is no business justification for product-grade multi-tenancy, self-service auth, or business-scale operational concerns — do not build for them. |
| NFR3 | Processing latency target: a 1-hour audio file at best-quality settings should complete in 30–60 minutes. This is an accepted, not a stretch, target — it directly informed the GPU tier choice in §3.4 (a mid-tier GPU comfortably meets it; nothing pricier is required to hit the latency bar). |
| NFR4 | Cost target: **$0.20–$0.40 per 1-hour-audio job** at best-quality settings, confirmed acceptable. This is a budget check against instance/architecture choices, not a hard ceiling to further optimize past. |
| NFR5 | Secrets (`HF_TOKEN` — required for the gated `pyannote/speaker-diarization-community-1` model) must never be embedded in a container image or supplied by a client. It is a platform-managed secret injected into the worker at runtime, exactly as `diarize.py`'s existing resolution order (`--hf-token` → `HF_TOKEN` env var → interactive prompt) already expects via the environment-variable path. |
| NFR6 | Built on AWS and/or Azure, accepting the associated setup and operational learning curve, in preference to a managed serverless-GPU platform (Track A was evaluated and explicitly not chosen — see §3.3). |
| NFR7 | The submit/status API must not be callable by an unauthenticated stranger who happens to find its URL — a single shared credential (e.g. an API key) is sufficient given NFR2's single-operator scope. This is distinct from NFR2: NFR2 rules out building *multi-user, self-service* auth (signup, roles, per-user accounts); it does not mean *no* auth. Without at least a shared key, an exposed endpoint is a way for a stranger to run arbitrary GPU-billed jobs on the operator's account. Concrete mechanism is an open decision — see §5 item 9. |
| NFR8 | The autoscaler enforces a configurable maximum concurrent-worker cap. FR5 wants parallel jobs, but "scales to meet demand" (NFR1) with no ceiling turns any bug, accidental bulk upload, or (absent NFR7 being implemented correctly) unauthorized use into effectively unbounded GPU spend. A cap is a cheap safeguard against exactly the cost risk the rest of this document otherwise takes seriously (NFR4). |

### 2.3 Explicit non-goals (considered and rejected during design)

- A full C#/.NET reimplementation of the transcription/alignment/diarization models (§1, item 1).
- A desktop GUI running the pipeline against the local machine (§1, item 3) — the existing
  PowerShell pipeline in this repository already covers that case.
- A always-on resident local service with idle-shutdown for a single desktop client — evaluated
  and found to add API/lifecycle machinery without solving the actual problem (the actual problem
  is insufficient *local* GPU power, not local process-lifecycle management).
- A multi-tenant, business-justified SaaS product — no business case exists; NFR2 makes this
  explicit so the design doesn't drift toward it.
- In-process Python embedding via Python.NET — rejected as added fragility (GIL, bundling a full
  PyTorch runtime inside a host process) for no benefit over subprocess/HTTP interop.
- A managed transcription API (e.g. Azure's Whisper endpoint) as a substitute for self-hosting —
  evaluated and rejected: not feature-equivalent (no matching forced alignment or
  pyannote-parity, tunable diarization) and sends audio to a third party.

---

## 3. Research questions and findings

This section preserves the research conducted during design, since the answers directly justify
the architectural decision in §4.

### 3.1 Can the WhisperX core be called from C# without rewriting it?

Three interop mechanisms were compared:

| Mechanism | Verdict |
|---|---|
| Subprocess exec of the existing Python CLIs (same approach `run_pipeline.ps1` already uses) | Works with zero changes to the Python side; simplest; consistent with this pipeline's existing intentional per-stage process isolation. Good default for a purely local client. |
| Resident local HTTP microservice wrapping whisperx (e.g. FastAPI), called via `HttpClient` | Avoids reload cost across repeated runs; natural fit once progress/streaming and network-based clients matter. **This is the pattern that generalizes to a cloud deployment**, which is why it was carried forward. |
| Python.NET (pythonnet), embedding CPython directly inside the .NET process | Rejected: GIL contention, must bundle/match a full PyTorch runtime inside the host process, fragile cross-language debugging — real added complexity for a benefit (marginally lower latency) that doesn't matter here. |

### 3.2 Is a managed transcription API (e.g. Azure's Whisper endpoint) a viable substitute for self-hosting?

No. Azure OpenAI's Whisper endpoint provides transcription only — no word-level forced alignment
and no diarization matching this pipeline's `pyannote/speaker-diarization-community-1` stage with
its tunable `--min-speakers`/`--max-speakers`. Azure AI Speech's separate diarization feature is a
different model and pipeline, not a pyannote-parity replacement, and would require composing two
separate Azure services to approximate current output. It would also send audio to a third party,
which may or may not be acceptable depending on content. Managed APIs remain a reasonable option
if a future need cares less about exact output parity and more about zero maintenance — noted here
for completeness, not adopted.

### 3.3 Serverless GPU platform (Track A) vs. self-built AWS/Azure (Track B)

| | Track A — RunPod Serverless / Modal / Beam | Track B — AWS or Azure, self-built |
|---|---|---|
| Queueing, autoscaling, submit/status API | Provided by the platform | Must be built (queue + orchestrator + API layer) |
| Operational burden | Near-zero | Real — IAM, networking, autoscaling policy, storage lifecycle |
| Infrastructure control | Limited to the platform's offerings | Full — region, instance type, spot policy, etc. |
| Fit for this operator | Would minimize a learning curve that isn't a cost here | Matches existing AWS/Azure working experience; learning curve explicitly accepted |

**Decision: Track B.** The usual argument for Track A — avoiding the ops learning curve of a
general cloud — does not apply, since the intended operator already works professionally with both
AWS and Azure. Track B was chosen for the additional control and the fact that its extra setup
cost is not really a cost here.

### 3.4 Cost and performance estimate — 1 hour of audio, best-quality settings

Reproduced from the design conversation, since it directly grounds NFR3/NFR4 and the compute-tier
decision in §4.

**Throughput assumptions.** WhisperX's own published benchmark is ~70x realtime for the
`large-v2` model on an A100 with batched inference; `large-v3` is the same parameter-count class
and assumed to perform comparably, though it hasn't been separately benchmarked here — worth a
quick sanity check once §5 item 11's exact model identifier is chosen. A T4 (the cheapest common
cloud GPU tier) is
roughly 8–10x weaker on tensor throughput, so transcription alone is estimated at ~8–12x realtime
on a T4. Diarization (pyannote's segmentation → embedding → clustering pipeline) is the pipeline's
slowest stage relative to audio length — it batches less efficiently than Whisper's inference and
was estimated at only ~2–6x realtime even on GPU. Forced alignment (wav2vec2) is comparatively
cheap.

**Estimated wall time for 1 hour of audio on a single T4:**

| Stage | Estimated time |
|---|---|
| Transcribe (large model) | ~5–8 min |
| Align (wav2vec2) | ~2–5 min |
| Diarize (pyannote) | ~10–30 min — dominant cost |
| Instance boot + model load | ~2–10 min, depending on whether model weights are cached (see §4.4) |
| **Total** | **~19–53 min** (sum of the rows above — the stages run sequentially, not in parallel) |

NFR3's 30–60 minute target functions as a ceiling, not a floor: finishing faster than 30 minutes
is not a problem, only finishing slower than 60 is. The ~19–53 min sum comfortably clears that
ceiling on a T4 without needing a pricier GPU tier, even at its slowest estimated case.

**Pricing (checked live during design, September 2026, us-east-1 / East US):**

| Instance | GPU | On-demand | Spot | Est. job duration | Est. cost/job |
|---|---|---|---|---|---|
| AWS `g4dn.xlarge` | NVIDIA T4, 16GB | $0.526/hr | ~$0.27–0.30/hr | ~45 min | $0.20 (spot) – $0.40 (on-demand) |
| Azure `NC4as_T4_v3` | NVIDIA T4, 16GB | $0.526/hr | similar range | ~45 min | ~$0.20–0.40 |
| AWS `g5.xlarge` | NVIDIA A10G, 24GB | $1.006/hr | ~$0.45–0.55/hr est. | ~15–20 min (2–3x faster) | ~$0.15–0.35 |

Because faster GPU tiers cost proportionally more per hour but finish proportionally sooner, cost
per job lands in roughly the same **$0.20–$0.40** range regardless of tier — the GPU choice mainly
trades turnaround time, not total cost, which is exactly the FR6 cost/speed control. Spot pricing
is the one lever that meaningfully lowers cost, at the risk of an interruption on a 20–45 minute
job. Storage (a few GB in S3/Blob), data transfer, and control-plane services (queue, small API)
are effectively free at this usage volume and were not separately budgeted.

**This estimate was confirmed acceptable** against NFR3/NFR4 during design and should be
re-validated against real measurements once the worker is built (see §6).

Sources consulted: [g4dn.xlarge — Vantage](https://instances.vantage.sh/aws/ec2/g4dn.xlarge),
[g4dn.xlarge spot/on-demand — DoiT Compute](https://compute.doit.com/spot/us-east-1/g4dn.xlarge),
[Standard_NC4as_T4_v3 — AzureSpeed](https://www.azurespeed.com/AzureVmPricing/Standard_NC4as_T4_v3),
[g5.xlarge — Vantage](https://instances.vantage.sh/aws/ec2/g5.xlarge). Cloud pricing changes over
time; treat these as directionally accurate, not current-as-implemented figures.

---

## 4. Architecture decision

**Shape: an async job queue in front of an autoscaled pool of GPU workers, each running the
existing WhisperX pipeline unmodified in a container, on AWS or Azure (Track B).**

### 4.1 Worker: containerize the pipeline as-is

The worker is a container image built around this repository's four pipeline scripts
(`transcribe.py`, `align_and_merge.py`, `diarize.py`, `finalize.py`), invoked in the same order
`run_pipeline.ps1` uses today, with no logic changes (FR1). This repository stays the source of
truth for pipeline behavior; per Appendix A §D, the new project vendors an unmodified copy of
these four scripts (not a live dependency, not a fork of their logic).

A useful detail confirmed while reviewing this repo's own documentation
(`docs/reference/pipeline-stage-scripts.md`): stages 1–3 already print structured progress lines
to stdout — `"<Stage>: NN% (elapsed <duration>, ETA <duration>)"`, with `diarize.py` additionally
tagging `[segmentation]`/`[embeddings]`. **The worker can parse these existing lines directly to
populate per-stage job progress (FR3) — no instrumentation of the Python scripts is needed.**

### 4.2 Job queue + async API

A small API layer accepts job submissions (audio reference + settings — at minimum the model,
language, min/max speakers, and GPU tier a job should use, mirroring the parameters
`run_pipeline.ps1` already exposes and the cost/speed control FR6 and FR7 require), enqueues work,
and answers status/result queries (FR2–FR4). Concrete service choice is an open decision (§5) between,
e.g., AWS (SQS + Batch/ECS+GPU, or Lambda/Fargate for the API) and Azure (Storage Queue or Service
Bus + Container Apps Jobs/Batch, Functions or a small App Service for the API). Both clouds cover
this pattern natively; the decision is which one (or whether to target both).

Every request this API accepts must be checked against the shared credential from NFR7 once the
API is reachable outside localhost — mechanism is an open decision, §5 item 9. The autoscaler
(§4.3) enforces NFR8's concurrent-worker cap regardless of how many jobs the queue holds.

### 4.3 Compute tier

Default to a **T4-class instance** (`g4dn.xlarge` / `NC4as_T4_v3`) as the baseline tier — it meets
the 30–60 minute target (NFR3) at the $0.20–0.40 target cost (NFR4) per §3.4. An A10G-class tier
(`g5.xlarge`) is offered as a faster, proportionally pricier option, giving FR6 (cost vs. speed) a
concrete, two-tier starting implementation that can be extended later.

### 4.4 Model weight caching

Whisper (large model, ~3GB), the wav2vec2 alignment model (~1GB), and the pyannote diarization
models (~1GB, gated behind `HF_TOKEN`) add up to several GB. Downloaded fresh from Hugging Face on
every cold start, this alone can consume 5–10+ minutes — a meaningful fraction of the latency
budget. **Bake these weights into the worker's container image or a persistent volume attached at
boot** (custom AMI, golden container image layer, or an EBS/Managed Disk snapshot with a
pre-warmed Hugging Face cache directory) so cold start only needs to load already-local weights.
The specific mechanism is an open decision (§5); the requirement to avoid a live weight download
on every job is not.

### 4.5 Storage

Job input audio and output artifacts (the four JSON/text files per job) live in object storage —
S3 or Azure Blob — so results remain retrievable independently of when the worker that produced
them is still running (FR4).

### 4.6 Secrets

`HF_TOKEN` is provisioned as a platform secret (AWS Secrets Manager / Azure Key Vault) and injected
into the worker's environment at runtime, landing on the existing `HF_TOKEN` env var resolution
path `diarize.py` already implements (NFR5). It is never baked into the image and never accepted
from a client request.

### 4.7 Frontend (client scope)

**Status: scoped, not designed.** This document fixes what the client must do and where its
boundaries are. It deliberately does not design it, because there is nothing yet to design it
against: the API contract (§4.2) does not exist, and §5 items 7–9 (frontend technology, UI design,
API authentication) are open. Designing screens before the contract is settled would be guesswork
that gets thrown away.

**What the client must do.** Three verbs, all against the async job API (FR2–FR4):

1. **Submit** — pick or upload an audio file, choose job settings (model, language, min/max
   speakers, GPU tier — see §4.2), receive a job identifier immediately.
2. **Track** — list jobs and show each one's state (queued, running with per-stage progress,
   completed, failed), by polling the status endpoint.
3. **Collect** — download the result artifacts of a completed job, at any later time, whether or
   not the browser session that submitted it still exists.

**What the client is not.**
- Not a way to run the pipeline locally — that stays in `whisperx-scribe` (§2.3).
- Not multi-user: no signup, roles or per-user accounts (NFR2). It holds or forwards the single
  shared credential from NFR7 and nothing more.
- Not the place for pipeline logic. The client only ever talks to the API; the API is what
  decouples desktop, web and mobile, so the technology choice stays independent of everything
  else in this document.
- Never given `HF_TOKEN` (NFR5). It never sees it.

**Likely first implementation.** A thin web UI covering the three verbs. Given the
poll-for-status nature of the requirement this is the natural starting point, but it is not a
commitment to any technology.

**When to write the client design doc.** After the submit/status/result API contract is concrete
(§6 step 6) and §5 items 7–9 are decided. Until then, do not start it.

**What the client design doc should contain** (so a future session does not have to rediscover
this list):
- The API contract as the client consumes it: endpoints, request/response shapes, job states,
  error and retry behaviour.
- Authentication handling on the client side (how the credential is stored and sent — §5 item 9).
- Screens and flows for the three verbs above: layout, empty/loading/failed states, how
  per-stage progress is shown.
- Large-file upload behaviour: direct-to-object-storage vs. through the API, resumability,
  size limits.
- Polling interval and what happens when the tab is closed and reopened.
- Hosting and delivery of the client itself (static site, desktop app, etc.).

**Where it lives.** In the `scribe-works` repository, as its own document under `docs/`, next to
this one. It is a design doc, not a plan, so it follows the same placement as this document; the
per-task implementation plans that come out of it go in that repo's `docs/plans/`.

---

## 5. Open questions

Resolve these first, in the new repo's kickoff session. Item 10 (repository name) is already
resolved; the rest are open. These were raised during design but intentionally left unresolved; they don't change the shape in
§4, only its concrete implementation. **This section is this document's actual handoff point** —
the new repo's first Claude Code session should work through it with the operator before §6 is
treated as actionable.

1. **AWS, Azure, or both?** Not chosen. The operator has working experience in both; pick one to
   start, informed by whichever has friendlier GPU spot availability/quota at implementation time.
2. **Orchestration service within the chosen cloud** — e.g. AWS Batch vs. ECS/Fargate+GPU vs. a
   self-managed Auto Scaling Group; Azure Container Apps Jobs vs. Azure Batch vs. AKS.
3. **Queue technology** — SQS vs. Service Bus vs. Storage Queue (or a simpler mechanism if the
   chosen orchestration service has queueing built in, e.g. AWS Batch's own job queue).
4. **Submit/status API implementation** — language/framework. Not decided; could reasonably be
   C#/.NET given the operator's stated interest in that ecosystem, or Python for closer proximity
   to the worker code. Either is compatible with this design's shape.
5. **Model weight caching mechanism** — custom AMI/golden image vs. a persistent attached volume
   vs. baking weights into a container image layer. Needs a concrete choice and a measurement of
   the resulting cold-start time against §3.4's estimate.
6. **Spot vs. on-demand policy** — whether to default to spot for cost, and how job
   retry/resumption works if a spot instance is reclaimed mid-job (a 20–45 minute job has
   non-trivial exposure to this).
7. **Frontend technology** — not decided; start minimal (§4.7) and let usage drive further
   investment.
8. **UI design** — no wireframe, layout, or interaction design exists yet beyond the three
   verbs named in §4.7 (upload, list-with-status, download). Not started; deliberately deferred
   until the API contract (§4.2, item 4 above) is concrete enough to design a UI against.
9. **API authentication mechanism (NFR7)** — not decided. The simplest option is a single static
   API key issued to the operator's own clients and checked on every request; a cloud-native
   option (AWS API Gateway API keys / IAM auth, Azure API Management subscription keys or Easy
   Auth) may be simpler still if the orchestration choice in item 2 already puts one of those in
   front of the API. Needs a decision before the API is exposed outside localhost.
10. **Repository — resolved: `scribe-works`.** This document currently lives in
    `whisperx-scribe/docs/` only because there's nowhere better for it yet; the implementation is
    a separate project and this document should be copied into that project's own repository once
    created. The name reads as a sibling of `whisperx-scribe` (the local tool this reuses), "works"
    in the sense of ironworks/waterworks — a facility that produces something — covers the whole
    system (queue, workers, API and client) rather than only the worker, and it doesn't bake in a
    specific cloud provider or orchestration choice that items 1–3 leave open. Considered and not
    chosen: `scribe-cloud`, `scribe-hub`, `whisperx-cloud-worker`. Run a quick GitHub name-collision
    search before creating the repository.
11. **Exact Whisper model identifier for "best quality"** — FR7 leaves this open between
    `large-v2` and `large-v3` (or a future equivalent); §3.4's performance estimate is benchmarked
    against `large-v2` and assumed, not verified, to hold for `large-v3`. Pin the exact
    `--model` value the worker's "best quality" job setting passes through, and re-check §3.4's
    estimate against it once real measurements are available (§6 step 4).

---

## 6. Possible implementation sequence

Provisional — depends on §5. Sketched here to show the shape holds together end to end, not as a ready-to-execute plan. Several
steps below name a §5 open question directly (e.g. step 5 needs items 1–3, step 3 needs item 5); a real implementation plan, written after §5 is resolved, should supersede this
section rather than extend it. Ordered so each phase produces something independently verifiable
before the next begins.

1. **New repository.** Create the separate `scribe-works` repository (§5 item 10, decided); do
   not implement inside `whisperx-scribe`.
2. **Containerize the pipeline (§4.1).** Build a Dockerfile that runs the four existing stages
   against a test audio file and reproduces this repository's own reference output
   (`tests/data/sample-2-speakers.wav` / `sample-2-speakers.expected.txt`) with no logic changes.
   This is the first validation gate — nothing later matters if this doesn't match.
3. **Model weight caching (§4.4).** Implement whichever mechanism is chosen in §5 item 5; measure
   cold-start time before vs. after to confirm it meaningfully undercuts the §3.4 estimate's
   "2–10 min, depending on caching" range.
4. **Single-worker cloud run.** Manually launch one instance of the container on the chosen cloud
   GPU tier against a real 1-hour audio file; measure actual wall time and actual cost, and compare
   both against the §3.4 estimate (30–60 min, $0.20–0.40).
5. **Queue + autoscaling (§4.2, §4.3).** Wire up the chosen orchestration service so jobs are
   enqueued and workers scale from zero on demand, including the GPU-tier selection from §4.3 as a
   per-job parameter (FR6) and the concurrent-worker cap (NFR8).
6. **Submit/status/result API (§4.2, §4.5).** Build the thin API: submit a job, poll status
   (parsing the existing stage progress lines per §4.1), retrieve results from object storage.
7. **Secrets wiring (§4.6).** Confirm `HF_TOKEN` reaches the worker via the platform secret
   manager and never appears in the image or logs.
8. **Minimal web UI (§4.7).** Upload, job list with status, download when ready.
9. **Parallel-job validation.** Submit two or more jobs concurrently and confirm they run in
   parallel rather than queuing behind a single worker (FR5), and that idle periods between jobs
   show no standing GPU cost (NFR1).

---

## 7. Validation criteria

The design is realized when all of the following hold, measured against real usage rather than
the estimates in §3.4:

1. The containerized worker's output for a known test file matches this repository's own
   pipeline output for the same file (same four-stage schema; diarization/alignment content
   equivalent given identical model versions and settings).
2. A 1-hour audio job at best-quality settings completes within 30–60 minutes end-to-end
   (queue → worker boot → four stages → result available), matching NFR3.
3. The same job's total cloud cost falls within $0.20–$0.40, matching NFR4. If it doesn't,
   re-examine the model-caching mechanism (§4.4) and spot-vs-on-demand policy (§5 item 6) first —
   those are the two levers §3.4 identified as having the largest effect.
4. No GPU compute cost is incurred while no job is running (NFR1) — confirm via the cloud
   provider's billing/cost-explorer for an idle period.
5. Two or more jobs submitted close together run concurrently, not serially (FR5).
6. A job's result remains retrievable after its worker instance has terminated (FR4).
7. `HF_TOKEN` is verified absent from the built container image (image layer inspection) and
   absent from worker logs (NFR5).
8. Submitting more jobs than the configured concurrent-worker cap queues the excess rather than
   scaling past it (NFR8).

---

## 8. References

- This repository's pipeline architecture and stage contracts: `CLAUDE.md` (§Architecture),
  `docs/reference/pipeline-stage-scripts.md`, `docs/reference/output-files.md`.
- This repository's configuration-layering pattern, referenced in FR7 as a model to follow:
  `docs/explanation/configuration-layering.md`, `settings.json`, `settings.ps1`.
- The source project: `whisperx-scribe`, https://github.com/gkibria-dev/whisperx-scribe. The four
  pipeline scripts and the two dependency pins referenced in Appendix A §D were taken from commit
  `30484db8c5e1160e9da22388e3bb990780882171` (2026-09-20, `main`). Record that SHA in the new repo
  when vendoring; it is what makes a future "did the source change?" check possible.
- Cloud pricing sources checked during §3.4's estimate: see the links at the end of that section.

---

## Appendix A: Kickoff checklist

Concrete steps to get from this document to a working repository with its first session running.
Steps A–C are one-time setup the operator does outside any agentic session. Step D is a decision
this document did not previously make explicitly. Step E addresses task and session granularity —
this is a multi-week project, not a single sitting. Step F defines the working loop applied to
each task from E. Step G is how the very first session actually begins.

### A. Create the GitHub repository

1. Create a new **private** repository — matches this being a single-operator tool (NFR2), and
   there's no reason to expose infrastructure/cost-control code publicly.
2. Name: `scribe-works` (decided, §5 item 10).
3. Description (as used): *"Scribe Works: on-demand cloud-GPU transcription for WhisperX. Async job
   queue, autoscaled workers, tunable cost and speed."*
4. Default branch: `main`.
5. `.gitignore` / license: skip both for now. A `.gitignore` template only makes sense once the
   language/framework choices in §5 (items 2–4, 7) are made — adding one prematurely risks
   guessing wrong. A `LICENSE` is optional on a private repo and only matters if it's ever made
   public; add one later if that changes.
6. Branch protection on `main` (require PRs before merge) is optional but worth turning on if the
   workflow in §F below is going to be followed for real — it makes "draft PR per unit of work"
   the actual mechanism rather than a convention that's easy to skip under a solo workflow.

### B. Clone it locally

Standard `git clone` to wherever repos live locally — a sibling of this repository (e.g. next to
`whisperx-scribe`) keeps the two easy to reference from each other during the vendoring step below.

### C. Copy this design doc in and commit

1. Copy this file into the new repo as `docs/scribe-works-design-doc.md` — directly
   under `docs/`, not `docs/plans/`, for the same reason it was moved there in `whisperx-scribe`:
   it's a design doc, not a plan. Reserve `docs/plans/` in the new repo for the real, per-task
   implementation plans that step F's loop produces once work actually starts.
2. Consider also creating a minimal `CLAUDE.md` in the new repo's root at this point, with a line
   pointing at the design doc (e.g. *"Read `docs/scribe-works-design-doc.md` before
   starting any work in this repository."*). Without it, every future session has to be told to
   read the doc explicitly; with it, that happens automatically the way this repository's own
   `CLAUDE.md` already primes every session here.
3. First commit: something like `Add initial design doc for scribe-works`.

### D. Should the new project copy code from `whisperx-scribe`, or start from scratch? (answered)

**Copy only the four pipeline scripts; write everything else from scratch.**

`whisperx-scribe`'s value to this project is narrow and specific: `transcribe.py`,
`align_and_merge.py`, `diarize.py`, and `finalize.py` under `02-Transcription-Pipeline/scripts/`,
plus the two pins in `requirements.txt` (`whisperx==3.8.6`, `torchcodec==0.7.0`) — this is the
logic FR1 requires reproducing exactly. Everything else in this repository —
`run_pipeline.ps1`, `settings.ps1`/`settings.json`, the setup scripts, the PowerShell tests, the
Diátaxis docs — is specific to the local-machine, Windows/PowerShell workflow this project is
explicitly not part of (see the header table's "Explicitly out of scope" row) and has no reason
to exist in the new repo.

Concretely:

1. Copy just `02-Transcription-Pipeline/scripts/*.py` into the new repo (e.g. under
   `worker/pipeline/`), and take the two relevant lines from `requirements.txt` for the worker's
   own dependency file.
2. Record the `whisperx-scribe` commit SHA the copy was taken from — a one-line comment at the top
   of each copied file, or a short `VENDORED_FROM.md` next to them, is enough. This is the only
   thing that makes a future re-sync ("did the source scripts change upstream?") checkable instead
   of guessed.
3. Treat updates as a deliberate, manual re-copy when needed, not an automatic dependency (no git
   submodule, no build-time fetch from the other repo). At solo-project scale and with these four
   scripts being stable rather than high-churn, a submodule or live dependency adds real friction
   (submodule checkout steps, or a network dependency during every container build) for a sync
   need that will come up rarely.
4. Licensing is a non-issue here — `whisperx-scribe` is MIT-licensed under the same author's
   copyright, so copying it into a private repo under the same ownership carries no obligation
   beyond what step 2 already does for traceability.

### E. Task and session granularity — not one branch, not one session

**No — this should not be one branch or one continuous Claude Code session.** Three reasons:

- **Scope.** §6 alone lists nine phases spanning container packaging, cloud infrastructure, a
  queue, an API, secrets, a frontend, and end-to-end validation — before even counting the §5
  open-questions work that has to happen first. Each of those is independently meaningful and
  independently reviewable; none of them depends on being in the same branch as the others.
- **Session hygiene.** A single session dragged across weeks of unrelated work (Dockerfiles one
  day, cloud IaC the next, a web UI after that) accumulates context that makes later work in that
  session slower and harder to review, even with this harness's automatic summarization. Starting
  fresh per task keeps each session focused on one thing it can actually hold in full detail.
- **Reviewability.** The loop in §F only does its job — a plan to approve, a diff to review — if
  each PR is scoped to one coherent unit of work. One PR for the whole project (or even for one
  whole §6 phase bundled with the next) reduces "review" back to a rubber stamp.

**Recommended tracking mechanism: GitHub Issues**, native to the repo and proportionate to a
solo project — no separate project-management tool needed. Seed it with:

1. One issue for resolving §5's open questions — this is the very first unit of work, precedes
   any branch, and its output (the resolved decisions) is what makes the rest of the issues
   concrete instead of speculative.
2. One issue per §6 phase as a starting breakdown — they're already roughly right-sized (e.g.
   "containerize the pipeline," "queue + autoscaling," "submit/status/result API"). Split a phase
   into more than one issue once it's actually scoped, if it turns out to be bigger than it looked
   from this document (§6 says as much: it's illustrative, not a committed breakdown).

Each issue becomes the unit of work §F's loop runs on: the branch name and PR reference the issue,
the task's plan doc (§F step 4) links back to it, and the issue closes when its PR merges. Start a
new Claude Code session per branch/task rather than resuming one session across issues — see §G
for how each of those sessions begins.

### F. The agentic coding workflow (refined)

The proposed loop was: branch → push, draft PR → requirement analysis → plan → approve → write
plan in repo → implement → validate → review → commit and push. That's the right shape for one
task from §E, with one adjustment: **"commit and push" is continuous, not a final step.**
Committing only appears once at the end of the list below because that's where the loop closes,
not because it's a single event — commit as implementation progresses, and push regularly so the
draft PR reflects real progress rather than appearing empty until the very end.

The loop, run once per task from §E:

1. **Branch** — create a task branch off `main` (e.g. `feat/containerize-pipeline`).
2. **Push, open a draft PR** — even before real code exists, so the PR thread exists as the place
   design/plan/review discussion for this unit of work happens.
3. **Requirement analysis** — within that task's scope, read the relevant §5 open questions and
   §2 requirements this unit of work touches; confirm scope with the operator if anything is
   ambiguous.
4. **Plan** — write an implementation plan for this specific unit of work into the new repo's
   `docs/plans/`, following the shape this repository's own plans use (status, current/target
   state, decisions with rationale, ordered steps, validation criteria — see
   `whisperx-scribe/docs/plans/runtime-separation-refactor-plan.md` for the reference shape).
5. **Approve** — operator reviews and approves the plan before implementation starts (this is
   what Claude Code's plan mode is for).
6. **Implement** — write the code against the approved plan.
7. **Validate** — run whatever that plan's validation criteria specify (tests, a manual check,
   a real cloud run — whatever applies to that unit of work).
8. **Review** — self-review the diff, or run a review pass (e.g. this project's `code-review`
   skill), before considering it done.
9. **Commit and push** (continuously through 6–8, not only here) — mark the PR ready for review,
   and merge once validated.

### G. Start Claude Code

Open a terminal/IDE at the new repo's root and start a session there (a session in
`whisperx-scribe` cannot act on a repo it isn't rooted in). The very first session handles §E's
first issue — resolving §5 — and is the one exception to §F's loop, since there's no code to plan
yet, just decisions to make. If step C.2's `CLAUDE.md` was created, the design doc is already in
context automatically; if not, the first prompt needs to say so explicitly. Either way:

> Read `docs/scribe-works-design-doc.md`. Let's work through the Open Questions in §5
> together before any implementation — I want to decide those first, then break the result into
> issues and run each through the branch/PR/plan workflow in Appendix A §F.

Every session after that starts fresh against one issue from §E, not as a continuation of this
first one.

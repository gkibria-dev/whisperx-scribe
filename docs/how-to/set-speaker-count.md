# How to set the number of speakers

Tell diarization how many people are speaking.

## When you know the exact number

1. Pass the same number as the minimum and the maximum:

   ```powershell
   .\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\interview.wav" -MinSpeakers 2 -MaxSpeakers 2
   ```

## When you know a range

1. Pass the lower bound, the upper bound, or both:

   ```powershell
   .\02-Transcription-Pipeline\run_pipeline.ps1 "C:\Recordings\meeting.wav" -MinSpeakers 3 -MaxSpeakers 6
   ```

## Make it the default on this computer

1. Add the values to `settings.local.json` in the repository root:

   ```json
   {
     "pipeline": { "minSpeakers": 2, "maxSpeakers": 2 }
   }
   ```

2. Run the pipeline without `-MinSpeakers` and `-MaxSpeakers`.

To stop using the default, delete the two keys. Setting them to `null` does not remove a value
that `settings.json` sets.

## Check the result

1. Open `<stem>_final.txt`.
2. Check the speaker labels: `SPEAKER_00`, `SPEAKER_01`, and so on.

Both values must be 1 or more, and the minimum must not be greater than the maximum. Invalid
values are only rejected at the diarization stage, after transcription has finished.

## Related

- Reference: [`-MinSpeakers`](../reference/run-pipeline.md#-minspeakers), [`-MaxSpeakers`](../reference/run-pipeline.md#-maxspeakers)

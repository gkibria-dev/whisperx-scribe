# How to run the tests

Run all four tests from the repository root. Run the fast ones first.

## After changing settings, scripts or docs

1. Run the settings test:

   ```powershell
   .\tests\test-settings.ps1
   ```

2. Run the documentation test:

   ```powershell
   .\tests\test-docs.ps1
   ```

3. If a line reads `Undocumented option:` or `Documented option not in the script:`, edit the
   reference file named in the failure, then run the test again.

## After changing pipeline code

1. Make sure `HF_TOKEN` is set ([how-to](configure-hugging-face-token.md)).
2. Run the pipeline test:

   ```powershell
   .\tests\test-pipeline.ps1
   ```

3. To inspect the generated files, add `-KeepOutput`. The folder path is printed at the end.

## After changing setup or dependencies

1. Run the clean-install test:

   ```powershell
   .\tests\test-clean-install.ps1
   ```

2. If it fails, the temporary copy and the test environment are kept, and their paths are printed.
3. To keep them after a successful run too, add `-KeepTemp`.

## Test with other audio

1. Use a file with exactly two speakers:

   ```powershell
   .\tests\test-pipeline.ps1 -Audio "C:\Recordings\two-people.wav" -Language en -KeepOutput
   ```

Don't pass an existing folder that holds other files as `-OutputDirectory`. It is deleted after
a successful run unless `-KeepOutput` is given.

## Check the repository afterwards

1. Run:

   ```powershell
   git status
   ```

2. No test should have added generated files.

## Related

- [Reference: test scripts](../reference/test-scripts.md)

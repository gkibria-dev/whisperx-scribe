# How to change the defaults on one computer

Change paths or pipeline defaults for this computer only, without editing the committed
`settings.json`.

1. In the repository root, create `settings.local.json` if it does not exist.
2. Add only the sections and keys you want to change. For example:

   ```json
   {
     "environment": { "venvPath": "E:\\envs\\whisperx" },
     "pipeline":    { "model": "large-v3", "language": "en" },
     "output":      { "mode": "directory", "directory": "D:\\Transcripts" }
   }
   ```

   - Escape backslashes as `\\`.
   - `%NAME%` environment variables work in path values.
   - A relative path is resolved against the repository root.
3. Save the file.
4. Check the effective values:

   ```powershell
   . .\settings.ps1; (Get-ProjectSettings -RepositoryRoot (Get-Location).Path).pipeline
   ```

   Replace `.pipeline` with `.environment`, `.output` or `.test` to see the other sections.
5. Run the settings test:

   ```powershell
   .\tests\test-settings.ps1
   ```

To undo a change, delete that key from `settings.local.json`. To undo all local changes,
delete the file.

Keys you leave out keep their values from `settings.json`. Never put a token or password in
this file.

## Related

- [Reference: settings](../reference/settings.md)
- [Explanation: configuration layering](../explanation/configuration-layering.md)

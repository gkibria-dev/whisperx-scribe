# WhisperX Transcription - shared configuration loader
#
# Dot-source this from any project script:
#     . (Join-Path $RepoRoot "settings.ps1")
#     $Settings = Get-ProjectSettings -RepositoryRoot $RepoRoot
#
# Configuration comes from three layers, each overriding the one before it:
#     1. the built-in defaults in Get-DefaultProjectSettings
#     2. settings.json          (committed, portable defaults)
#     3. settings.local.json    (gitignored, optional machine-specific overrides)
#
# Missing files and missing keys are not errors - the built-in defaults keep the
# project working without any settings file at all.
#
# Secrets never belong in either settings file. HF_TOKEN is read from the
# environment, exactly as before.
#
# Written for Windows PowerShell 5.1: no ConvertFrom-Json -AsHashtable, no
# ternary, no null-coalescing.

function Get-DefaultProjectSettings {
    return @{
        environment = @{
            venvPath      = '%LOCALAPPDATA%\WhisperX-Transcription\venv'
            pythonCommand = 'python'
        }
        pipeline = @{
            model       = 'medium'
            device      = 'cpu'
            computeType = 'int8'
            language    = ''
            minSpeakers = $null
            maxSpeakers = $null
        }
        output = @{
            mode      = 'beside-audio'
            directory = '%LOCALAPPDATA%\WhisperX-Transcription\output'
        }
        test = @{
            outputDirectory = '%LOCALAPPDATA%\WhisperX-Transcription\test-output'
            environmentPath = '%LOCALAPPDATA%\WhisperX-Transcription\test-venv'
            keepOutput      = $false
            model           = 'medium'
            device          = 'cpu'
            computeType     = 'int8'
        }
    }
}

function Read-SettingsFile {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8

    if ([string]::IsNullOrWhiteSpace($content)) {
        return $null
    }

    try {
        return ($content | ConvertFrom-Json)
    }
    catch {
        throw @"
Failed to parse settings file: $Path

$($_.Exception.Message)

Fix the JSON syntax, or delete the file to fall back to the defaults.
"@
    }
}

function Merge-SettingsSection {
    # Copies $Defaults, then overlays any key the override object actually
    # supplies. A key set to null in JSON leaves the default in place.
    param(
        [Parameter(Mandatory)][hashtable]$Defaults,
        $Override
    )

    $merged = @{}

    foreach ($key in $Defaults.Keys) {
        $merged[$key] = $Defaults[$key]
    }

    if ($null -eq $Override) {
        return $merged
    }

    foreach ($key in @($merged.Keys)) {
        $property = $Override.PSObject.Properties[$key]

        if ($null -ne $property -and $null -ne $property.Value) {
            $merged[$key] = $property.Value
        }
    }

    return $merged
}

function Get-ProjectSettings {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $settings = Get-DefaultProjectSettings

    $settingsFiles = @(
        (Join-Path $RepositoryRoot "settings.json"),
        (Join-Path $RepositoryRoot "settings.local.json")
    )

    foreach ($settingsFile in $settingsFiles) {
        $document = Read-SettingsFile -Path $settingsFile

        if ($null -eq $document) {
            continue
        }

        foreach ($section in @($settings.Keys)) {
            $sectionProperty = $document.PSObject.Properties[$section]

            if ($null -ne $sectionProperty) {
                $settings[$section] = Merge-SettingsSection `
                    -Defaults $settings[$section] `
                    -Override $sectionProperty.Value
            }
        }
    }

    return $settings
}

function Resolve-ConfiguredPath {
    # Expands %VAR% style environment variables, then resolves a relative path
    # against the repository root. The path does not need to exist.
    param(
        [string]$Path,
        [Parameter(Mandatory)][string]$RepositoryRoot
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path)

    if ([System.IO.Path]::IsPathRooted($expanded)) {
        return [System.IO.Path]::GetFullPath($expanded)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot $expanded))
}

function Get-VenvPython {
    param([Parameter(Mandatory)][string]$EnvironmentPath)

    return (Join-Path $EnvironmentPath "Scripts\python.exe")
}

function Get-LegacyEnvironmentPaths {
    # Reports virtual environments left inside the repository by earlier versions
    # of this project.
    #
    # This is ADVISORY ONLY. Nothing in this project may fall back to these
    # paths - the configured external environment is the only one used. This
    # function exists so setup.ps1 can tell the user about an orphan that is now
    # safe to delete.
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $legacyNames = @(".venv", "env", "whisperx-env")
    $found = @()

    foreach ($legacyName in $legacyNames) {
        $candidate = Join-Path $RepositoryRoot $legacyName

        if (Test-Path -LiteralPath (Get-VenvPython -EnvironmentPath $candidate) -PathType Leaf) {
            $found += $candidate
        }
    }

    return $found
}

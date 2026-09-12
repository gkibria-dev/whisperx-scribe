<#
.SYNOPSIS
    Validates the settings layering used by every script in this project.

.DESCRIPTION
    Checks that configuration resolves in this order, each layer overriding only
    the keys it actually supplies:

        built-in defaults  ->  settings.json  ->  settings.local.json

    Most assertions run against synthetic settings files in a temporary
    directory, so the test never reads or writes the developer's real
    settings.local.json.

    The test is fast and offline. It does not need a WhisperX environment, does
    not download models, and does not run the transcription pipeline.

.EXAMPLE
    .\tests\test-settings.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$RepositoryRoot = Split-Path -Parent $PSScriptRoot

. (Join-Path $RepositoryRoot "settings.ps1")

$script:Passed = 0
$script:Failed = 0
$script:Sandboxes = @()

function Assert-Equal {
    param($Expected, $Actual, [Parameter(Mandatory)][string]$Description)

    if ($Expected -eq $Actual) {
        $script:Passed++
        Write-Host "  PASS  $Description" -ForegroundColor Green
    }
    else {
        $script:Failed++
        Write-Host "  FAIL  $Description" -ForegroundColor Red
        Write-Host "        expected: [$Expected]" -ForegroundColor Red
        Write-Host "        actual:   [$Actual]" -ForegroundColor Red
    }
}

function Assert-True {
    param($Condition, [Parameter(Mandatory)][string]$Description)

    if ($Condition) {
        $script:Passed++
        Write-Host "  PASS  $Description" -ForegroundColor Green
    }
    else {
        $script:Failed++
        Write-Host "  FAIL  $Description" -ForegroundColor Red
    }
}

function New-SettingsSandbox {
    # Writes synthetic settings files into a throwaway directory and returns it,
    # so layering can be tested without touching the real repository files.
    param($MainJson, $LocalJson)

    $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) `
        ("WhisperX-settings-" + [Guid]::NewGuid().ToString("N"))

    New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
    $script:Sandboxes += $sandbox

    if ($null -ne $MainJson) {
        $MainJson | Out-File -FilePath (Join-Path $sandbox "settings.json") -Encoding utf8
    }

    if ($null -ne $LocalJson) {
        $LocalJson | Out-File -FilePath (Join-Path $sandbox "settings.local.json") -Encoding utf8
    }

    return $sandbox
}

Write-Host "=== WhisperX settings layering test ===" -ForegroundColor Cyan
Write-Host "Repository: $RepositoryRoot"

try {
    # ------------------------------------------------------------------
    Write-Host ""
    Write-Host "--- Layer 1: built-in defaults apply with no settings files ---" -ForegroundColor Yellow

    $sandbox = New-SettingsSandbox -MainJson $null -LocalJson $null
    $settings = Get-ProjectSettings -RepositoryRoot $sandbox

    Assert-Equal '%LOCALAPPDATA%\WhisperX-Transcription\venv' $settings.environment.venvPath `
        "venvPath falls back to the built-in default"
    Assert-Equal "medium" $settings.pipeline.model "pipeline.model falls back to the built-in default"
    Assert-Equal "beside-audio" $settings.output.mode "output.mode falls back to the built-in default"

    # ------------------------------------------------------------------
    Write-Host ""
    Write-Host "--- Layer 2: settings.json overrides the defaults ---" -ForegroundColor Yellow

    $mainJson = @'
{
  "environment": { "venvPath": "C:\\from-main\\venv", "pythonCommand": "python-main" },
  "pipeline":    { "model": "large-v3", "device": "cuda" },
  "output":      { "mode": "directory" },
  "test":        { "outputDirectory": "C:\\from-main\\test-output" }
}
'@

    $sandbox = New-SettingsSandbox -MainJson $mainJson -LocalJson $null
    $settings = Get-ProjectSettings -RepositoryRoot $sandbox

    Assert-Equal "C:\from-main\venv" $settings.environment.venvPath "settings.json supplies venvPath"
    Assert-Equal "large-v3" $settings.pipeline.model "settings.json supplies pipeline.model"
    Assert-Equal "int8" $settings.pipeline.computeType `
        "a key absent from settings.json still comes from the defaults"

    # ------------------------------------------------------------------
    Write-Host ""
    Write-Host "--- Layer 3: settings.local.json overrides only what it supplies ---" -ForegroundColor Yellow

    $localJson = @'
{
  "environment": { "venvPath": "D:\\from-local\\venv" }
}
'@

    $sandbox = New-SettingsSandbox -MainJson $mainJson -LocalJson $localJson
    $settings = Get-ProjectSettings -RepositoryRoot $sandbox

    # The override itself.
    Assert-Equal "D:\from-local\venv" $settings.environment.venvPath `
        "settings.local.json overrides environment.venvPath"

    # Unrelated keys must survive - including the sibling key in the very same
    # section, which is where a naive whole-section replacement would break.
    Assert-Equal "python-main" $settings.environment.pythonCommand `
        "sibling key in the overridden section still comes from settings.json"
    Assert-Equal "large-v3" $settings.pipeline.model `
        "unrelated section (pipeline.model) still comes from settings.json"
    Assert-Equal "cuda" $settings.pipeline.device `
        "unrelated section (pipeline.device) still comes from settings.json"
    Assert-Equal "directory" $settings.output.mode `
        "unrelated section (output.mode) still comes from settings.json"
    Assert-Equal "C:\from-main\test-output" $settings.test.outputDirectory `
        "unrelated section (test.outputDirectory) still comes from settings.json"
    Assert-Equal "int8" $settings.pipeline.computeType `
        "a key in neither file still comes from the built-in defaults"

    # ------------------------------------------------------------------
    Write-Host ""
    Write-Host "--- Path resolution ---" -ForegroundColor Yellow

    $resolved = Resolve-ConfiguredPath -Path '%LOCALAPPDATA%\WhisperX-Transcription\venv' `
        -RepositoryRoot $RepositoryRoot

    Assert-Equal (Join-Path $env:LOCALAPPDATA "WhisperX-Transcription\venv") $resolved `
        "Resolve-ConfiguredPath expands %LOCALAPPDATA%"
    Assert-True ([System.IO.Path]::IsPathRooted($resolved)) `
        "the resolved environment path is absolute"
    Assert-Equal (Join-Path $resolved "Scripts\python.exe") (Get-VenvPython -EnvironmentPath $resolved) `
        "Get-VenvPython appends Scripts\python.exe"

    # ------------------------------------------------------------------
    Write-Host ""
    Write-Host "--- No secrets in settings files ---" -ForegroundColor Yellow

    foreach ($name in @("settings.json", "settings.local.json")) {
        $path = Join-Path $RepositoryRoot $name

        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            continue
        }

        $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8

        Assert-True ($content -notmatch '(?i)(hf_token|token|secret|password|credential|api[_-]?key)') `
            "$name contains no secret-looking keys"
    }

    # ------------------------------------------------------------------
    Write-Host ""
    Write-Host "--- This repository's real configuration ---" -ForegroundColor Yellow

    Assert-True (Test-Path -LiteralPath (Join-Path $RepositoryRoot "settings.json") -PathType Leaf) `
        "settings.json exists"

    $realSettings = Get-ProjectSettings -RepositoryRoot $RepositoryRoot
    $realVenv = Resolve-ConfiguredPath -Path $realSettings.environment.venvPath `
        -RepositoryRoot $RepositoryRoot

    Assert-True ([System.IO.Path]::IsPathRooted($realVenv)) `
        "the configured environment path resolves to an absolute path"
    Assert-True (-not $realVenv.StartsWith($RepositoryRoot, [StringComparison]::OrdinalIgnoreCase)) `
        "the configured environment path is outside the repository"

    $localPath = Join-Path $RepositoryRoot "settings.local.json"

    if (Test-Path -LiteralPath $localPath -PathType Leaf) {
        Write-Host "  settings.local.json is present on this machine." -ForegroundColor DarkGray

        # Parses, and is actually consulted by the loader.
        $localDocument = Read-SettingsFile -Path $localPath
        Assert-True ($null -ne $localDocument) "settings.local.json parses as JSON"

        $localVenvProperty = $null
        $environmentSection = $localDocument.PSObject.Properties["environment"]

        if ($null -ne $environmentSection -and $null -ne $environmentSection.Value) {
            $localVenvProperty = $environmentSection.Value.PSObject.Properties["venvPath"]
        }

        if ($null -ne $localVenvProperty) {
            $expected = Resolve-ConfiguredPath -Path $localVenvProperty.Value `
                -RepositoryRoot $RepositoryRoot

            Assert-Equal $expected $realVenv `
                "the environment path override in settings.local.json is applied"
        }

        # Check every key in settings.json against the effective value, deciding
        # what to expect from whether the override actually supplies that key.
        # Nothing here assumes a particular override shape, so this keeps working
        # however this machine's settings.local.json is written.
        $committed = Read-SettingsFile -Path (Join-Path $RepositoryRoot "settings.json")

        $overriddenCount = 0
        $inheritedCount = 0

        foreach ($sectionProperty in $committed.PSObject.Properties) {
            $sectionName = $sectionProperty.Name

            if (-not $realSettings.ContainsKey($sectionName)) {
                continue
            }

            $localSection = $null
            $localSectionProperty = $localDocument.PSObject.Properties[$sectionName]

            if ($null -ne $localSectionProperty) {
                $localSection = $localSectionProperty.Value
            }

            foreach ($keyProperty in $sectionProperty.Value.PSObject.Properties) {
                $keyName = $keyProperty.Name

                if (-not $realSettings[$sectionName].ContainsKey($keyName)) {
                    continue
                }

                $effective = $realSettings[$sectionName][$keyName]

                $localValue = $null

                if ($null -ne $localSection) {
                    $localKeyProperty = $localSection.PSObject.Properties[$keyName]

                    if ($null -ne $localKeyProperty) {
                        $localValue = $localKeyProperty.Value
                    }
                }

                if ($null -ne $localValue) {
                    $overriddenCount++
                    Assert-Equal $localValue $effective `
                        "$sectionName.$keyName comes from settings.local.json"
                }
                else {
                    $inheritedCount++
                    Assert-Equal $keyProperty.Value $effective `
                        "$sectionName.$keyName still comes from settings.json"
                }
            }
        }

        Write-Host "  ($overriddenCount key(s) overridden locally, $inheritedCount inherited from settings.json)" -ForegroundColor DarkGray

        Assert-True ($inheritedCount -gt 0) `
            "at least one setting is still inherited from settings.json"
    }
    else {
        Write-Host "  settings.local.json is absent - override assertions skipped." -ForegroundColor DarkGray
    }

    # ------------------------------------------------------------------
    Write-Host ""
    Write-Host "--- settings.local.json is ignored by Git ---" -ForegroundColor Yellow

    if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "  git not available - Git assertions skipped." -ForegroundColor DarkYellow
    }
    else {
        & git -C $RepositoryRoot check-ignore -q "settings.local.json"
        Assert-Equal 0 $LASTEXITCODE "git check-ignore reports settings.local.json as ignored"

        $tracked = & git -C $RepositoryRoot ls-files "settings.local.json"
        Assert-True ([string]::IsNullOrWhiteSpace($tracked)) `
            "settings.local.json is not tracked by Git"

        # settings.json must remain committable. Tracking status depends on
        # whether a commit has happened yet, so assert on the ignore rule, which
        # is the property the configuration design actually guarantees.
        & git -C $RepositoryRoot check-ignore -q "settings.json"
        Assert-Equal 1 $LASTEXITCODE "settings.json is NOT ignored by Git"
    }

    # ------------------------------------------------------------------
    Write-Host ""
    Write-Host "--- Consumers use the settings mechanism ---" -ForegroundColor Yellow

    $consumers = @(
        "01-Environment-Setup\setup.ps1",
        "02-Transcription-Pipeline\run_pipeline.ps1"
    )

    foreach ($consumer in $consumers) {
        $source = Get-Content -LiteralPath (Join-Path $RepositoryRoot $consumer) -Raw -Encoding UTF8

        Assert-True ($source -match 'settings\.ps1') "$consumer loads settings.ps1"
        Assert-True ($source -match 'environment\.venvPath') "$consumer reads environment.venvPath"
        Assert-True ($source -match 'Resolve-ConfiguredPath') "$consumer resolves the configured path"

        # There must be no way back to a repository-local environment.
        Assert-True ($source -notmatch 'EnvironmentCandidates') `
            "$consumer has no repository-local environment fallback"
    }

    Write-Host ""

    if ($script:Failed -gt 0) {
        throw "$script:Failed assertion(s) failed."
    }

    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "SETTINGS TEST PASSED" -ForegroundColor Green
    Write-Host "Assertions passed: $script:Passed" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host "SETTINGS TEST FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Assertions passed: $script:Passed, failed: $script:Failed" -ForegroundColor Red
    Write-Host "==============================================" -ForegroundColor Red
    throw
}
finally {
    foreach ($sandbox in $script:Sandboxes) {
        if (Test-Path -LiteralPath $sandbox) {
            Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

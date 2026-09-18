<#
.SYNOPSIS
    Checks that every script option and every setting is documented in docs/reference.

.DESCRIPTION
    Reads the real scripts and the real settings loader, then compares them with
    the headings of the reference documents, in both directions:

        - every parameter in the code has a reference heading (nothing missing);
        - every reference heading names a real script, parameter or setting
          (nothing stale after a rename or removal).

    Scripts are discovered by globbing, so a new script is checked automatically.

    Code side:
        PowerShell scripts   the param() block, read through the PowerShell AST
        Python stage scripts the leading string literals of each add_argument( call
        Settings             every key returned by Get-DefaultProjectSettings

    Docs side, per reference file:
        ## `script-name`     one section per script
        ### `-Parameter`     one heading per parameter, spelled as on the command line
        ### `section.key`    one heading per setting (settings.md only)

    The test is fast and offline. It does not need a WhisperX environment and
    does not import any Python package.

.EXAMPLE
    .\tests\test-docs.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$ReferenceRoot = Join-Path $RepositoryRoot "docs\reference"

. (Join-Path $RepositoryRoot "settings.ps1")

$script:Passed = 0
$script:Failed = 0

# Which scripts each reference file documents.
$ScriptGroups = @(
    @{ Reference = "setup-scripts.md";          Directory = "01-Environment-Setup";              Filter = "*.ps1" },
    @{ Reference = "run-pipeline.md";           Directory = "02-Transcription-Pipeline";         Filter = "*.ps1" },
    @{ Reference = "pipeline-stage-scripts.md"; Directory = "02-Transcription-Pipeline\scripts"; Filter = "*.py"  },
    @{ Reference = "test-scripts.md";           Directory = "tests";                             Filter = "*.ps1" }
)

$SettingsReference = "settings.md"

function Write-Pass {
    param([Parameter(Mandatory)][string]$Description)

    $script:Passed++
    Write-Host "  PASS  $Description" -ForegroundColor Green
}

function Write-Fail {
    param(
        [Parameter(Mandatory)][string]$Description,
        [string[]]$Details = @()
    )

    $script:Failed++
    Write-Host "  FAIL  $Description" -ForegroundColor Red

    foreach ($detail in $Details) {
        Write-Host "        $detail" -ForegroundColor Red
    }
}

function Get-PowerShellParameters {
    param([Parameter(Mandatory)][string]$Path)

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)

    if ($errors.Count -gt 0) {
        throw "Cannot parse ${Path}: $($errors[0].Message)"
    }

    if ($null -eq $ast.ParamBlock) {
        return @()
    }

    return @($ast.ParamBlock.Parameters | ForEach-Object { "-" + $_.Name.VariablePath.UserPath })
}

function Get-PythonArguments {
    # Collects every option string passed to add_argument(, including calls
    # that span several lines and calls with both a short and a long flag.
    param([Parameter(Mandatory)][string]$Path)

    $source = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $names = @()

    $calls = [regex]::Matches($source, 'add_argument\(\s*((?:(?:"[^"]*"|''[^'']*'')\s*,?\s*)+)')

    foreach ($call in $calls) {
        foreach ($literal in [regex]::Matches($call.Groups[1].Value, '"([^"]*)"|''([^'']*)''')) {
            $value = $literal.Groups[1].Value + $literal.Groups[2].Value
            $names += $value
        }
    }

    return $names
}

function Get-ReferenceHeadings {
    # Returns @{ Sections = @{ name = [list of ### names] }; All = [every ### name] }.
    # Headings count only when their whole text is one code span. Lines inside
    # fenced code blocks are ignored.
    param([Parameter(Mandatory)][string]$Path)

    $sections = [ordered]@{}
    $all = @()
    $current = $null
    $inFence = $false

    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        if ($line -match '^\s*(```|~~~)') {
            $inFence = -not $inFence
            continue
        }

        if ($inFence) {
            continue
        }

        if ($line -match '^##\s+`([^`]+)`\s*$') {
            $current = $Matches[1]
            $sections[$current] = @()
            continue
        }

        if ($line -match '^##\s') {
            $current = $null
            continue
        }

        if ($line -match '^###\s+`([^`]+)`\s*$') {
            $all += $Matches[1]

            if ($null -ne $current) {
                $sections[$current] += $Matches[1]
            }
        }
    }

    return @{ Sections = $sections; All = $all }
}

function Compare-Names {
    # Returns @{ Missing = in code, not in docs; Stale = in docs, not in code }.
    param([string[]]$Code = @(), [string[]]$Documented = @())

    return @{
        Missing = @($Code | Where-Object { $Documented -cnotcontains $_ })
        Stale   = @($Documented | Where-Object { $Code -cnotcontains $_ })
    }
}

Write-Host "=== WhisperX documentation coverage test ===" -ForegroundColor Cyan
Write-Host "Repository: $RepositoryRoot"

try {
    foreach ($group in $ScriptGroups) {
        $referenceRelative = "docs\reference\" + $group.Reference
        $referencePath = Join-Path $ReferenceRoot $group.Reference

        Write-Host ""
        Write-Host "--- $referenceRelative ($($group.Directory)\$($group.Filter)) ---" -ForegroundColor Yellow

        if (Test-Path -LiteralPath $referencePath -PathType Leaf) {
            $headings = Get-ReferenceHeadings -Path $referencePath
        }
        else {
            # Keep going with no headings, so every undocumented option is still listed.
            Write-Fail "$referenceRelative exists" @("Create it with one '## ``script``' section per script.")
            $headings = @{ Sections = [ordered]@{}; All = @() }
        }

        $scripts = @(
            Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot $group.Directory) -Filter $group.Filter -File |
            Sort-Object Name
        )

        foreach ($scriptFile in $scripts) {
            $name = $scriptFile.Name

            if ($scriptFile.Extension -eq ".py") {
                $codeNames = @(Get-PythonArguments -Path $scriptFile.FullName)
            }
            else {
                $codeNames = @(Get-PowerShellParameters -Path $scriptFile.FullName)
            }

            if (-not $headings.Sections.Contains($name)) {
                $details = @("Add a '## ``$name``' section to $referenceRelative.")

                foreach ($codeName in $codeNames) {
                    $details += "Undocumented option: $codeName"
                }

                Write-Fail "$name has a section" $details
                continue
            }

            $comparison = Compare-Names -Code $codeNames -Documented @($headings.Sections[$name])
            $details = @()

            foreach ($missing in $comparison.Missing) {
                $details += "Undocumented option: $missing  (add '### ``$missing``' under '## ``$name``')"
            }

            foreach ($stale in $comparison.Stale) {
                $details += "Documented option not in the script: $stale  (remove or rename the heading)"
            }

            if ($details.Count -eq 0) {
                Write-Pass "$name - $($codeNames.Count) option(s) documented, none stale"
            }
            else {
                Write-Fail "$name options match $referenceRelative" $details
            }
        }

        $scriptNames = @($scripts | ForEach-Object { $_.Name })

        foreach ($sectionName in $headings.Sections.Keys) {
            if ($scriptNames -cnotcontains $sectionName) {
                Write-Fail "section '$sectionName' names an existing script" @(
                    "No $($group.Filter) file named '$sectionName' in $($group.Directory).",
                    "Remove or rename the section in $referenceRelative."
                )
            }
        }
    }

    # ------------------------------------------------------------------
    $referenceRelative = "docs\reference\$SettingsReference"
    $referencePath = Join-Path $ReferenceRoot $SettingsReference

    Write-Host ""
    Write-Host "--- $referenceRelative (Get-DefaultProjectSettings) ---" -ForegroundColor Yellow

    if (Test-Path -LiteralPath $referencePath -PathType Leaf) {
        $headings = Get-ReferenceHeadings -Path $referencePath
    }
    else {
        Write-Fail "$referenceRelative exists" @("Create it with one '### ``section.key``' heading per setting.")
        $headings = @{ Sections = [ordered]@{}; All = @() }
    }

    $defaults = Get-DefaultProjectSettings
    $settingKeys = @()

    foreach ($section in $defaults.Keys) {
        foreach ($key in $defaults[$section].Keys) {
            $settingKeys += "$section.$key"
        }
    }

    $settingKeys = @($settingKeys | Sort-Object)
    $comparison = Compare-Names -Code $settingKeys -Documented $headings.All
    $details = @()

    foreach ($missing in $comparison.Missing) {
        $details += "Undocumented setting: $missing  (add '### ``$missing``')"
    }

    foreach ($stale in $comparison.Stale) {
        $details += "Documented setting not in Get-DefaultProjectSettings: $stale"
    }

    if ($details.Count -eq 0) {
        Write-Pass "$($settingKeys.Count) setting(s) documented, none stale"
    }
    else {
        Write-Fail "settings match $referenceRelative" $details
    }

    Write-Host ""

    if ($script:Failed -gt 0) {
        throw "$script:Failed assertion(s) failed."
    }

    Write-Host "==============================================" -ForegroundColor Green
    Write-Host "DOCUMENTATION TEST PASSED" -ForegroundColor Green
    Write-Host "Assertions passed: $script:Passed" -ForegroundColor Green
    Write-Host "==============================================" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Red
    Write-Host "DOCUMENTATION TEST FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Assertions passed: $script:Passed, failed: $script:Failed" -ForegroundColor Red
    Write-Host "==============================================" -ForegroundColor Red
    throw
}

# Every failure path throws before this point. Exit 0 explicitly so a trailing native
# command (git, robocopy) cannot leave a non-zero $LASTEXITCODE behind on success.
exit 0

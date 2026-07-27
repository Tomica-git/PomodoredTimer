[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$StagingDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    throw "WINDOWS PUBLIC BUILD CHECK FAILED: $Message"
}

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$stagingPath = [IO.Path]::GetFullPath($StagingDirectory)
if (-not (Test-Path -LiteralPath $stagingPath -PathType Container)) {
    Fail "staging directory does not exist"
}

$files = @(Get-ChildItem -LiteralPath $stagingPath -File -Recurse)
if ($files.Count -ne 1 -or $files[0].Name -ne "PomodoredTimer.Windows.Public.exe") {
    $names = ($files | ForEach-Object { $_.FullName.Substring($stagingPath.Length).TrimStart('\', '/') }) -join ", "
    Fail "unexpected publish output: $names"
}

$sourceRoot = Join-Path $repoRoot "Windows/src"
$sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -File -Recurse |
    Where-Object { $_.Extension -in ".cs", ".xaml", ".csproj" })
$sourceText = ($sourceFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
$sourceForbidden = @(
    "youtube",
    "youtu.be",
    "webview",
    "personal_build",
    "/Users/",
    "/home/",
    "C:\Users\",
    "PomodoredTimer\Personal"
)
foreach ($needle in $sourceForbidden) {
    if ($sourceText.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        Fail "forbidden public-source marker is present: $needle"
    }
}

$bytes = [IO.File]::ReadAllBytes($files[0].FullName)
$binaryText = [Text.Encoding]::UTF8.GetString($bytes) + "`n" + [Text.Encoding]::Unicode.GetString($bytes)
# The self-contained Windows Desktop runtime contains generic framework type and path names.
# Those are checked at the application-source boundary above; this final binary scan is limited
# to app-specific personal features, identities, and persistence keys to avoid runtime false positives.
$binaryForbidden = @(
    "youtube",
    "youtu.be",
    "pomodored.timer.state.v1",
    "pomodored.window.compact.v1",
    "pomodored.window.alwaysOnTop.v1",
    "PomodoredTimer\Personal"
)
foreach ($needle in $binaryForbidden) {
    if ($binaryText.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        Fail "forbidden public-binary marker is present: $needle"
    }
}

foreach ($required in @("PomodoredTimer", "Public", "state.v1.json")) {
    if ($binaryText.IndexOf($required, [StringComparison]::Ordinal) -lt 0) {
        Fail "required public identity is missing: $required"
    }
}

Write-Host "PASS: Windows public artifact contains no personal media, storage keys, records, or local paths"

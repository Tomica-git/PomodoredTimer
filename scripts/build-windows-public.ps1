[CmdletBinding()]
param(
    [ValidateSet("win-x64")]
    [string]$Runtime = "win-x64"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$solutionPath = Join-Path $repoRoot "Windows/PomodoredTimer.Windows.sln"
$appProject = Join-Path $repoRoot "Windows/src/PomodoredTimer.Windows.Public/PomodoredTimer.Windows.Public.csproj"
$testProject = Join-Path $repoRoot "Windows/tests/PomodoredTimer.Core.Tests/PomodoredTimer.Core.Tests.csproj"
$vectorPath = Join-Path $repoRoot "Shared/TestVectors/public-core-v1/timer-vectors.json"
$expectedDist = [IO.Path]::GetFullPath((Join-Path $repoRoot "dist/windows-public"))
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("pomodored-windows-public-" + [Guid]::NewGuid().ToString("N"))
$publishDirectory = Join-Path $temporaryRoot "publish"

try {
    New-Item -ItemType Directory -Path $publishDirectory -Force | Out-Null

    & dotnet restore $solutionPath
    if ($LASTEXITCODE -ne 0) { throw "dotnet restore failed" }

    & dotnet build $solutionPath --configuration Release --no-restore
    if ($LASTEXITCODE -ne 0) { throw "dotnet build failed" }

    & dotnet run --project $testProject --configuration Release --no-build -- $vectorPath
    if ($LASTEXITCODE -ne 0) { throw "Windows deterministic tests failed" }

    & dotnet restore $appProject --runtime $Runtime
    if ($LASTEXITCODE -ne 0) { throw "Windows runtime restore failed" }

    & dotnet publish $appProject `
        --configuration Release `
        --runtime $Runtime `
        --self-contained true `
        --no-restore `
        --output $publishDirectory `
        -p:PublishSingleFile=true `
        -p:IncludeNativeLibrariesForSelfExtract=true `
        -p:DebugType=None `
        -p:DebugSymbols=false
    if ($LASTEXITCODE -ne 0) { throw "Windows public publish failed" }

    & (Join-Path $PSScriptRoot "verify-windows-public.ps1") -StagingDirectory $publishDirectory

    $actualDist = [IO.Path]::GetFullPath($expectedDist)
    $allowedDist = [IO.Path]::GetFullPath((Join-Path $repoRoot "dist/windows-public"))
    if (-not [String]::Equals($actualDist, $allowedDist, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to replace an unexpected output path"
    }

    if (Test-Path -LiteralPath $actualDist) {
        Remove-Item -LiteralPath $actualDist -Recurse -Force
    }
    New-Item -ItemType Directory -Path $actualDist -Force | Out-Null

    $publishedExe = Join-Path $publishDirectory "PomodoredTimer.Windows.Public.exe"
    $distExe = Join-Path $actualDist "PomodoredTimer.Windows.Public.exe"
    Move-Item -LiteralPath $publishedExe -Destination $distExe
    $hash = (Get-FileHash -LiteralPath $distExe -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -LiteralPath (Join-Path $actualDist "SHA256.txt") `
        -Value "$hash  PomodoredTimer.Windows.Public.exe" `
        -Encoding ascii

    $commit = (& git -C $repoRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Cannot identify the source commit" }
    $dirty = @(& git -C $repoRoot status --porcelain).Count -gt 0
    if ($LASTEXITCODE -ne 0) { throw "Cannot inspect the source tree" }
    $dotnetVersion = (& dotnet --version).Trim()
    if ($LASTEXITCODE -ne 0) { throw "Cannot identify the .NET SDK" }
    $manifest = [ordered]@{
        schemaVersion = 1
        product = "windows-public"
        edition = "public"
        releaseStatus = "candidate"
        source = [ordered]@{
            commit = $commit
            dirty = $dirty
        }
        environment = [ordered]@{
            platform = "windows"
            architecture = "x64"
            toolchain = ".NET SDK $dotnetVersion"
            runtime = $Runtime
        }
        artifact = [ordered]@{
            path = "PomodoredTimer.Windows.Public.exe"
            sha256 = $hash
        }
    }
    $manifest | ConvertTo-Json -Depth 5 | Set-Content `
        -LiteralPath (Join-Path $actualDist "BUILD-MANIFEST.json") `
        -Encoding utf8

    Write-Host $actualDist
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

$ErrorActionPreference = "Stop"

$Repository = Split-Path -Parent $PSScriptRoot
$Build = Join-Path $Repository "build"

function Resolve-Studio {
    $Running = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $Running -and (Test-Path -LiteralPath $Running.Path)) {
        return $Running.Path
    }

    $Roots = @(
        (Join-Path $env:LOCALAPPDATA "Roblox\Versions"),
        (Join-Path ${env:ProgramFiles(x86)} "Roblox\Versions")
    )
    foreach ($Root in $Roots) {
        if (-not (Test-Path -LiteralPath $Root)) { continue }
        $Studio = Get-ChildItem -LiteralPath $Root -Filter "RobloxStudioBeta.exe" -File -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($null -ne $Studio) { return $Studio.FullName }
    }
    throw "RobloxStudioBeta.exe was not found"
}

Push-Location $Repository
try {
    & (Join-Path $PSScriptRoot "Build.ps1")

    $Studio = Resolve-Studio
    $Output = Join-Path $Build "verify-studio-tests.log"
    $Arguments = @(
        "--task", "RunScript",
        "--localPlaceFile", ('"' + (Join-Path $Build "fishing-tests.rbxlx") + '"'),
        "--runScriptFile", ('"' + (Join-Path $PSScriptRoot "StudioTestRunner.luau") + '"'),
        "--outputFile", ('"' + $Output + '"'),
        "--quitAfterExecution"
    )
    $Process = Start-Process -FilePath $Studio -ArgumentList $Arguments -WindowStyle Hidden -Wait -PassThru
    if ($Process.ExitCode -ne 0) {
        throw "Roblox Studio exited with code $($Process.ExitCode)"
    }
    $Text = Get-Content -Raw -LiteralPath $Output
    if (-not $Text.Contains("[ECSRFishingDemo] PASS")) {
        throw "Studio verification did not produce [ECSRFishingDemo] PASS"
    }
    Write-Host "[ECSRFishingDemo] PASS"
    Write-Host "[ECSR Fishing Verify] PASS - static, build and Studio state evolution"
}
finally {
    Pop-Location
}

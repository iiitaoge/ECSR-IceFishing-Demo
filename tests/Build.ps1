$ErrorActionPreference = "Stop"

$Repository = Split-Path -Parent $PSScriptRoot
$Build = Join-Path $Repository "build"
New-Item -ItemType Directory -Path $Build -Force | Out-Null

Push-Location $Repository
try {
    & (Join-Path $PSScriptRoot "Conformance.ps1")
    $Rojo = & (Join-Path $PSScriptRoot "ResolveRojo.ps1") -Repository $Repository
    & $Rojo build demo.project.json --output (Join-Path $Build "fishing-demo.rbxlx")
    if ($LASTEXITCODE -ne 0) { throw "playable Demo build failed" }
    & $Rojo build test.project.json --output (Join-Path $Build "fishing-tests.rbxlx")
    if ($LASTEXITCODE -ne 0) { throw "test place build failed" }
    Write-Host "[ECSR Fishing Build] PASS - conformance and Rojo artifacts"
}
finally {
    Pop-Location
}

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    throw "Fishing Demo conformance failed: $Message"
}

$Repository = Split-Path -Parent $PSScriptRoot
$EcsrConformance = Join-Path $Repository "vendor\ECSR\tests\Conformance.ps1"
if (-not (Test-Path -LiteralPath $EcsrConformance)) {
    Fail "ECSR submodule is missing; run git submodule update --init --recursive"
}
& $EcsrConformance

$Demo = Join-Path $Repository "demo"
$EcsrApp = Join-Path $Demo "ECSR"
$DemoRoots = @(Get-ChildItem -LiteralPath $Demo -Directory | ForEach-Object Name | Sort-Object)
if (($DemoRoots -join "|") -ne "ECSR") {
    Fail "demo may contain only the ECSR application boundary; found $($DemoRoots -join ', ')"
}
$ExpectedRoots = @("Components", "Platform", "Rules", "Systems")
$ActualRoots = @(Get-ChildItem -LiteralPath $EcsrApp -Directory | ForEach-Object Name | Sort-Object)
if (($ActualRoots -join "|") -ne (($ExpectedRoots | Sort-Object) -join "|")) {
    Fail "demo/ECSR may contain only Components, Systems, Rules and Platform; found $($ActualRoots -join ', ')"
}

$DomainFiles = @(
    foreach ($Root in @("Components", "Systems", "Rules")) {
        Get-ChildItem -LiteralPath (Join-Path $EcsrApp $Root) -Filter "*.luau" -File -Recurse
    }
)
$WritePattern = '\b(?:self\.)?(?:world|_world):(spawnAt|spawn|insert|remove|despawn|clear|replace|optimizeQueries)\s*\('
$WriteViolations = @($DomainFiles | Select-String -Pattern $WritePattern)
if ($WriteViolations.Count -gt 0) {
    Fail "domain code escaped ECSR StateUpdateRule authority: $($WriteViolations[0].Path):$($WriteViolations[0].LineNumber)"
}

$PlatformLeaks = @($DomainFiles | Select-String -Pattern 'GetService|Instance\.new|RemoteEvent|ReplicatedStorage|ServerScriptService|StarterPlayer|Workspace')
if ($PlatformLeaks.Count -gt 0) {
    Fail "Components/Systems/Rules contain a Roblox platform dependency: $($PlatformLeaks[0].Path):$($PlatformLeaks[0].LineNumber)"
}

$PresentationPath = Join-Path $EcsrApp "Platform\FishingPresentation.luau"
$ClientLoaderPath = Join-Path $EcsrApp "Platform\FishingDemo.client.luau"
if (-not (Test-Path -LiteralPath $PresentationPath) -or -not (Test-Path -LiteralPath $ClientLoaderPath)) {
    Fail "presentation module or client loader is missing"
}

$PresentationText = Get-Content -Raw -LiteralPath $PresentationPath
foreach ($Marker in @(
    'PresentationRoot',
    'ObjectiveRail',
    'MiniMap',
    'CatchReveal',
    'TweenService',
    'ECSRFishingEffects',
    'createFishModel',
    'createCatchHaul',
    'createIceBreakBurst',
    'createSinkingIce',
    'createWaterRipple',
    'createSplashDroplets',
    'showCatchReveal'
)) {
    if (-not $PresentationText.Contains($Marker)) {
        Fail "showcase presentation is missing $Marker"
    }
}
if ($PresentationText -match 'FrameworkRule|StateUpdateRule|\b(?:world|_world):') {
    Fail "presentation layer contains ECSR business authority"
}

$ServerAdapterPath = Join-Path $EcsrApp "Platform\FishingDemo.server.luau"
$ServerAdapterText = Get-Content -Raw -LiteralPath $ServerAdapterPath
if (-not $ServerAdapterText.Contains('Players.CharacterAutoLoads = false')) {
    Fail "the vessel-only presentation must disable Roblox character auto-loading"
}
if (-not $ServerAdapterText.Contains('suppressCharacter(player)')) {
    Fail "the platform adapter must remove an already-created character"
}

$EcsrStatus = git -C (Join-Path $Repository "vendor\ECSR") status --porcelain
if ($LASTEXITCODE -ne 0) {
    Fail "unable to inspect the ECSR submodule"
}
if ($EcsrStatus) {
    Fail "vendor/ECSR must remain an unmodified dependency"
}

Write-Host "[ECSR Fishing Conformance] PASS - framework pin, domain ontology and presentation authority are closed"

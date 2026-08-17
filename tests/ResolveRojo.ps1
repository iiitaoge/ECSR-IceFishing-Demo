param(
    [Parameter(Mandatory = $true)]
    [string]$Repository
)

$ErrorActionPreference = "Stop"
$Version = "7.7.0"
$ToolRoot = Join-Path $Repository "build\tools\rojo-$Version"
$Executable = Join-Path $ToolRoot "rojo.exe"
if (Test-Path -LiteralPath $Executable) {
    return $Executable
}

$ArchiveRoot = Join-Path $Repository "build\tools"
$Archive = Join-Path $ArchiveRoot "rojo-$Version-windows-x86_64.zip"
New-Item -ItemType Directory -Path $ArchiveRoot -Force | Out-Null

if (-not (Test-Path -LiteralPath $Archive)) {
    $Uri = "https://github.com/rojo-rbx/rojo/releases/download/v$Version/rojo-$Version-windows-x86_64.zip"
    Write-Host "[Tools] Downloading Rojo $Version"
    Invoke-WebRequest -Uri $Uri -OutFile $Archive
}

New-Item -ItemType Directory -Path $ToolRoot -Force | Out-Null
Expand-Archive -LiteralPath $Archive -DestinationPath $ToolRoot -Force
if (-not (Test-Path -LiteralPath $Executable)) {
    $Resolved = Get-ChildItem -LiteralPath $ToolRoot -Filter "rojo.exe" -File -Recurse | Select-Object -First 1
    if ($null -eq $Resolved) {
        throw "Rojo $Version archive did not contain rojo.exe"
    }
    $Executable = $Resolved.FullName
}

return $Executable

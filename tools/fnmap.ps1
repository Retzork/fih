# fnmap.ps1 - batch function-dossier collector for REA (Phase 2 helper).
# Usage (from project root):
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\fnmap.ps1 -Map <map.txt> [-Out <dossiers.json>] [-Merge] [-Refresh]
# Map file: one entry per line, "0xADDRESS Name" (3rd+ tokens = optional note). "#" comments. UTF-8.
# Output: docs\analysis\fnmap\<map-basename>.json (merged by default; -Refresh re-queries all).
# Requires tools\rea.ps1 and the shared snapshot; each new function costs one Ghidra query.

param(
    [Parameter(Mandatory = $true)][string]$Map,
    [string]$Exe = "C:\Games\Steam\steamapps\common\Insaniquarium Deluxe\Insaniquarium.exe",
    [string]$Snapshot = "docs\analysis\snapshots\insaniquarium.json",
    [string]$Out,
    [switch]$Refresh
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not $Out) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Map)
    $dir = Join-Path $root "docs\analysis\fnmap"
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $Out = Join-Path $dir "$base.json"
}

$entries = @()
foreach ($line in Get-Content -LiteralPath $Map) {
    $line = $line.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { continue }
    $t = $line -split '\s+', 3
    if ($t.Count -lt 2 -or $t[0] -notmatch '^0x[0-9a-fA-F]+$') {
        Write-Warning "skipping malformed line: $line"; continue
    }
    $entries += [pscustomobject]@{ addr = $t[0].ToLower(); name = $t[1]; note = if ($t.Count -ge 3) { $t[2] } else { "" } }
}

$existing = @{}
if (-not $Refresh -and (Test-Path -LiteralPath $Out)) {
    $old = Get-Content -LiteralPath $Out -Raw | ConvertFrom-Json
    foreach ($f in $old.functions) { $existing[$f.address] = $f }
}

$results = @()
foreach ($e in $entries) {
    if ($existing.ContainsKey($e.addr)) {
        Write-Host ("cached   {0} {1}" -f $e.addr, $e.name)
        $f = $existing[$e.addr]
        $f.name = $e.name; $f.note = $e.note
        $results += $f
        continue
    }
    Write-Host ("querying {0} {1}" -f $e.addr, $e.name)
    $tmp = Join-Path $env:TEMP ("fnmap-{0}.json" -f ($e.addr -replace '^0x',''))
    & (Join-Path $root "tools\rea.ps1") function $Exe $e.addr --provider ghidra --json --snapshot $Snapshot > $tmp
    if ($LASTEXITCODE -ne 0) { Write-Warning ("query failed for {0}" -f $e.addr); continue }
    $j = (Get-Content -LiteralPath $tmp -Raw | ConvertFrom-Json).normalized_result
    $results += [pscustomobject]@{
        address  = $e.addr
        name     = $e.name
        note     = $e.note
        procName = $j.procedure.name
        range    = if ($j.procedure.body.ranges) { "{0}-{1}" -f $j.procedure.body.ranges[0].start, $j.procedure.body.ranges[0].end } else { "" }
        signature = $j.signature
        callers  = @($j.callers | ForEach-Object { $_.address })
        callees  = @($j.callees | ForEach-Object { $_.address })
        pseudocode = $j.pseudocode
        assembly = $j.assembly
    }
    Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
}

[pscustomobject]@{ map = (Resolve-Path -LiteralPath $Map).Path; exe = $Exe; generated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"); functions = $results } |
    ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Out -Encoding UTF8
Write-Host ("wrote {0} function entries to {1}" -f $results.Count, $Out)

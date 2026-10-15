# extract-game-module.ps1 - carve the embedded game module out of the canonical exe (read-only).
# Usage: powershell -File tools\extract-game-module.ps1 [-Exe <path>] [-OutDir <dir>]
# The Steam exe carries a '!popcapdrmprotect!' stub followed by a full PE32 image
# (the actual game module, ImageBase 0x400000). This script verifies the stub and the
# embedded PE header, then writes the carved image next to a SHA-256 identity report.
# Evidence use: output binary + hashes are deterministic regenerations of the canonical target.

param(
    [string]$Exe = "C:\Games\Steam\steamapps\common\Insaniquarium Deluxe\Insaniquarium.exe",
    [string]$OutDir = "docs\analysis\snapshots"
)

$ErrorActionPreference = "Stop"

$bytes = [IO.File]::ReadAllBytes($Exe)
$marker = [Text.Encoding]::ASCII.GetBytes("!popcapdrmprotect!")
$searchStart = 0x100000
$markerOff = -1
for ($i = $searchStart; $i -le ($bytes.Length - $marker.Length); $i++) {
    if ($bytes[$i] -eq $marker[0] -and $bytes[$i + 13] -eq $marker[13]) {
        $ok = $true
        for ($j = 0; $j -lt $marker.Length; $j++) {
            if ($bytes[$i + $j] -ne $marker[$j]) { $ok = $false; break }
        }
        if ($ok) { $markerOff = $i; break }
    }
}
if ($markerOff -lt 0) { throw "popcapdrmprotect marker not found (search from 0x$($searchStart.ToString('x')))" }

$mzOff = -1
for ($i = $markerOff + $marker.Length; $i -lt ($markerOff + 0x1000); $i++) {
    if ($bytes[$i] -eq 0x4D -and $bytes[$i + 1] -eq 0x5A) {
        $lf = [BitConverter]::ToInt32($bytes, $i + 0x3C)
        if ($lf -gt 0 -and $lf -lt 0x1000) {
            $sig = [Text.Encoding]::ASCII.GetString($bytes, $i + $lf, 4)
            if ($sig -eq "PE`0`0") { $mzOff = $i; break }
        }
    }
}
if ($mzOff -lt 0) { throw "embedded PE not found after marker at 0x$($markerOff.ToString('x'))" }

$pe = $mzOff + [BitConverter]::ToInt32($bytes, $mzOff + 0x3C)
$magic = [BitConverter]::ToUInt16($bytes, $pe + 24)
if ($magic -ne 0x10b) { throw "embedded image is not PE32 (magic 0x$($magic.ToString('x')))" }
$nSects = [BitConverter]::ToUInt16($bytes, $pe + 6)
$sizeOpt = [BitConverter]::ToUInt16($bytes, $pe + 20)
$entry = [BitConverter]::ToUInt32($bytes, $pe + 24 + 16)
$base = [BitConverter]::ToUInt32($bytes, $pe + 24 + 28)

$moduleSize = $bytes.Length - $mzOff
$module = New-Object byte[] $moduleSize
[Array]::Copy($bytes, $mzOff, $module, 0, $moduleSize)
$sha = [Security.Cryptography.SHA256]::Create().ComputeHash($module)
$shaHex = ($sha | ForEach-Object { $_.ToString("x2") }) -join ''

if (-not [IO.Directory]::Exists($OutDir)) { [IO.Directory]::CreateDirectory($OutDir) | Out-Null }
$outPath = Join-Path $OutDir "insaniquarium-game-module.exe"

"source:        $Exe"
"marker offset: 0x$($markerOff.ToString('x'))"
"module offset: 0x$($mzOff.ToString('x'))"
"module size:   $moduleSize bytes"
"sha256:        $shaHex"
"entry point:   0x$($entry.ToString('x'))  image base: 0x$($base.ToString('x'))"

$st = $pe + 24 + $sizeOpt
for ($i = 0; $i -lt $nSects; $i++) {
    $e = $st + $i * 40
    $name = [Text.Encoding]::ASCII.GetString($bytes, $e, 8).TrimEnd([char]0)
    $vs = [BitConverter]::ToUInt32($bytes, $e + 8)
    $va = [BitConverter]::ToUInt32($bytes, $e + 12)
    $rawSize = [BitConverter]::ToUInt32($bytes, $e + 16)
    $rawPtr = [BitConverter]::ToUInt32($bytes, $e + 20)
    "section $name VA=0x$($va.ToString('x8')) VSize=0x$($vs.ToString('x8')) RawPtr=0x$($rawPtr.ToString('x8')) RawSize=0x$($rawSize.ToString('x8'))"
}

if ([IO.File]::Exists($outPath)) {
    $existing = [Security.Cryptography.SHA256]::Create().ComputeHash([IO.File]::ReadAllBytes($outPath))
    $existingHex = ($existing | ForEach-Object { $_.ToString("x2") }) -join ''
    if ($existingHex -eq $shaHex) {
        "output already current: $outPath"
        exit 0
    }
}
[IO.File]::WriteAllBytes($outPath, $module)
"wrote: $outPath"

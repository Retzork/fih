# rtti-classmap.ps1 - recover MSVC RTTI class -> vtable -> slot map from a PE32 image (read-only).
# Usage: powershell -File tools\rtti-classmap.ps1 [-Module <path>] [-OutFile <path>]
# Chain: type name string -> RTTITypeDescriptor (name ptr) -> CompleteObjectLocator (descriptor ptr)
#        -> vtable (COL ptr at vtable[-4]) -> virtual function slot addresses.
# Multi-inheritance produces one row per complete-object locator. Evidence use: output rows are
# direct byte-level reads of the module file; confirm individual slots with REA function dossiers.

param(
    [string]$Module = "docs\analysis\snapshots\insaniquarium-game-module.exe",
    [string]$OutFile = "docs\evidence\p2.2-module-rtti-classes.txt"
)

$ErrorActionPreference = "Stop"
$bytes = [IO.File]::ReadAllBytes($Module)
function U32([int]$o) { return [BitConverter]::ToUInt32($bytes, $o) }

$pe = [int](U32 0x3C)
$nSects = [BitConverter]::ToUInt16($bytes, $pe + 6)
$sizeOpt = [BitConverter]::ToUInt16($bytes, $pe + 20)
$st = $pe + 24 + $sizeOpt
$sects = @()
for ($i = 0; $i -lt $nSects; $i++) {
    $e = $st + $i * 40
    $sects += [pscustomobject]@{
        Name = [Text.Encoding]::ASCII.GetString($bytes, $e, 8).TrimEnd([char]0)
        VSize = U32 ($e + 8); VA = U32 ($e + 12); RawSize = U32 ($e + 16); Raw = U32 ($e + 20)
    }
}
$imageBase = [BitConverter]::ToUInt32($bytes, $pe + 24 + 28)
$text = $sects | Where-Object { $_.Name -eq ".text" }
$textLo = $imageBase + $text.VA
$textHi = $imageBase + $text.VA + $text.VSize

function Off2Va([int]$o) {
    foreach ($s in $sects) {
        if ($o -ge $s.Raw -and $o -lt ($s.Raw + $s.RawSize)) { return $imageBase + $s.VA + ($o - $s.Raw) }
    }
    return $null
}

$enc = [Text.Encoding]::ASCII
$nameRe = [regex]'\.\?A[VU][A-Za-z0-9_@?$<>:,\-\|\*\s]*'
$nameSet = @{}
$names = New-Object System.Collections.Generic.List[object]
$s = [Text.Encoding]::GetEncoding(28591).GetString($bytes)
foreach ($m in $nameRe.Matches($s)) {
    $va = Off2Va $m.Index
    if ($va -eq $null) { continue }
    $raw = $m.Value
    $pretty = ($raw -replace '^\.\?A[VU]', '' -replace '@@$', '') -replace '@', '::'
    $nameSet[[uint32]$va] = $pretty
    $names.Add([pscustomobject]@{ Off = $m.Index; VA = [uint32]$va; Pretty = $pretty })
}

$scanLimit = $bytes.Length - 4
$descHits = New-Object System.Collections.Generic.List[object]
foreach ($n in $names) {
    $d = $n.Off - 8
    if ($d -lt 0) { continue }
    $vf = U32 $d
    if ($vf -ge $imageBase -and $vf -lt ($imageBase + 0x300000)) {
        $descVa = Off2Va $d
        if ($descVa -ne $null) { $descHits.Add([pscustomobject]@{ Class = $n.Pretty; Desc = [uint32]$descVa }) }
    }
}
$descSet = @{}
foreach ($h in $descHits) { $descSet[$h.Desc] = $h.Class }

$colHits = New-Object System.Collections.Generic.List[object]
for ($o = 0; $o -le $scanLimit; $o += 4) {
    $v = U32 $o
    if ($descSet.ContainsKey($v)) {
        foreach ($delta in @(12, 8)) {
            $c = $o - $delta
            if ($c -lt 0) { continue }
            $colVa = Off2Va $c
            if ($colVa -ne $null) { $colHits.Add([pscustomobject]@{ Class = $descSet[$v]; Desc = $v; Col = [uint32]$colVa }) }
        }
    }
}
$colByVa = @{}
foreach ($h in $colHits) { $colByVa[$h.Col] = $h }

$rows = New-Object System.Collections.Generic.List[string]
$rows.Add("# RTTI class map for $Module")
$rows.Add("# classes: $($names.Count)  descriptors: $($descHits.Count)  locators: $($colHits.Count)")
$rows.Add("# class`tdesc_va`tcol_va`tvtable_va`tslots`tslot list")
$vtCount = 0
for ($o = 0; $o -le $scanLimit; $o += 4) {
    $v = U32 $o
    if ($colByVa.ContainsKey($v)) {
        $h = $colByVa[$v]
        $slotStart = $o + 4
        $vtVa = Off2Va $slotStart
        if ($vtVa -eq $null) { continue }
        $slots = New-Object System.Collections.Generic.List[string]
        while ($slots.Count -lt 64) {
            $so = $slotStart + 4 * $slots.Count
            if ($so + 4 -gt $bytes.Length) { break }
            $sv = U32 $so
            if ($sv -lt $textLo -or $sv -gt $textHi) { break }
            $slots.Add(("0x{0:X}" -f $sv))
        }
        if ($slots.Count -gt 0) {
            $vtCount++
            $rows.Add(("{0}`t0x{1:X}`t0x{2:X}`t0x{3:X}`t{4}`t{5}" -f $h.Class, $h.Desc, $h.Col, $vtVa, $slots.Count, ($slots -join ',')))
        }
    }
}
$rows.Add("# vtables recovered: $vtCount")
$rows | Set-Content $OutFile
"classes: $($names.Count)  descriptors: $($descHits.Count)  locators: $($colHits.Count)  vtables: $vtCount"
"wrote: $OutFile"

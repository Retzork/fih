# pe-imports.ps1 - engine-free PE32 import-table reader (read-only).
# Usage: powershell -File tools\pe-imports.ps1 "C:\path\to\target.exe"
# Prints: PE header facts, imported DLL names with function counts, full function lists.
# Evidence use: output is a direct read of the file's import directory (no disassembler).

param([Parameter(Mandatory = $true)][string]$Path)

$bytes = [IO.File]::ReadAllBytes($Path)
function U16($o) { [BitConverter]::ToUInt16($bytes, $o) }
function U32($o) { [BitConverter]::ToUInt32($bytes, $o) }

$pe = [int](U32 0x3C)
$machine = U16 ($pe + 4)
$nSects = U16 ($pe + 6)
$sizeOpt = U16 ($pe + 20)
$opt = $pe + 24
$magic = U16 $opt
if ($magic -ne 0x10b) { throw "not PE32 (magic 0x$($magic.ToString('x')))" }
$dd = $opt + 96
$impRva = U32 ($dd + 8)
$impSize = U32 ($dd + 12)
"pe_offset: 0x$($pe.ToString('x'))  machine: 0x$($machine.ToString('x'))  sections: $nSects  magic: 0x$($magic.ToString('x'))"
"import_directory rva: 0x$($impRva.ToString('x'))  size: $impSize"

$sects = @()
$st = $opt + $sizeOpt
for ($i = 0; $i -lt $nSects; $i++) {
    $e = $st + $i * 40
    $name = [Text.Encoding]::ASCII.GetString($bytes, $e, 8).TrimEnd([char]0)
    $vs = U32 ($e + 8); $va = U32 ($e + 12); $raw = U32 ($e + 20)
    $sects += [pscustomobject]@{ Name = $name; VA = $va; VS = $vs; RAW = $raw }
}

function RvaToOff([uint32]$rva) {
    foreach ($s in $sects) {
        $span = [Math]::Max([int64]$s.VS, [int64]$s.RAW)
        if ($rva -ge $s.VA -and $rva -lt ($s.VA + $span)) { return [int]($rva - $s.VA + $s.RAW) }
    }
    return -1
}

function ReadStr([uint32]$rva) {
    $o = RvaToOff $rva
    if ($o -lt 0) { return "<?rva:0x$($rva.ToString('x'))>" }
    $end = $o
    while ($end -lt $bytes.Length -and $bytes[$end] -ne 0) { $end++ }
    return [Text.Encoding]::ASCII.GetString($bytes, $o, $end - $o)
}

$o = RvaToOff $impRva
$results = @()
while ($true) {
    $oft = U32 $o; $nameRva = U32 ($o + 12); $ft = U32 ($o + 16)
    if ($oft -eq 0 -and $nameRva -eq 0 -and $ft -eq 0) { break }
    $dll = ReadStr $nameRva
    $funcs = @()
    $thunkRva = if ($oft -ne 0) { $oft } else { $ft }
    $to = RvaToOff $thunkRva
    while ($to -ge 0) {
        $t = U32 $to
        if ($t -eq 0) { break }
        if (($t -band 0x80000000) -ne 0) { $funcs += "ordinal:$($t -band 0xffff)" }
        else { $funcs += (ReadStr ($t + 2)) }
        $to += 4
    }
    $results += [pscustomobject]@{ DLL = $dll; Count = $funcs.Count; Functions = $funcs }
    $o += 20
}

""
"IMPORTED DLLs ($($results.Count)):"
$results | ForEach-Object { "{0}  ({1} functions)" -f $_.DLL, $_.Count }
""
foreach ($r in $results) {
    ""
    "== $($r.DLL) =="
    $r.Functions | Sort-Object | ForEach-Object { "  $_" }
}

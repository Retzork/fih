# extract-audio.ps1 - P3.6 sound extraction into assets_raw/sounds/ (read-only on the game).
# Usage (from project root):
#   powershell -File tools\extract-audio.ps1
# Inputs: docs\analysis\resources.json + the canonical install.
# Outputs:
#   assets_raw\sounds\<name>.ogg   - copied 1:1 (manifest-referenced)
#   assets_raw\sounds\<name>.wav   - .au sources decoded with ffmpeg (pcm_mulaw 8k mono -> pcm_s16le)
#   assets_raw\audio.json          - id -> file mapping + volume/alias + ffprobe verification
# Conversion command recorded per file; ffprobe must confirm decodability of every output.

param(
    [string]$Inventory = "docs\analysis\resources.json",
    [string]$AssetsRoot = "C:\Games\Steam\steamapps\common\Insaniquarium Deluxe",
    [string]$OutRoot = "assets_raw"
)

$ErrorActionPreference = "Stop"
$AssetsRoot = $AssetsRoot.TrimEnd('\')
$inv = Get-Content -LiteralPath $Inventory -Raw | ConvertFrom-Json

$outDir = Join-Path $OutRoot "sounds"
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

function Probe([string]$path) {
    $out = & ffprobe -v error -show_entries "stream=codec_name,sample_rate,channels" -show_entries "format=duration" -of default=noprint_wrappers=1 $path
    $h = @{}
    foreach ($line in $out) { $kv = $line -split '=', 2; if ($kv.Count -eq 2) { $h[$kv[0]] = $kv[1] } }
    return $h
}

$report = @()
$stats = @{ copied = 0; converted = 0; probeFailures = 0; bytesOut = 0 }

foreach ($g in $inv.groups) {
    foreach ($r in $g.resources) {
        if ($r.type -ne 'Sound' -or -not $r.file) { continue }
        $src = Join-Path $AssetsRoot $r.file
        $ext = [IO.Path]::GetExtension($r.file).ToLowerInvariant()
        $stem = [IO.Path]::GetFileNameWithoutExtension($r.file)
        $cmd = $null
        if ($ext -eq '.ogg') {
            $dstName = "$stem.ogg"
            $dst = Join-Path $outDir $dstName
            Copy-Item -LiteralPath $src -Destination $dst -Force
            $cmd = "copy"
            $stats.copied++
        }
        elseif ($ext -eq '.au') {
            $dstName = "$stem.wav"
            $dst = Join-Path $outDir $dstName
            $cmd = "ffmpeg -hide_banner -loglevel error -y -i `"$src`" -c:a pcm_s16le `"$dst`""
            & ffmpeg -hide_banner -loglevel error -y -i $src -c:a pcm_s16le $dst
            if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed for $src" }
            $stats.converted++
        }
        else {
            throw "unexpected sound extension: $($r.file)"
        }

        $probe = Probe $dst
        if (-not $probe.ContainsKey('codec_name')) { $stats.probeFailures++ }
        $len = (Get-Item -LiteralPath $dst).Length
        $stats.bytesOut += $len

        $attrs = @{}
        foreach ($p in $r.attrs.PSObject.Properties) { $attrs[$p.Name] = $p.Value }
        $report += [ordered]@{
            id = $r.id; group = $g.id; source = $r.file; output = "sounds\$dstName"
            conversion = $cmd; bytes = $len
            probe = [ordered]@{ codec = $probe['codec_name']; sampleRate = $probe['sample_rate']; channels = $probe['channels']; duration = $probe['duration'] }
            attrs = $attrs
        }
    }
}

$result = [ordered]@{
    generated = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    source = $Inventory
    stats = $stats
    sounds = $report
}
[IO.File]::WriteAllText((Join-Path (Get-Location) (Join-Path $OutRoot "audio.json")), ($result | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))

"ogg copied: $($stats.copied)"
"au converted: $($stats.converted)"
"probe failures: $($stats.probeFailures)"
"total output: {0:N1} MB" -f ($stats.bytesOut / 1MB)
"manifest: $OutRoot\audio.json"

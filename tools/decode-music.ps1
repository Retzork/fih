# decode-music.ps1 - P3.7 music extraction into assets_raw/music/ (read-only on the game).
# Usage (from project root):
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\decode-music.ps1
# Inputs: the canonical install's music\*.mo3 (unreferenced by the manifest, EV-0025).
# Outputs:
#   assets_raw\music\<name>.ogg - decoded by ffmpeg's libopenmpt demuxer, encoded libvorbis
#   assets_raw\music.json       - per-file source SHA-256 + ffprobe verification + exact command
# Tooling choice: docs\DECISIONS.md D-0006 (ffmpeg/libopenmpt; BASS P/Invoke route rejected).
# ffprobe must confirm decodability of every output; a probe miss is counted, not fatal.

param(
    [string]$MusicRoot = "C:\Games\Steam\steamapps\common\Insaniquarium Deluxe\music",
    [string]$OutRoot = "assets_raw",
    [string]$Quality = "5"
)

$ErrorActionPreference = "Stop"
$MusicRoot = $MusicRoot.TrimEnd('\')

$outDir = Join-Path $OutRoot "music"
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

function Probe([string]$path) {
    $out = & ffprobe -v error -show_entries "format=format_name,duration" -show_entries "stream=codec_name,sample_rate,channels" -show_entries "format_tags=title,encoder" -of default=noprint_wrappers=1 $path
    $h = @{}
    foreach ($line in $out) { $kv = $line -split '=', 2; if ($kv.Count -eq 2) { $h[$kv[0]] = $kv[1] } }
    return $h
}

$files = Get-ChildItem -LiteralPath $MusicRoot -Filter *.mo3 -File | Sort-Object Name
if ($files.Count -eq 0) { throw "no .mo3 files found in $MusicRoot" }

$report = @()
$stats = @{ decoded = 0; probeFailures = 0; bytesOut = 0 }

foreach ($f in $files) {
    $src = $f.FullName
    $stem = $f.BaseName
    $dst = Join-Path $outDir "$stem.ogg"

    $srcProbe = Probe $src
    $sha = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
    $srcBytes = $f.Length

    $cmd = "ffmpeg -hide_banner -loglevel error -y -i `"$src`" -c:a libvorbis -q:a $Quality `"$dst`""
    & ffmpeg -hide_banner -loglevel error -y -i $src -c:a libvorbis -q:a $Quality $dst
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed for $src" }
    $stats.decoded++

    $probe = Probe $dst
    if (-not $probe.ContainsKey('codec_name')) { $stats.probeFailures++ }
    $len = (Get-Item -LiteralPath $dst).Length
    $stats.bytesOut += $len

    $report += [ordered]@{
        file = "music\$($f.Name)"
        output = "music\$stem.ogg"
        sourceSha256 = $sha
        sourceBytes = $srcBytes
        source = [ordered]@{
            format = $srcProbe['format_name']; duration = $srcProbe['duration']
            title = $srcProbe['TAG:title']; encoder = $srcProbe['TAG:encoder']
        }
        conversion = $cmd
        bytes = $len
        probe = [ordered]@{
            codec = $probe['codec_name']; sampleRate = $probe['sample_rate']
            channels = $probe['channels']; duration = $probe['duration']
        }
    }
}

$result = [ordered]@{
    generated = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    source = $MusicRoot
    tool = "ffmpeg libopenmpt demuxer + libvorbis encoder"
    stats = $stats
    music = $report
}
[IO.File]::WriteAllText((Join-Path (Get-Location) (Join-Path $OutRoot "music.json")), ($result | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))

"mo3 decoded: $($stats.decoded)"
"probe failures: $($stats.probeFailures)"
"total output: {0:N1} MB" -f ($stats.bytesOut / 1MB)
"manifest: $OutRoot\music.json"

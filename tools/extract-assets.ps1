# extract-assets.ps1 - P3.3 image extraction into assets_raw/ (read-only on the game install).
# Usage (from project root):
#   powershell -File tools\extract-assets.ps1
# Inputs: docs\analysis\resources.json (parse-resources.ps1) and the canonical install.
# Outputs:
#   assets_raw\images\<name>.png        - every referenced base image, converted 1:1 (no compositing)
#   assets_raw\masks\<name>.png         - every referenced mask companion (grayscale layers)
#   assets_raw\frames\<ID>\fNNN.png     - per-cell crops for multi-cell grids (row-major order)
#   assets_raw\extraction.json          - what was written + grid provenance (declared|inferred)
# Grid rule: declared cols/rows from the manifest; for undeclared sheets of width 800 px with
# 80-px-divisible dims, grid = 10 x (height/80) is INFERRED (EV-0027) and tagged as such.

param(
    [string]$Inventory = "docs\analysis\resources.json",
    [string]$AssetsRoot = "C:\Games\Steam\steamapps\common\Insaniquarium Deluxe",
    [string]$OutRoot = "assets_raw"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$AssetsRoot = $AssetsRoot.TrimEnd('\')

$inv = Get-Content -LiteralPath $Inventory -Raw | ConvertFrom-Json
$imgDir = Join-Path $OutRoot "images"
$maskDir = Join-Path $OutRoot "masks"
$frameRoot = Join-Path $OutRoot "frames"
foreach ($d in @($imgDir, $maskDir, $frameRoot)) { if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }

function Convert-ToPng32([string]$srcPath, [string]$dstPath) {
    $img = [System.Drawing.Image]::FromFile($srcPath)
    $full = New-Object System.Drawing.Bitmap($img.Width, $img.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($full)
    $g.DrawImageUnscaled($img, 0, 0)
    $g.Dispose(); $img.Dispose()
    $dir = Split-Path $dstPath -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $full.Save($dstPath, [System.Drawing.Imaging.ImageFormat]::Png)
    return $full
}

function Save-Frame([System.Drawing.Bitmap]$full, [int]$x, [int]$y, [int]$cw, [int]$ch, [string]$dstPath) {
    $rect = New-Object System.Drawing.Rectangle $x, $y, $cw, $ch
    $bmp = $full.Clone($rect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bmp.Save($dstPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

$doneBase = @{}
$doneMask = @{}
$report = @()
$stats = @{ baseWritten = 0; maskWritten = 0; framesWritten = 0; sheetsSliced = 0; inferredGrids = 0 }

foreach ($g in $inv.groups) {
    foreach ($r in $g.resources) {
        if ($r.type -ne 'Image' -or -not $r.file) { continue }

        $id = $r.id
        $srcRel = $r.file
        $stem = [IO.Path]::GetFileNameWithoutExtension($srcRel)
        $pngRel = "images\$stem.png"
        $pngAbs = Join-Path $OutRoot $pngRel

        $full = $null
        if (-not $doneBase.ContainsKey($srcRel.ToLowerInvariant())) {
            $full = Convert-ToPng32 (Join-Path $AssetsRoot $srcRel) $pngAbs
            $doneBase[$srcRel.ToLowerInvariant()] = $true
            $stats.baseWritten++
        }

        # mask companion (explicit, or first candidate; self-masks are skipped)
        $maskSrcRel = $null
        $maskPngRel = $null
        $maskRole = $null
        if ($r.mask) { $maskSrcRel = $r.mask; $maskRole = if ($r.maskSource) { $r.maskSource } else { "candidate" } }
        elseif ($r.maskCandidates -and $r.maskCandidates.Count -gt 0) { $maskSrcRel = $r.maskCandidates[0]; $maskRole = "candidate" }
        $selfMask = $false
        if ($maskSrcRel -and ($maskSrcRel.ToLowerInvariant() -eq $srcRel.ToLowerInvariant())) {
            $selfMask = $true; $maskSrcRel = $null; $maskRole = $null
        }
        if ($maskSrcRel) {
            $maskStem = [IO.Path]::GetFileNameWithoutExtension($maskSrcRel)
            $maskPngRel = "masks\$maskStem.png"
            if (-not $doneMask.ContainsKey($maskSrcRel.ToLowerInvariant())) {
                $null = Convert-ToPng32 (Join-Path $AssetsRoot $maskSrcRel) (Join-Path $OutRoot $maskPngRel)
                $doneMask[$maskSrcRel.ToLowerInvariant()] = $true
                $stats.maskWritten++
            }
        }

        # grid: declared or inferred
        $cols = 1; $rows = 1; $gridSource = "declared"
        if ($r.frame -and $r.frame.count -gt 1) {
            $cols = [int]$r.frame.cols; $rows = [int]$r.frame.rows
        }
        elseif ((-not $r.frame -or $r.frame.count -eq 1) -and $r.width -eq 800 -and $r.width % 80 -eq 0 -and $r.height % 80 -eq 0 -and $r.height -gt 80) {
            $cols = 10; $rows = [int]($r.height / 80); $gridSource = "inferred"; $stats.inferredGrids++
        }
        $cw = [int]($r.width / $cols); $ch = [int]($r.height / $rows)

        $frames = @()
        if ($cols * $rows -gt 1) {
            if (-not $full) {
                $tmp = [System.Drawing.Image]::FromFile((Join-Path $AssetsRoot $srcRel))
                $full = New-Object System.Drawing.Bitmap($tmp.Width, $tmp.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
                $gg = [System.Drawing.Graphics]::FromImage($full)
                $gg.DrawImageUnscaled($tmp, 0, 0)
                $gg.Dispose(); $tmp.Dispose()
            }
            $idDir = Join-Path $frameRoot $id
            if (-not (Test-Path -LiteralPath $idDir)) { New-Item -ItemType Directory -Path $idDir | Out-Null }
            for ($row = 0; $row -lt $rows; $row++) {
                for ($col = 0; $col -lt $cols; $col++) {
                    $fname = "f{0:D3}.png" -f ($row * $cols + $col)
                    $frel = "frames\$id\$fname"
                    Save-Frame $full ($col * $cw) ($row * $ch) $cw $ch (Join-Path $OutRoot $frel)
                    $frames += $frel
                    $stats.framesWritten++
                }
            }
            $stats.sheetsSliced++
        }
        if ($full) { $full.Dispose() }

        $attrs = @{}
        foreach ($p in $r.attrs.PSObject.Properties) { $attrs[$p.Name] = $p.Value }

        $report += [ordered]@{
            id = $id; group = $g.id; source = $srcRel; png = $pngRel
            maskSource = $maskSrcRel; maskPng = $maskPngRel; maskRole = $maskRole; selfMask = $selfMask
            resolvedVia = $r.resolvedVia
            w = $r.width; h = $r.height; cols = $cols; rows = $rows; cellW = $cw; cellH = $ch
            gridSource = $gridSource; frames = $frames; attrs = $attrs
        }
    }
}

# frames/ is a verification/debug artifact; the Godot project uses sheet PNGs + AtlasTexture
# regions (tools\godot\gen_spriteframes.gd), so keep Godot from importing 3k redundant PNGs.
[IO.File]::WriteAllText((Join-Path $OutRoot "frames\.gdignore"), "", (New-Object Text.UTF8Encoding $false))

$result = [ordered]@{
    generated = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    source = $Inventory
    stats = $stats
    images = $report
}
[IO.File]::WriteAllText((Join-Path (Get-Location) (Join-Path $OutRoot "extraction.json")), ($result | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding $false))

"base PNGs written: $($stats.baseWritten)"
"mask PNGs written: $($stats.maskWritten)"
"sheets sliced: $($stats.sheetsSliced) (frames: $($stats.framesWritten); inferred grids: $($stats.inferredGrids))"
"extraction manifest: $OutRoot\extraction.json"

# inspect-images.ps1 - per-image geometry and layer classification (read-only, P3.2).
# Usage (from project root):
#   powershell -File tools\inspect-images.ps1
# Inputs: docs\analysis\resources.json (from parse-resources.ps1).
# Outputs: docs\analysis\p3.2-image-report.json + console summary.
# Measures: dims, declared grid (cols/rows from manifest), mask companion dims/grayscale,
# pixel stats (grayscale vs color, zero-alpha count). Nothing here proves engine behavior.

param(
    [string]$Inventory = "docs\analysis\resources.json",
    [string]$AssetsRoot = "C:\Games\Steam\steamapps\common\Insaniquarium Deluxe",
    [string]$Out = "docs\analysis\p3.2-image-report.json"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$AssetsRoot = $AssetsRoot.TrimEnd('\')

$inv = Get-Content -LiteralPath $Inventory -Raw | ConvertFrom-Json

function Get-PixelStats([string]$absPath) {
    $img = [System.Drawing.Image]::FromFile($absPath)
    $bmp = New-Object System.Drawing.Bitmap $img
    $img.Dispose()
    $rect = New-Object System.Drawing.Rectangle 0, 0, $bmp.Width, $bmp.Height
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $bytes = New-Object byte[] ($data.Stride * $data.Height)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
    $stride = $data.Stride; $w = $data.Width; $h = $data.Height
    $bmp.UnlockBits($data); $bmp.Dispose()

    $gray = 0; $colour = 0; $alphaZero = 0
    $minL = 255; $maxL = 0; $sumL = 0.0
    for ($y = 0; $y -lt $h; $y++) {
        $row = $y * $stride
        for ($x = 0; $x -lt $w; $x++) {
            $i = $row + $x * 4
            $b = $bytes[$i]; $g = $bytes[$i + 1]; $r = $bytes[$i + 2]; $a = $bytes[$i + 3]
            if ($a -eq 0) { $alphaZero++; continue }
            if ($r -eq $g -and $g -eq $b) { $gray++ } else { $colour++ }
            $l = ($r + $g + $b) / 3.0
            if ($l -lt $minL) { $minL = $l }
            if ($l -gt $maxL) { $maxL = $l }
            $sumL += $l
        }
    }
    $opaque = $gray + $colour
    return @{
        gray = $gray; colour = $colour; alphaZero = $alphaZero
        minL = [math]::Round($minL, 1); maxL = [math]::Round($maxL, 1)
        meanL = if ($opaque -gt 0) { [math]::Round($sumL / $opaque, 1) } else { $null }
        colorRatio = if ($opaque -gt 0) { [math]::Round($colour / $opaque, 4) } else { 0 }
    }
}

$rows = @()
foreach ($g in $inv.groups) {
    foreach ($r in $g.resources) {
        if ($r.type -ne 'Image' -or -not $r.file) { continue }
        $abs = Join-Path $AssetsRoot $r.file
        $ps = Get-PixelStats $abs

        $maskPath = $null
        if ($r.mask) { $maskPath = $r.mask }
        elseif ($r.maskCandidates -and $r.maskCandidates.Count -gt 0) { $maskPath = $r.maskCandidates[0] }

        $maskInfo = $null
        if ($maskPath) {
            $maskAbs = Join-Path $AssetsRoot $maskPath
            $mimg = [System.Drawing.Image]::FromFile($maskAbs)
            $mw = $mimg.Width; $mh = $mimg.Height
            $mimg.Dispose()
            $mps = Get-PixelStats $maskAbs
            $maskInfo = @{
                file = $maskPath; w = $mw; h = $mh
                allGray = ($mps.colour -eq 0)
                minL = $mps.minL; maxL = $mps.maxL; meanL = $mps.meanL
                dimsMatch = ($mw -eq $r.width -and $mh -eq $r.height)
                alphaZero = $mps.alphaZero
            }
        }

        $declCols = if ($r.frame) { $r.frame.cols } else { 1 }
        $declRows = if ($r.frame) { $r.frame.rows } else { 1 }
        $flags = @()
        if ($ps.alphaZero -gt 0 -and -not $maskPath) { $flags += 'base-has-alpha' }
        if ($ps.colorRatio -lt 0.01) { $flags += 'grayscale-only' }
        if ($declCols -eq 1 -and $declRows -eq 1 -and $r.width -ge 160 -and $r.height -ge 160) { $flags += 'undocumented-multicell' }
        if ($maskInfo -and -not $maskInfo.dimsMatch) { $flags += 'mask-dims-mismatch' }
        if ($maskInfo -and -not $maskInfo.allGray) { $flags += 'mask-not-grayscale' }

        $rows += [ordered]@{
            id = $r.id; group = $r.group; file = $r.file; format = $r.format
            w = $r.width; h = $r.height
            declCols = $declCols; declRows = $declRows
            cellW = if ($r.frame) { $r.frame.cellW } else { $r.width }
            cellH = if ($r.frame) { $r.frame.cellH } else { $r.height }
            border = if ($r.attrs.framedelay -or $r.attrs.anim -or $r.attrs.framemap) { $true } else { $false }
            colorRatio = $ps.colorRatio
            gray = $ps.gray; colour = $ps.colour; alphaZero = $ps.alphaZero
            meanL = $ps.meanL
            mask = $maskInfo
            maskSource = $r.maskSource
            resolvedVia = $r.resolvedVia
            flags = $flags
        }
    }
}

$summary = [ordered]@{
    images = $rows.Count
    withMask = @($rows | Where-Object { $_.mask }).Count
    explicitMask = @($rows | Where-Object { $_.maskSource }).Count
    candidatesOnly = @($rows | Where-Object { $_.mask -and -not $_.maskSource }).Count
    grayscaleOnly = @($rows | Where-Object { $_.flags -contains 'grayscale-only' }).Count
    baseHasAlpha = @($rows | Where-Object { $_.alphaZero -gt 0 }).Count
    maskDimsMismatch = @($rows | Where-Object { $_.flags -contains 'mask-dims-mismatch' }).Count
    maskNotGrayscale = @($rows | Where-Object { $_.flags -contains 'mask-not-grayscale' }).Count
    undocumentedMulticell = @($rows | Where-Object { $_.flags -contains 'undocumented-multicell' }).Count
}

$result = [ordered]@{
    generated = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    source = $Inventory
    summary = $summary
    images = $rows
}
[IO.File]::WriteAllText((Join-Path (Get-Location) $Out), ($result | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))

"images measured: $($summary.images)"
"with mask: $($summary.withMask) (explicit $($summary.explicitMask), candidate-only $($summary.candidatesOnly))"
"grayscale-only base images: $($summary.grayscaleOnly)"
"base images with zero-alpha pixels: $($summary.baseHasAlpha)"
"mask dims != base dims: $($summary.maskDimsMismatch)"
"masks with non-gray pixels: $($summary.maskNotGrayscale)"
"undocumented multicell candidates: $($summary.undocumentedMulticell)"
""
"-- mask dims mismatch --"
$rows | Where-Object { $_.flags -contains 'mask-dims-mismatch' } | ForEach-Object { "{0,-22} {1}x{2}  mask {3} {4}x{5}" -f $_.id, $_.w, $_.h, (Split-Path $_.mask.file -Leaf), $_.mask.w, $_.mask.h }
""
"-- grayscale-only base images --"
$rows | Where-Object { $_.flags -contains 'grayscale-only' } | ForEach-Object { "{0,-22} {1}x{2} decl {3}x{4} cell {5}x{6} mask={7}" -f $_.id, $_.w, $_.h, $_.declCols, $_.declRows, $_.cellW, $_.cellH, ($_.mask.file) }
""
"-- undocumented multicell candidates --"
$rows | Where-Object { $_.flags -contains 'undocumented-multicell' } | ForEach-Object { "{0,-22} {1}x{2} mask={3}" -f $_.id, $_.w, $_.h, ($_.mask.file) }
""
"written: $Out"

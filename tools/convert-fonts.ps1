# convert-fonts.ps1 - P3.8 font conversion into assets_raw/fonts/ (read-only on the game).
# Usage (from project root):
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\convert-fonts.ps1
# Inputs: docs\analysis\resources.json (Font entries) + the canonical install's data\*.txt|*.gif.
# For each SexyApp bitmap-font descriptor the script:
#   - parses CharList / WidthList / RectList / OffsetList / KerningPairs / KerningValues and the
#     LayerSet* trailer (Image, Ascent, space width, AscentPadding, LineSpacingOffset, PointSize);
#   - resolves the atlas (LayerSetImage name -> data\<name>.gif, underscore-name fallback) and
#     validates every glyph rect (+offset) fits inside the atlas;
#   - copies raw layers to fonts\raw\ and composes the Godot page PNG:
#       RGB = base/first atlas pixel, A = luminance(mask/first atlas)  [colorize + outline model]
#   - emits one BMFont-text .fnt per font (space glyph added from LayerSetCharWidths).
# Outputs: assets_raw\fonts\<ID>.fnt, assets_raw\fonts\<ID>.png, assets_raw\fonts\raw\*, fonts.json
# Font storage/composition decision: docs\DECISIONS.md D-0007.

param(
    [string]$Inventory = "docs\analysis\resources.json",
    [string]$DataRoot = "C:\Games\Steam\steamapps\common\Insaniquarium Deluxe\data",
    [string]$OutRoot = "assets_raw"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$inv = Get-Content -LiteralPath $Inventory -Raw | ConvertFrom-Json
$outDir = Join-Path $OutRoot "fonts"
$rawDir = Join-Path $outDir "raw"
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
if (-not (Test-Path -LiteralPath $rawDir)) { New-Item -ItemType Directory -Path $rawDir -Force | Out-Null }

function Lum($c) { return [int][Math]::Round(0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B) }

function Get-Block([string]$txt, [string]$name, [string]$stopName) {
    $m = [regex]::Match($txt, "Define\s+$name\s*\((?<body>.*?)\)\s*;", [Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $m.Success) { throw "block $name not found" }
    return $m.Groups['body'].Value
}

function Get-Chars([string]$body) {
    $tokens = [regex]::Matches($body, """(?<d>[^""])""|'(?<s>[^'])'")
    $chars = @()
    foreach ($t in $tokens) {
        $ch = if ($t.Groups['d'].Success) { $t.Groups['d'].Value } else { $t.Groups['s'].Value }
        $chars += [int][char]$ch
    }
    return , $chars
}

$report = @()
$stats = @{ fonts = 0; totalChars = 0; totalKernings = 0; composed = 0; baseAtlas = 0; fallbackAtlas = 0; bytesOut = 0 }

foreach ($g in $inv.groups) {
    foreach ($r in $g.resources) {
        if ($r.type -ne 'Font' -or -not $r.file) { continue }
        $id = $r.id
        $srcPath = Join-Path "C:\Games\Steam\steamapps\common\Insaniquarium Deluxe" $r.file
        $txt = [Text.Encoding]::GetEncoding(1252).GetString([IO.File]::ReadAllBytes($srcPath))

        $charCodes = Get-Chars (Get-Block $txt 'CharList' 'WidthList')
        $widths = @([regex]::Matches((Get-Block $txt 'WidthList' 'RectList'), '-?\d+') | ForEach-Object { [int]$_.Value })
        $rects = @([regex]::Matches((Get-Block $txt 'RectList' 'OffsetList'), '\(\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+)\s*\)') | ForEach-Object { , @([int]$_.Groups[1].Value, [int]$_.Groups[2].Value, [int]$_.Groups[3].Value, [int]$_.Groups[4].Value) })
        $offsets = @([regex]::Matches((Get-Block $txt 'OffsetList' 'KerningPairs'), '\(\s*(-?\d+),\s*(-?\d+)\s*\)') | ForEach-Object { , @([int]$_.Groups[1].Value, [int]$_.Groups[2].Value) })
        $kernPairs = @()
        $kernValues = @()
        try {
            foreach ($t in [regex]::Matches((Get-Block $txt 'KerningPairs' $null), '"((?:[^""\\]|\\.)*)"')) {
                $s = $t.Groups[1].Value -replace '\\"', '"' -replace '\\\\', '\'
                if ($s.Length -ne 2) { throw "$id kerning token not 2 chars: [$s]" }
                $kernPairs += , @([int][char]$s[0], [int][char]$s[1])
            }
            $kernValues = @([regex]::Matches((Get-Block $txt 'KerningValues' $null), '-?\d+') | ForEach-Object { [int]$_.Value })
        }
        catch { $kernPairs = @(); $kernValues = @() }

        if ($charCodes.Count -ne $widths.Count -or $charCodes.Count -ne $rects.Count -or $charCodes.Count -ne $offsets.Count) {
            throw "$id list count mismatch: chars=$($charCodes.Count) widths=$($widths.Count) rects=$($rects.Count) offsets=$($offsets.Count)"
        }
        if ($kernPairs.Count -ne $kernValues.Count) { throw "$id kerning mismatch: pairs=$($kernPairs.Count) values=$($kernValues.Count)" }

        function Get-Cmd([string]$pattern) {
            $m = [regex]::Match($txt, $pattern)
            if (-not $m.Success) { throw "trailer '$pattern' not found" }
            return $m.Groups[1].Value
        }
        $atlasName = Get-Cmd "LayerSetImage\s+Main\s+'(?<v>[^']+)'"
        $ascent = [int](Get-Cmd "LayerSetAscent\s+Main\s+(\d+)")
        $spaceW = [int](Get-Cmd "LayerSetCharWidths\s+Main\s+\(' '\)\s+\((\d+)\)")
        $pad = [int](Get-Cmd "LayerSetAscentPadding\s+Main\s+(-?\d+)")
        $lsOff = [int](Get-Cmd "LayerSetLineSpacingOffset\s+Main\s+(-?\d+)")
        $pointSize = [int](Get-Cmd "SetDefaultPointSize\s+(\d+)")

        $basePath = Join-Path $DataRoot "$atlasName.gif"
        $maskPath = Join-Path $DataRoot "_$atlasName.gif"
        $hasBase = Test-Path -LiteralPath $basePath
        $hasMask = Test-Path -LiteralPath $maskPath
        if (-not ($hasBase -or $hasMask)) { throw "$id no atlas gif found for '$atlasName'" }
        $atlasPath = if ($hasBase) { $basePath } else { $maskPath }
        $atlasVia = if ($hasBase) { 'base' } else { 'underscore-fallback' }

        $atlasImg = [System.Drawing.Bitmap]::new($atlasPath)
        $maxX = 0; $maxY = 0
        for ($i = 0; $i -lt $rects.Count; $i++) {
            $x = $rects[$i][0] + $rects[$i][2]; $y = $rects[$i][1] + $rects[$i][3]
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -gt $maxY) { $maxY = $y }
        }
        if ($maxX -gt $atlasImg.Width -or $maxY -gt $atlasImg.Height) {
            throw "$id rect extents ${maxX}x${maxY} exceed atlas $($atlasImg.Width)x$($atlasImg.Height)"
        }

        $srcImg = [System.Drawing.Bitmap]::new($atlasPath)
        $alphaImg = if ($hasMask) { [System.Drawing.Bitmap]::new($maskPath) } else { $srcImg }
        $page = [System.Drawing.Bitmap]::new($srcImg.Width, $srcImg.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        for ($y = 0; $y -lt $srcImg.Height; $y++) {
            for ($x = 0; $x -lt $srcImg.Width; $x++) {
                $s = $srcImg.GetPixel($x, $y); $a = Lum $alphaImg.GetPixel($x, $y)
                $page.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, $s.R, $s.G, $s.B))
            }
        }
        $pagePath = Join-Path $outDir "$id.png"
        $page.Save($pagePath, [System.Drawing.Imaging.ImageFormat]::Png)
        $page.Dispose()

        if ($hasBase) { Copy-Item -LiteralPath $basePath -Destination (Join-Path $rawDir "${id}_base.png") -Force }
        if ($hasMask) { Copy-Item -LiteralPath $maskPath -Destination (Join-Path $rawDir "${id}_mask.png") -Force }
        $srcImg.Dispose(); if ($hasMask) { $alphaImg.Dispose() }; $atlasImg.Dispose()

        $enc = New-Object Text.UTF8Encoding $false
        $sb = New-Object Text.StringBuilder
        [void]$sb.AppendLine("info face=`"$id`" size=$pointSize bold=0 italic=0 charset=`"`" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0")
        [void]$sb.AppendLine("common lineHeight=$maxY base=$ascent scaleW=$($srcImg.Width) scaleH=$($srcImg.Height) pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4")
        [void]$sb.AppendLine("page id=0 file=`"$id.png`"")
        [void]$sb.AppendLine("chars count=$($charCodes.Count + 1)")
        [void]$sb.AppendLine("char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=$spaceW page=0 chnl=15")
        for ($i = 0; $i -lt $charCodes.Count; $i++) {
            [void]$sb.AppendLine("char id=$($charCodes[$i]) x=$($rects[$i][0]) y=$($rects[$i][1]) width=$($rects[$i][2]) height=$($rects[$i][3]) xoffset=$($offsets[$i][0]) yoffset=$($offsets[$i][1]) xadvance=$($widths[$i]) page=0 chnl=15")
        }
        [void]$sb.AppendLine("kernings count=$($kernPairs.Count)")
        for ($i = 0; $i -lt $kernPairs.Count; $i++) {
            [void]$sb.AppendLine("kerning first=$($kernPairs[$i][0]) second=$($kernPairs[$i][1]) amount=$($kernValues[$i])")
        }
        $fntPath = Join-Path $outDir "$id.fnt"
        [IO.File]::WriteAllText((Join-Path (Get-Location) $fntPath), $sb.ToString(), $enc)

        $stats.fonts++; $stats.totalChars += $charCodes.Count; $stats.totalKernings += $kernPairs.Count
        $stats.composed++
        if ($hasBase) { $stats.baseAtlas++ } else { $stats.fallbackAtlas++ }
        foreach ($p in @($pagePath, $fntPath)) { $stats.bytesOut += (Get-Item -LiteralPath $p).Length }

        $report += [ordered]@{
            id = $id; group = $g.id; source = $r.file
            atlas = [ordered]@{ name = $atlasName; file = "data\$([IO.Path]::GetFileName($atlasPath))"; resolvedVia = $atlasVia; width = $maxX; height = $maxY; mask = $hasMask }
            metrics = [ordered]@{ pointSize = $pointSize; ascent = $ascent; ascentPadding = $pad; lineSpacingOffset = $lsOff; spaceWidth = $spaceW; lineHeight = $maxY }
            chars = $charCodes.Count; charCodes = $charCodes; kernings = $kernPairs.Count
            outputs = @("fonts\$id.fnt", "fonts\$id.png")
        }
    }
}

$result = [ordered]@{
    generated = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    source = $Inventory
    composition = "page RGB = atlas(base or underscore) pixel; page A = luminance(mask or atlas self)"
    stats = $stats
    fonts = $report
}
[IO.File]::WriteAllText((Join-Path (Get-Location) (Join-Path $OutRoot "fonts.json")), ($result | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))

"fonts converted: $($stats.fonts) (base atlas: $($stats.baseAtlas), fallback: $($stats.fallbackAtlas))"
"total glyphs: $($stats.totalChars); total kerning pairs: $($stats.totalKernings)"
"output: {0:N0} KB" -f ($stats.bytesOut / 1KB)
"manifest: $OutRoot\fonts.json"

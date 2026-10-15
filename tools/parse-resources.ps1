# parse-resources.ps1 - engine-free parser for properties\resources.xml (read-only).
# Usage (from project root):
#   powershell -File tools\parse-resources.ps1
#   powershell -File tools\parse-resources.ps1 -Manifest <path> -AssetsRoot <path> -Out <path>
# Output: machine-readable inventory JSON (default docs\analysis\resources.json).
# Resolution is case-insensitive (install ships mixed-case names, e.g. Aquarium5.jpg).
# Mask handling: explicit alphaimage/alphagrid attributes are resolved; otherwise
# leading-underscore and trailing-underscore candidates are only *recorded*, not assumed.

param(
    [string]$Manifest = "C:\Games\Steam\steamapps\common\Insaniquarium Deluxe\properties\resources.xml",
    [string]$AssetsRoot = "C:\Games\Steam\steamapps\common\Insaniquarium Deluxe",
    [string]$Out = "docs\analysis\resources.json"
)

$ErrorActionPreference = "Stop"
$AssetsRoot = $AssetsRoot.TrimEnd('\')

if (-not (Test-Path -LiteralPath $Manifest)) { throw "manifest not found: $Manifest" }
if (-not (Test-Path -LiteralPath $AssetsRoot)) { throw "assets root not found: $AssetsRoot" }

# --- file index (lowercase relative path -> actual relative path) ---
$index = @{}
Get-ChildItem -LiteralPath $AssetsRoot -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($AssetsRoot.Length + 1)
    $index[$rel.ToLowerInvariant()] = $rel
}

function Resolve-Asset([string]$dir, [string]$name) {
    # $name may or may not carry an extension; try as-is when it does, else probe extensions.
    $hasExt = $name -match '\.[A-Za-z0-9]+$'
    $exts = if ($hasExt) { @('') } else { @('.gif', '.jpg', '.png', '.ogg', '.au', '.wav') }
    foreach ($e in $exts) {
        $rel = if ($dir) { "$dir\$name$e" } else { "$name$e" }
        $hit = $index[$rel.ToLowerInvariant()]
        if ($hit) { return $hit }
    }
    return $null
}

$sizeCache = @{}
function Get-ImageSize([string]$absPath) {
    if ($sizeCache.ContainsKey($absPath)) { return $sizeCache[$absPath] }
    $b = [IO.File]::ReadAllBytes($absPath)
    $size = $null
    if ($b.Length -ge 10 -and $b[0] -eq 0x47 -and $b[1] -eq 0x49 -and $b[2] -eq 0x46 -and $b[3] -eq 0x38) {
        $size = @{ w = [int]$b[6] + ([int]$b[7] -shl 8); h = [int]$b[8] + ([int]$b[9] -shl 8); format = 'gif' }
    }
    elseif ($b.Length -ge 24 -and $b[0] -eq 0x89 -and $b[1] -eq 0x50 -and $b[2] -eq 0x4E -and $b[3] -eq 0x47) {
        $w = 0; $h = 0
        for ($i = 0; $i -lt 4; $i++) {
            $w = ($w -shl 8) -bor $b[16 + $i]
            $h = ($h -shl 8) -bor $b[20 + $i]
        }
        $size = @{ w = $w; h = $h; format = 'png' }
    }
    elseif ($b.Length -ge 4 -and $b[0] -eq 0xFF -and $b[1] -eq 0xD8) {
        $i = 2
        while ($i -lt ($b.Length - 9)) {
            if ($b[$i] -ne 0xFF) { $i++; continue }
            $marker = $b[$i + 1]
            if ($marker -eq 0x01 -or ($marker -ge 0xD0 -and $marker -le 0xD7) -or $marker -eq 0xFF) { $i += 2; continue }
            if ($marker -eq 0xD8 -or $marker -eq 0xD9) { $i += 2; continue }
            $segLen = ([int]$b[$i + 2] -shl 8) + [int]$b[$i + 3]
            if ($marker -ge 0xC0 -and $marker -le 0xCF -and $marker -ne 0xC4 -and $marker -ne 0xC8 -and $marker -ne 0xCC) {
                $h = ([int]$b[$i + 5] -shl 8) + [int]$b[$i + 6]
                $w = ([int]$b[$i + 7] -shl 8) + [int]$b[$i + 8]
                $size = @{ w = $w; h = $h; format = 'jpg' }
                break
            }
            $i += 2 + $segLen
        }
    }
    $sizeCache[$absPath] = $size
    return $size
}

# --- parse manifest ---
# Quirk: the shipped manifest contains unquoted attribute values (e.g. `cols=3`), which the
# game's SexyApp XMLParser tolerates but strict XML parsers reject. Normalize before parsing.
$raw = Get-Content -LiteralPath $Manifest -Raw
$raw = [regex]::Replace($raw, '(\s[\w]+)(?=\s*/?>)', '$1=""')
$raw = [regex]::Replace($raw, '(\s[\w]+)=([^"\s>]+)(\s|/?>)', '$1="$2"$3')
[xml]$doc = $raw
$usedFiles = @{}
$records = @()
$unresolved = @()
$allGroups = @()

foreach ($group in $doc.ResourceManifest.ChildNodes) {
    if ($group.NodeType -ne 'Element' -or $group.Name -ne 'Resources') { continue }
    $groupId = $group.GetAttribute('id')
    $defPath = $null
    $defPrefix = $null
    $groupRecords = @()

    foreach ($node in $group.ChildNodes) {
        if ($node.NodeType -ne 'Element') { continue }

        if ($node.Name -eq 'SetDefaults') {
            $defPath = $node.GetAttribute('path')
            $defPrefix = $node.GetAttribute('idprefix')
            continue
        }

        $type = $node.Name
        if ($type -notin @('Image', 'Font', 'Sound')) { continue }

        $id = $node.GetAttribute('id')
        $path = $node.GetAttribute('path')
        $attrs = @{}
        foreach ($a in $node.Attributes) {
            if ($a.Name -notin @('id', 'path')) { $attrs[$a.Name] = $a.Value }
        }

        $rec = [ordered]@{
            type = $type; id = $id; path = $path; group = $groupId
            defaultsPath = $defPath; defaultsPrefix = $defPrefix
            attrs = $attrs
            file = $null; resolvedVia = $null; width = $null; height = $null; format = $null
            frame = $null; mask = $null; maskSource = $null; maskCandidates = @()
            issues = @()
        }

        if ($type -in @('Image', 'Font', 'Sound')) {
            $file = Resolve-Asset $defPath $path
            $via = if ($file) { 'exact' } else { $null }
            if (-not $file -and $type -eq 'Image') {
                # Hypothesis (unverified): the engine falls back to the underscore-prefixed or
                # suffixed variant for entries whose plain name has no file on disk (14 such
                # entries: TANKMASK1-6 -> _mask*.jpg, HATCHREFLECTION, MENUBUTTONREFLECTION,
                # TITLEPAGEMASK, PETBUTTON*, STORE*HILIGHT). Verify in P3.2 via pixel inspection.
                $leaf = Split-Path $path -Leaf
                $file = Resolve-Asset $defPath "_$leaf"
                if ($file) { $via = 'leadingUnderscore' }
                else {
                    $file = Resolve-Asset $defPath "${leaf}_"
                    if ($file) { $via = 'trailingUnderscore' }
                }
            }
            if ($file) {
                $rec.file = $file
                $rec.resolvedVia = $via
                $usedFiles[$file.ToLowerInvariant()] = $true
                $abs = Join-Path $AssetsRoot $file
                $size = Get-ImageSize $abs
                if ($size) {
                    $rec.width = $size.w; $rec.height = $size.h; $rec.format = $size.format
                }
            }
            else {
                $probe = if ($path -match '\.[A-Za-z0-9]+$') { "$defPath\$path" } else { "$defPath\$path{.gif|.jpg|.png|.ogg|.au|.wav}" }
                $unresolved += [ordered]@{ type = $type; id = $id; group = $groupId; probe = $probe }
                $rec.issues += "unresolved"
            }
        }

        if ($type -eq 'Image' -and $rec.file) {
            $cols = if ($attrs.ContainsKey('cols')) { [int]$attrs['cols'] } else { 1 }
            $rows = if ($attrs.ContainsKey('rows')) { [int]$attrs['rows'] } else { 1 }
            if ($cols -lt 1 -or $rows -lt 1) { $rec.issues += "bad grid ${cols}x${rows}"; $cols = 1; $rows = 1 }
            $fw = [math]::Floor($rec.width / $cols)
            $fh = [math]::Floor($rec.height / $rows)
            if ($rec.width % $cols -ne 0) { $rec.issues += "width $($rec.width) not divisible by cols $cols" }
            if ($rec.height % $rows -ne 0) { $rec.issues += "height $($rec.height) not divisible by rows $rows" }
            $rec.frame = [ordered]@{ cols = $cols; rows = $rows; cellW = $fw; cellH = $fh; count = $cols * $rows }
            if ($attrs.ContainsKey('framemap')) {
                $rec.frame.framemap = @($attrs['framemap'] -split ',' | ForEach-Object { [int]$_.Trim() })
                foreach ($fm in $rec.frame.framemap) {
                    if ($fm -ge $rec.frame.count) { $rec.issues += "framemap index $fm out of range ($($rec.frame.count) cells)" }
                }
            }
            if ($attrs.ContainsKey('perframedelay')) {
                $rec.frame.perframedelay = @($attrs['perframedelay'] -split ',' | ForEach-Object { [int]$_.Trim() })
            }

            # explicit mask attribute
            $maskSpec = $null; $maskSrc = $null
            if ($attrs.ContainsKey('alphaimage')) { $maskSpec = $attrs['alphaimage']; $maskSrc = 'alphaimage' }
            elseif ($attrs.ContainsKey('alphagrid')) { $maskSpec = $attrs['alphagrid']; $maskSrc = 'alphagrid' }
            if ($maskSpec) {
                $maskFile = Resolve-Asset $defPath $maskSpec
                if ($maskFile) {
                    $rec.mask = $maskFile; $rec.maskSource = $maskSrc
                    $usedFiles[$maskFile.ToLowerInvariant()] = $true
                }
                else { $rec.issues += "$maskSrc unresolved: $maskSpec" }
            }
            else {
                $leadName = Split-Path $path -Leaf
                $lead = Resolve-Asset $defPath "_$leadName"
                $trail = Resolve-Asset $defPath "${leadName}_"
                $cands = @()
                if ($lead) { $cands += $lead; $usedFiles[$lead.ToLowerInvariant()] = $true }
                if ($trail -and $trail -ne $lead) { $cands += $trail; $usedFiles[$trail.ToLowerInvariant()] = $true }
                $rec.maskCandidates = $cands
            }
        }

        if ($type -eq 'Font') {
            if ($rec.file) {
                $stem = [IO.Path]::GetFileNameWithoutExtension($path)
                $lead = Resolve-Asset $defPath "_$stem"
                $plain = Resolve-Asset $defPath $stem
                $cands = @()
                if ($lead) { $cands += $lead; $usedFiles[$lead.ToLowerInvariant()] = $true }
                if ($plain -and $plain -ne $lead) { $cands += $plain; $usedFiles[$plain.ToLowerInvariant()] = $true }
                $rec.maskCandidates = $cands
            }
        }

        $groupRecords += $rec
        $records += $rec
    }

    $allGroups += [ordered]@{ id = $groupId; resources = $groupRecords }
}

# --- unreferenced asset files (images/sounds/music/data) ---
$assetDirs = @('images\', 'sounds\', 'music\', 'data\')
$unreferenced = @()
foreach ($kv in $index.GetEnumerator()) {
    $rel = $kv.Value
    $inScope = $false
    foreach ($d in $assetDirs) { if ($rel.ToLowerInvariant().StartsWith($d)) { $inScope = $true; break } }
    if (-not $inScope) { continue }
    if (-not $usedFiles.ContainsKey($kv.Key)) { $unreferenced += $rel }
}
$unreferenced = $unreferenced | Sort-Object

$stats = [ordered]@{
    totalResources = $records.Count
    images = @($records | Where-Object { $_.type -eq 'Image' }).Count
    fonts = @($records | Where-Object { $_.type -eq 'Font' }).Count
    sounds = @($records | Where-Object { $_.type -eq 'Sound' }).Count
    unresolved = $unresolved.Count
    unreferenced = $unreferenced.Count
    issueCount = @($records | Where-Object { $_.issues.Count -gt 0 }).Count
}

$result = [ordered]@{
    generated = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    manifest = $Manifest
    assetsRoot = $AssetsRoot
    stats = $stats
    groups = $allGroups
    unresolved = $unresolved
    unreferenced = $unreferenced
}

$outDir = Split-Path $Out -Parent
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$json = $result | ConvertTo-Json -Depth 12
[IO.File]::WriteAllText((Join-Path (Get-Location) $Out), $json, (New-Object Text.UTF8Encoding $false))

# --- summary ---
"resources: $($stats.totalResources) (images $($stats.images), fonts $($stats.fonts), sounds $($stats.sounds))"
"groups: $(($allGroups | ForEach-Object { "$($_.id)=$($_.resources.Count)" }) -join ', ')"
"unresolved: $($stats.unresolved)"
foreach ($u in $unresolved) { "  [$($u.type)] $($u.id) probe: $($u.probe)" }
"records with issues: $($stats.issueCount)"
foreach ($r in $records | Where-Object { $_.issues.Count -gt 0 }) { "  $($r.id): $($r.issues -join '; ')" }
"unreferenced asset files: $($stats.unreferenced)"
foreach ($u in $unreferenced) { "  $u" }
"written: $Out"

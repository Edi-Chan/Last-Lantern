$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$Root = Split-Path $PSScriptRoot -Parent
$Tile = 16
$AtlasW = 16
$AtlasH = 14

function ARGB([int]$r, [int]$g, [int]$b, [int]$a = 255) {
    return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

$WOOD = @{
    outline = ARGB 28 16 10; dark = ARGB 58 34 18; mid = ARGB 98 62 32
    light = ARGB 138 92 48; hi = ARGB 176 128 74; nail = ARGB 42 32 28
}
$STONE = @{
    outline = ARGB 22 24 28; dark = ARGB 52 56 62; mid = ARGB 86 92 100
    light = ARGB 118 124 132; hi = ARGB 158 162 168; nail = ARGB 36 38 42
}

function SetPix($bmp, [int]$x, [int]$y, $c) {
    if ($x -lt 0 -or $y -lt 0 -or $x -ge $bmp.Width -or $y -ge $bmp.Height) { return }
    $bmp.SetPixel($x, $y, $c)
}

function StairDist([int]$tx, [int]$ty, [bool]$right) {
    if ($right) { return $ty + $tx - 15 }
    return $ty - $tx
}

function LowCap([int]$tx, [int]$ty, [bool]$right, [string]$kind) {
    $width = if ($kind -eq "floor") { 8 } else { 5 }
    if ($ty -lt 13) { return $false }
    if ($right) { return $tx -le $width }
    return $tx -ge (15 - $width)
}

function HighCap([int]$tx, [int]$ty, [bool]$right, [string]$kind) {
    $width = if ($kind -eq "platform") { 8 } else { 5 }
    if ($ty -gt 2) { return $false }
    if ($right) { return $tx -ge (15 - $width) }
    return $tx -le $width
}

function DrawStairVariant($bmp, [int]$ox, [int]$oy, $pal, [bool]$right, [string]$kind) {
    $thick = 5
    for ($ty = 0; $ty -lt 16; $ty++) {
        for ($tx = 0; $tx -lt 16; $tx++) {
            $dist = StairDist $tx $ty $right
            $on = ($dist -ge 0 -and $dist -lt $thick)
            if ($kind -in @("start", "floor", "single") -and (LowCap $tx $ty $right $kind)) { $on = $true }
            if ($kind -in @("end", "platform", "single") -and (HighCap $tx $ty $right $kind)) { $on = $true }
            if (-not $on) { continue }
            $col = $pal.mid
            if ($dist -eq 0) { $col = $pal.outline }
            elseif ($dist -eq 1) { $col = $pal.hi }
            elseif ($dist -eq ($thick - 1)) { $col = $pal.dark }
            else {
                $col = if ((($tx + $ty) % 5) -eq 0) { $pal.light } else { $pal.mid }
                if ((($tx * 3 + $ty * 7) % 11) -eq 0) { $col = $pal.nail }
            }
            SetPix $bmp ($ox + $tx) ($oy + $ty) $col
        }
    }
    if ($right) {
        SetPix $bmp $ox ($oy + 15) $pal.outline
        SetPix $bmp ($ox + 15) $oy $pal.outline
        SetPix $bmp ($ox + 1) ($oy + 15) $pal.hi
        SetPix $bmp ($ox + 15) ($oy + 1) $pal.hi
    } else {
        SetPix $bmp ($ox + 15) ($oy + 15) $pal.outline
        SetPix $bmp $ox $oy $pal.outline
        SetPix $bmp ($ox + 14) ($oy + 15) $pal.hi
        SetPix $bmp $ox ($oy + 1) $pal.hi
    }
}

function SaveCrop($src, [int]$cx, [int]$cy, [string]$path) {
    $crop = $src.Clone((New-Object System.Drawing.Rectangle ($cx * $Tile), ($cy * $Tile), $Tile, $Tile), $src.PixelFormat)
    $crop.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $crop.Dispose()
}

$atlasPath = Join-Path $Root "assets\building\building_atlas.png"
$fs = [System.IO.File]::Open($atlasPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
$old = New-Object System.Drawing.Bitmap $fs
$canvas = New-Object System.Drawing.Bitmap ($AtlasW * $Tile), ($AtlasH * $Tile)
$canvas.SetResolution(96, 96)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
$g.DrawImage($old, 0, 0, $old.Width, $old.Height)
$g.Dispose()
$old.Dispose()
$fs.Close()

DrawStairVariant $canvas (1 * $Tile) (10 * $Tile) $WOOD $false "inner"
DrawStairVariant $canvas (2 * $Tile) (10 * $Tile) $WOOD $true "inner"
DrawStairVariant $canvas (3 * $Tile) (10 * $Tile) $STONE $false "inner"
DrawStairVariant $canvas (4 * $Tile) (10 * $Tile) $STONE $true "inner"

$kinds = @("single", "inner", "start", "end", "floor", "platform")
for ($i = 0; $i -lt $kinds.Count; $i++) {
    $kind = $kinds[$i]
    DrawStairVariant $canvas ($i * $Tile) (12 * $Tile) $WOOD $true $kind
    DrawStairVariant $canvas (($i + 6) * $Tile) (12 * $Tile) $WOOD $false $kind
    DrawStairVariant $canvas ($i * $Tile) (13 * $Tile) $STONE $true $kind
    DrawStairVariant $canvas (($i + 6) * $Tile) (13 * $Tile) $STONE $false $kind
}

$tmp = Join-Path $Root "assets\building\building_atlas.tmp.png"
$canvas.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
SaveCrop $canvas 1 12 (Join-Path $Root "assets\building\stairs\wood_stairs_icon.png")
SaveCrop $canvas 1 13 (Join-Path $Root "assets\building\stairs\stone_stairs_icon.png")
$canvas.Dispose()
Move-Item -Force $tmp $atlasPath
Write-Host "patched $atlasPath $($AtlasW * $Tile)x$($AtlasH * $Tile)"

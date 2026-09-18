$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$Root = Split-Path $PSScriptRoot -Parent
$Tile = 16
$AtlasW = 16
$AtlasH = 12

function New-Canvas([int]$w, [int]$h) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $bmp.SetResolution(96, 96)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $g.Dispose()
    return $bmp
}

function ARGB([int]$r, [int]$g, [int]$b, [int]$a = 255) {
    return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

function HashXY([int]$x, [int]$y, [int]$s) { return ($x * 73 + $y * 37 + $s * 19) -band 255 }

$WOOD = @{
    outline = ARGB 28 16 10; dark = ARGB 58 34 18; mid = ARGB 98 62 32
    light = ARGB 138 92 48; highlight = ARGB 176 128 74; nail = ARGB 42 32 28
}
$STONE = @{
    outline = ARGB 22 24 28; dark = ARGB 52 56 62; mid = ARGB 86 92 100
    light = ARGB 118 124 132; highlight = ARGB 158 162 168; nail = ARGB 36 38 42
}
$STRAW = @{
    outline = ARGB 48 34 12; dark = ARGB 110 78 22; mid = ARGB 168 124 36
    light = ARGB 204 164 58; highlight = ARGB 228 196 96; nail = ARGB 70 48 16
}
$METAL = @{
    outline = ARGB 18 18 22; dark = ARGB 48 50 56; mid = ARGB 92 98 108
    light = ARGB 150 156 166; highlight = ARGB 210 214 220; nail = ARGB 28 28 32
}

function SetPix($bmp, [int]$x, [int]$y, $c) {
    if ($null -eq $c -or $c -eq "") { return }
    if ($x -lt 0 -or $y -lt 0 -or $x -ge $bmp.Width -or $y -ge $bmp.Height) { return }
    $col = $c
    if ($c -is [int]) { $col = [System.Drawing.Color]::FromArgb([int]$c) }
    $bmp.SetPixel($x, $y, $col)
}

function FillRect($bmp, [int]$x0, [int]$y0, [int]$x1, [int]$y1, $c) {
    if ($null -eq $c) { return }
    for ($y = $y0; $y -lt $y1; $y++) {
        for ($x = $x0; $x -lt $x1; $x++) {
            if ($x -ge 0 -and $y -ge 0 -and $x -lt $bmp.Width -and $y -lt $bmp.Height) { SetPix $bmp $x $y $c }
        }
    }
}

function Grain($bmp, [int]$x0, [int]$y0, [int]$x1, [int]$y1, $pal, [bool]$vert, [int]$seed) {
    if ($null -eq $pal) { throw "palette missing" }
    for ($y = $y0; $y -lt $y1; $y++) {
        for ($x = $x0; $x -lt $x1; $x++) {
            $n = HashXY $x $y $seed
            $c = if ($n -lt 40) { $pal.dark } elseif ($n -lt 140) { $pal.mid } elseif ($n -lt 210) { $pal.light } else { $pal.highlight }
            if ($vert -and ($x % 4 -eq 0)) { $c = $pal.dark }
            if (-not $vert -and ($y % 4 -eq 0)) { $c = $pal.dark }
            if ($null -eq $c) { continue }
            if ($x -ge 0 -and $y -ge 0 -and $x -lt $bmp.Width -and $y -lt $bmp.Height) { SetPix $bmp $x $y $c }
        }
    }
}

function Outline($bmp, [int]$x0, [int]$y0, [int]$x1, [int]$y1, $c) {
    for ($x = $x0; $x -lt $x1; $x++) { SetPix $bmp $x $y0 $c; SetPix $bmp $x ($y1 - 1) $c }
    for ($y = $y0; $y -lt $y1; $y++) { SetPix $bmp $x0 $y $c; SetPix $bmp ($x1 - 1) $y $c }
}

function DrawConnected($bmp, [int]$ox, [int]$oy, $pal, [int]$mask, [string]$kind) {
    $vert = ($kind -eq "wall" -or $kind -eq "bg")
    $seedMap = @{ wall = 3; bg = 5; foundation = 7; floor = 9 }
    $seed = 1
    if ($seedMap.ContainsKey($kind)) { $seed = [int]$seedMap[$kind] }
    Grain $bmp $ox $oy ($ox + 16) ($oy + 16) $pal $vert $seed
    if ($kind -eq "bg") {
        for ($y = 0; $y -lt 16; $y++) {
            for ($x = 0; $x -lt 16; $x++) {
                $pix = $bmp.GetPixel(($ox + $x), ($oy + $y))
                $dim = [System.Drawing.Color]::FromArgb(255, [int]($pix.R * 0.62), [int]($pix.G * 0.6), [int]($pix.B * 0.58))
                SetPix $bmp ($ox + $x) ($oy + $y) $dim
            }
        }
    }
    if ($kind -eq "foundation") {
        FillRect $bmp $ox ($oy + 11) ($ox + 16) ($oy + 16) $pal.dark
        for ($x = $ox + 1; $x -lt $ox + 15; $x += 3) { SetPix $bmp $x ($oy + 12) $pal.nail }
    }
    if ($kind -eq "floor") {
        FillRect $bmp $ox $oy ($ox + 16) ($oy + 3) $pal["highlight"]
        FillRect $bmp $ox ($oy + 3) ($ox + 16) ($oy + 5) $pal.light
    }
    $edgeHi = if ($kind -ne "bg") { $pal["highlight"] } else { $pal.mid }
    if (-not ($mask -band 1)) { FillRect $bmp $ox $oy ($ox + 16) ($oy + 1) $pal.outline; FillRect $bmp $ox ($oy + 1) ($ox + 16) ($oy + 2) $edgeHi }
    if (-not ($mask -band 4)) { FillRect $bmp $ox ($oy + 15) ($ox + 16) ($oy + 16) $pal.outline; FillRect $bmp $ox ($oy + 14) ($ox + 16) ($oy + 15) $pal.dark }
    if (-not ($mask -band 8)) { FillRect $bmp $ox $oy ($ox + 1) ($oy + 16) $pal.outline }
    if (-not ($mask -band 2)) { FillRect $bmp ($ox + 15) $oy ($ox + 16) ($oy + 16) $pal.outline }
    if ($kind -eq "wall") { SetPix $bmp ($ox + 4) ($oy + 6) $pal.nail; SetPix $bmp ($ox + 11) ($oy + 10) $pal.nail }
}

function DrawRoof($bmp, [int]$ox, [int]$oy, $pal, [int]$variant, [bool]$straw) {
    $palettes = if ($straw) { $script:STRAW } else { $pal }
    Grain $bmp $ox $oy ($ox + 16) ($oy + 16) $palettes $false $(if ($straw) { 9 } else { 3 })
    $hi = $palettes["highlight"]
    if ($straw -and $null -ne $hi) {
        for ($y = 0; $y -lt 16; $y++) { for ($x = 0; $x -lt 16; $x++) { if ((($x + $y * 2) % 5) -eq 0) { SetPix $bmp ($ox + $x) ($oy + $y) $hi } } }
    }
    $trans = ARGB 0 0 0 0
    $ol = $palettes["outline"]
    $dk = $palettes["dark"]
    if ($variant -eq 1) {
        for ($y = 0; $y -lt 16; $y++) { SetPix $bmp $ox ($oy + $y) $ol; for ($x = 1; $x -lt 4; $x++) { SetPix $bmp ($ox + $x) ($oy + $y) $dk } }
    } elseif ($variant -eq 2) {
        for ($y = 0; $y -lt 16; $y++) { SetPix $bmp ($ox + 15) ($oy + $y) $ol; for ($x = 12; $x -lt 15; $x++) { SetPix $bmp ($ox + $x) ($oy + $y) $dk } }
    } elseif ($variant -eq 3) {
        for ($y = 0; $y -lt 16; $y++) { for ($x = 0; $x -lt 16; $x++) { if ($x -lt (15 - $y)) { SetPix $bmp ($ox + $x) ($oy + $y) $trans } elseif ($x -eq (15 - $y)) { SetPix $bmp ($ox + $x) ($oy + $y) $ol } } }
    } elseif ($variant -eq 4) {
        for ($y = 0; $y -lt 16; $y++) { for ($x = 0; $x -lt 16; $x++) { if ($x -gt $y) { SetPix $bmp ($ox + $x) ($oy + $y) $trans } elseif ($x -eq $y) { SetPix $bmp ($ox + $x) ($oy + $y) $ol } } }
    } elseif ($variant -eq 5) {
        for ($y = 0; $y -lt 16; $y++) {
            for ($x = 0; $x -lt 16; $x++) {
                $left = $x -lt (7 - [int]($y / 2)); $right = $x -gt (8 + [int]($y / 2))
                if ($left -or $right) { SetPix $bmp ($ox + $x) ($oy + $y) $trans }
                elseif ($x -eq (7 - [int]($y / 2)) -or $x -eq (8 + [int]($y / 2))) { SetPix $bmp ($ox + $x) ($oy + $y) $ol }
            }
        }
    } else {
        Outline $bmp $ox $oy ($ox + 16) ($oy + 16) $ol
    }
}

function DrawBeam($bmp, [int]$ox, [int]$oy) {
    FillRect $bmp $ox ($oy + 5) ($ox + 16) ($oy + 11) $WOOD.mid
    FillRect $bmp $ox ($oy + 5) ($ox + 16) ($oy + 7) $WOOD["highlight"]
    FillRect $bmp $ox ($oy + 9) ($ox + 16) ($oy + 11) $WOOD.dark
    foreach ($x in 2, 8, 13) { SetPix $bmp ($ox + $x) ($oy + 8) $WOOD.nail }
    for ($x = 0; $x -lt 16; $x++) { SetPix $bmp ($ox + $x) ($oy + 5) $WOOD.outline; SetPix $bmp ($ox + $x) ($oy + 10) $WOOD.outline }
}

function DrawStairs($bmp, [int]$ox, [int]$oy, $pal, [bool]$right) {
    for ($step = 0; $step -lt 4; $step++) {
        $y1 = $oy + 16 - $step * 4; $y0 = $y1 - 4
        if ($right) { $x0 = $ox + $step * 4; $x1 = $ox + 16 } else { $x0 = $ox; $x1 = $ox + 16 - $step * 4 }
        FillRect $bmp $x0 $y0 $x1 $y1 $(if ($step % 2 -eq 0) { $pal.mid } else { $pal.light })
        for ($x = $x0; $x -lt $x1; $x++) { SetPix $bmp $x $y0 $pal.outline; SetPix $bmp $x ($y1 - 1) $pal.dark }
    }
}

function DrawLadder($bmp, [int]$ox, [int]$oy) {
    FillRect $bmp ($ox + 2) $oy ($ox + 5) ($oy + 16) $WOOD.mid
    FillRect $bmp ($ox + 11) $oy ($ox + 14) ($oy + 16) $WOOD.mid
    foreach ($y in 2, 6, 10, 14) { FillRect $bmp ($ox + 2) ($oy + $y) ($ox + 14) ($oy + $y + 2) $WOOD.light }
    for ($y = 0; $y -lt 16; $y++) { SetPix $bmp ($ox + 2) ($oy + $y) $WOOD.outline; SetPix $bmp ($ox + 13) ($oy + $y) $WOOD.outline }
}

function DrawPlatform($bmp, [int]$ox, [int]$oy, $pal) {
    FillRect $bmp $ox ($oy + 2) ($ox + 16) ($oy + 7) $pal.mid
    FillRect $bmp $ox ($oy + 2) ($ox + 16) ($oy + 4) $pal.highlight
    for ($x = 0; $x -lt 16; $x++) { SetPix $bmp ($ox + $x) ($oy + 2) $pal.outline; SetPix $bmp ($ox + $x) ($oy + 6) $pal.outline }
    SetPix $bmp ($ox + 4) ($oy + 5) $pal.nail; SetPix $bmp ($ox + 11) ($oy + 5) $pal.nail
}

function DrawWindow($bmp, [int]$ox, [int]$oy, [bool]$wood) {
    $pal = if ($wood) { $WOOD } else { $METAL }
    $glass = ARGB 70 118 148 140; $ghi = ARGB 170 210 230 90
    FillRect $bmp $ox $oy ($ox + 16) ($oy + 16) $pal.dark
    Outline $bmp $ox $oy ($ox + 16) ($oy + 16) $pal.outline
    FillRect $bmp ($ox + 2) ($oy + 2) ($ox + 14) ($oy + 14) $glass
    FillRect $bmp ($ox + 3) ($oy + 3) ($ox + 7) ($oy + 7) $ghi
    FillRect $bmp ($ox + 7) $oy ($ox + 9) ($oy + 16) $pal.mid
    FillRect $bmp $ox ($oy + 7) ($ox + 16) ($oy + 9) $pal.mid
}

function DrawBarricade($bmp, [int]$ox, [int]$oy) {
    Grain $bmp $ox $oy ($ox + 16) ($oy + 16) $WOOD $true 11
    for ($y = 0; $y -lt 16; $y += 4) { FillRect $bmp $ox ($oy + $y) ($ox + 16) ($oy + $y + 2) $WOOD.dark }
    Outline $bmp $ox $oy ($ox + 16) ($oy + 16) $WOOD.outline
    SetPix $bmp ($ox + 3) ($oy + 5) $METAL.light; SetPix $bmp ($ox + 12) ($oy + 10) $METAL.light
}

function DrawBarrel($bmp, [int]$ox, [int]$oy) {
    FillRect $bmp ($ox + 3) ($oy + 2) ($ox + 13) ($oy + 15) $WOOD.mid
    FillRect $bmp ($ox + 4) ($oy + 3) ($ox + 12) ($oy + 5) $WOOD.highlight
    foreach ($y in 6, 10, 14) { FillRect $bmp ($ox + 3) ($oy + $y) ($ox + 13) ($oy + $y + 1) $WOOD.dark }
    Outline $bmp ($ox + 3) ($oy + 2) ($ox + 13) ($oy + 15) $WOOD.outline
}

function DrawShelf($bmp, [int]$ox, [int]$oy) {
    FillRect $bmp ($ox + 1) ($oy + 1) ($ox + 15) ($oy + 15) $WOOD.dark
    foreach ($y in 4, 9, 14) { FillRect $bmp ($ox + 1) ($oy + $y) ($ox + 15) ($oy + $y + 1) $WOOD.light }
    FillRect $bmp ($ox + 1) ($oy + 1) ($ox + 3) ($oy + 15) $WOOD.mid
    FillRect $bmp ($ox + 13) ($oy + 1) ($ox + 15) ($oy + 15) $WOOD.mid
    SetPix $bmp ($ox + 5) ($oy + 7) (ARGB 120 40 36); SetPix $bmp ($ox + 10) ($oy + 12) (ARGB 60 90 70)
    Outline $bmp ($ox + 1) ($oy + 1) ($ox + 15) ($oy + 15) $WOOD.outline
}

function DrawTable($bmp, [int]$ox, [int]$oy) {
    FillRect $bmp ($ox + 1) ($oy + 5) ($ox + 15) ($oy + 8) $WOOD.light
    FillRect $bmp ($ox + 2) ($oy + 8) ($ox + 4) ($oy + 15) $WOOD.mid
    FillRect $bmp ($ox + 12) ($oy + 8) ($ox + 14) ($oy + 15) $WOOD.mid
    for ($x = 1; $x -lt 15; $x++) { SetPix $bmp ($ox + $x) ($oy + 5) $WOOD.outline; SetPix $bmp ($ox + $x) ($oy + 7) $WOOD.outline }
}

function DrawChair($bmp, [int]$ox, [int]$oy) {
    FillRect $bmp ($ox + 4) ($oy + 1) ($ox + 12) ($oy + 8) $WOOD.mid
    FillRect $bmp ($ox + 4) ($oy + 8) ($ox + 13) ($oy + 11) $WOOD.light
    FillRect $bmp ($ox + 4) ($oy + 11) ($ox + 6) ($oy + 15) $WOOD.dark
    FillRect $bmp ($ox + 11) ($oy + 11) ($ox + 13) ($oy + 15) $WOOD.dark
    Outline $bmp ($ox + 4) ($oy + 1) ($ox + 12) ($oy + 8) $WOOD.outline
}

function DrawSign($bmp, [int]$ox, [int]$oy) {
    FillRect $bmp ($ox + 7) ($oy + 8) ($ox + 9) ($oy + 16) $WOOD.dark
    FillRect $bmp ($ox + 2) ($oy + 2) ($ox + 14) ($oy + 10) $WOOD.light
    Outline $bmp ($ox + 2) ($oy + 2) ($ox + 14) ($oy + 10) $WOOD.outline
    FillRect $bmp ($ox + 4) ($oy + 4) ($ox + 12) ($oy + 5) $WOOD.dark
    FillRect $bmp ($ox + 4) ($oy + 7) ($ox + 10) ($oy + 8) $WOOD.dark
}

function DrawRack($bmp, [int]$ox, [int]$oy) {
    FillRect $bmp ($ox + 2) ($oy + 1) ($ox + 14) ($oy + 3) $WOOD.mid
    FillRect $bmp ($ox + 2) ($oy + 1) ($ox + 4) ($oy + 15) $WOOD.dark
    FillRect $bmp ($ox + 12) ($oy + 1) ($ox + 14) ($oy + 15) $WOOD.dark
    FillRect $bmp ($ox + 6) ($oy + 3) ($ox + 8) ($oy + 13) (ARGB 160 160 170)
    FillRect $bmp ($ox + 9) ($oy + 3) ($ox + 11) ($oy + 13) (ARGB 140 90 50)
    SetPix $bmp ($ox + 6) ($oy + 3) $METAL.highlight
}

function DrawChestTile($bmp, [int]$ox, [int]$oy) {
    FillRect $bmp ($ox + 1) ($oy + 5) ($ox + 15) ($oy + 15) $WOOD.mid
    FillRect $bmp ($ox + 1) ($oy + 5) ($ox + 15) ($oy + 9) $WOOD.light
    FillRect $bmp ($ox + 7) ($oy + 8) ($ox + 9) ($oy + 12) $METAL.light
    Outline $bmp ($ox + 1) ($oy + 5) ($ox + 15) ($oy + 15) $WOOD.outline
    SetPix $bmp ($ox + 8) ($oy + 10) (ARGB 210 170 50)
}

function DrawTorchTile($bmp, [int]$ox, [int]$oy) {
    FillRect $bmp ($ox + 7) ($oy + 7) ($ox + 10) ($oy + 15) $WOOD.mid
    FillRect $bmp ($ox + 6) ($oy + 2) ($ox + 11) ($oy + 8) (ARGB 230 120 30)
    FillRect $bmp ($ox + 7) ($oy + 3) ($ox + 10) ($oy + 6) (ARGB 255 210 80)
    SetPix $bmp ($ox + 8) ($oy + 2) (ARGB 255 240 180)
    FillRect $bmp ($ox + 4) ($oy + 10) ($ox + 12) ($oy + 13) $WOOD.dark
}

function DrawDoor([bool]$reinforced) {
    $bmp = New-Canvas 16 48
    Grain $bmp 1 1 15 47 $WOOD $true 7
    Outline $bmp 0 0 16 48 $WOOD.outline
    FillRect $bmp 2 4 14 6 $WOOD.dark
    FillRect $bmp 2 24 14 26 $WOOD.dark
    FillRect $bmp 2 40 14 42 $WOOD.dark
    SetPix $bmp 12 28 (ARGB 210 180 70)
    if ($reinforced) {
        foreach ($y in 8, 22, 36) {
            FillRect $bmp 1 $y 15 ($y + 3) $METAL.mid
            SetPix $bmp 2 ($y + 1) $METAL["highlight"]; SetPix $bmp 13 ($y + 1) $METAL["highlight"]
        }
        FillRect $bmp 11 24 14 28 $METAL.light
    }
    return $bmp
}

function DrawGate() {
    $bmp = New-Canvas 32 48
    Grain $bmp 1 1 31 47 $WOOD $true 4
    Outline $bmp 0 0 32 48 $WOOD.outline
    FillRect $bmp 15 1 17 47 $WOOD.dark
    foreach ($y in 10, 22, 34) { FillRect $bmp 1 $y 31 ($y + 3) $METAL.dark }
    SetPix $bmp 6 24 $METAL.highlight; SetPix $bmp 25 24 $METAL.highlight
    return $bmp
}

function DrawWorkbench() {
    $bmp = New-Canvas 32 16
    FillRect $bmp 1 4 31 9 $WOOD.light
    FillRect $bmp 2 9 6 16 $WOOD.mid
    FillRect $bmp 26 9 30 16 $WOOD.mid
    FillRect $bmp 10 1 14 5 $METAL.mid
    Outline $bmp 1 4 31 9 $WOOD.outline
    return $bmp
}

function DrawAnvil() {
    $bmp = New-Canvas 32 16
    FillRect $bmp 6 10 26 16 $METAL.dark
    FillRect $bmp 4 5 28 10 $METAL.mid
    FillRect $bmp 2 6 8 9 $METAL.light
    FillRect $bmp 24 4 30 8 $METAL.highlight
    Outline $bmp 4 5 28 10 $METAL.outline
    return $bmp
}

function DrawFurnace() {
    $bmp = New-Canvas 32 32
    Grain $bmp 2 4 30 32 $STONE $false 2
    Outline $bmp 2 4 30 32 $STONE.outline
    FillRect $bmp 10 14 22 28 (ARGB 18 10 8)
    FillRect $bmp 12 16 20 26 (ARGB 220 90 24)
    FillRect $bmp 14 18 18 24 (ARGB 255 180 50)
    FillRect $bmp 12 2 20 6 $STONE.mid
    return $bmp
}

function SavePng($bmp, [string]$path) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
}

function CropTile($src, [int]$cx, [int]$cy) {
    $out = New-Canvas 16 16
    for ($y = 0; $y -lt 16; $y++) {
        for ($x = 0; $x -lt 16; $x++) { $out.SetPixel($x, $y, $src.GetPixel($cx * 16 + $x, $cy * 16 + $y)) }
    }
    return $out
}

function ScaleToIcon($src) {
    $out = New-Canvas 16 16
    $g = [System.Drawing.Graphics]::FromImage($out)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.DrawImage($src, 0, 0, 16, 16)
    $g.Dispose()
    return $out
}

$atlas = New-Canvas ($AtlasW * $Tile) ($AtlasH * $Tile)
$rows = @(
    @{ kind = "foundation"; pal = $WOOD },
    @{ kind = "foundation"; pal = $STONE },
    @{ kind = "wall"; pal = $WOOD },
    @{ kind = "wall"; pal = $STONE },
    @{ kind = "bg"; pal = $WOOD },
    @{ kind = "bg"; pal = $STONE },
    @{ kind = "floor"; pal = $WOOD },
    @{ kind = "floor"; pal = $STONE }
)
for ($row = 0; $row -lt 8; $row++) {
    for ($mask = 0; $mask -lt 16; $mask++) { DrawConnected $atlas ($mask * 16) ($row * 16) $rows[$row].pal $mask $rows[$row].kind }
}
for ($v = 0; $v -lt 7; $v++) {
    DrawRoof $atlas ($v * 16) (8 * 16) $WOOD $v $false
    DrawRoof $atlas ($v * 16) (9 * 16) $WOOD $v $true
}
DrawBeam $atlas 0 160
DrawStairs $atlas 16 160 $WOOD $false
DrawStairs $atlas 32 160 $WOOD $true
DrawStairs $atlas 48 160 $STONE $false
DrawStairs $atlas 64 160 $STONE $true
DrawLadder $atlas 80 160
DrawPlatform $atlas 96 160 $WOOD
DrawPlatform $atlas 112 160 $STONE
DrawWindow $atlas 128 160 $true
DrawWindow $atlas 144 160 $false
DrawBarricade $atlas 160 160
DrawBarrel $atlas 176 160
DrawShelf $atlas 192 160
DrawTable $atlas 208 160
DrawChair $atlas 224 160
DrawSign $atlas 240 160
DrawRack $atlas 0 176
DrawTorchTile $atlas 16 176
DrawChestTile $atlas 32 176

$door = DrawDoor $false
$rdoor = DrawDoor $true
$gate = DrawGate
$bench = DrawWorkbench
$anvilBmp = DrawAnvil
$furnace = DrawFurnace
# dummy occupancy tiles copied from icons
$g = [System.Drawing.Graphics]::FromImage($atlas)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.DrawImage($door, 48, 176, 16, 16)
$g.DrawImage($rdoor, 64, 176, 16, 16)
$g.DrawImage($gate, 80, 176, 16, 16)
$g.DrawImage($bench, 96, 176, 16, 16)
$g.DrawImage($anvilBmp, 112, 176, 16, 16)
$g.DrawImage($furnace, 128, 176, 16, 16)
$g.Dispose()

SavePng $atlas (Join-Path $Root "assets/building/building_atlas.png")

$folders = @{
    wood_foundation = "foundations"; stone_foundation = "foundations"; wood_wall = "walls"; stone_wall = "walls"
    wood_background = "backgrounds"; stone_background = "backgrounds"; wood_floor = "floors"; stone_floor = "floors"
    wood_roof = "roofs"; straw_roof = "roofs"; wood_beam = "supports"; wood_stairs = "stairs"; stone_stairs = "stairs"
    wood_ladder = "stairs"; wood_platform = "platforms"; stone_platform = "platforms"; wood_window = "windows"
    glass_window = "windows"; wood_door = "doors"; reinforced_wood_door = "doors"; wood_gate = "defense"
    wood_barricade = "defense"; wall_torch = "lights"; wood_chest = "furniture"; wood_barrel = "furniture"
    wood_shelf = "furniture"; wood_table = "furniture"; wood_chair = "furniture"; wood_sign = "furniture"
    weapon_rack = "furniture"; workbench = "stations"; anvil = "stations"; furnace = "stations"
}

function SaveIcon($bmp, $key) {
    $p = Join-Path $Root ("assets/building/{0}/{1}_icon.png" -f $folders[$key], $key)
    SavePng $bmp $p
}

SaveIcon (CropTile $atlas 0 0) "wood_foundation"
SaveIcon (CropTile $atlas 0 1) "stone_foundation"
SaveIcon (CropTile $atlas 0 2) "wood_wall"
SaveIcon (CropTile $atlas 0 3) "stone_wall"
SaveIcon (CropTile $atlas 0 4) "wood_background"
SaveIcon (CropTile $atlas 0 5) "stone_background"
SaveIcon (CropTile $atlas 0 6) "wood_floor"
SaveIcon (CropTile $atlas 0 7) "stone_floor"
SaveIcon (CropTile $atlas 0 8) "wood_roof"
SaveIcon (CropTile $atlas 0 9) "straw_roof"
SaveIcon (CropTile $atlas 0 10) "wood_beam"
SaveIcon (CropTile $atlas 2 10) "wood_stairs"
SaveIcon (CropTile $atlas 4 10) "stone_stairs"
SaveIcon (CropTile $atlas 5 10) "wood_ladder"
SaveIcon (CropTile $atlas 6 10) "wood_platform"
SaveIcon (CropTile $atlas 7 10) "stone_platform"
SaveIcon (CropTile $atlas 8 10) "wood_window"
SaveIcon (CropTile $atlas 9 10) "glass_window"
SaveIcon (CropTile $atlas 10 10) "wood_barricade"
SaveIcon (CropTile $atlas 11 10) "wood_barrel"
SaveIcon (CropTile $atlas 12 10) "wood_shelf"
SaveIcon (CropTile $atlas 13 10) "wood_table"
SaveIcon (CropTile $atlas 14 10) "wood_chair"
SaveIcon (CropTile $atlas 15 10) "wood_sign"
SaveIcon (CropTile $atlas 0 11) "weapon_rack"
SaveIcon (CropTile $atlas 1 11) "wall_torch"
SaveIcon (CropTile $atlas 2 11) "wood_chest"
SaveIcon (ScaleToIcon $door) "wood_door"
SaveIcon (ScaleToIcon $rdoor) "reinforced_wood_door"
SaveIcon (ScaleToIcon $gate) "wood_gate"
SaveIcon (ScaleToIcon $bench) "workbench"
SaveIcon (ScaleToIcon $anvilBmp) "anvil"
SaveIcon (ScaleToIcon $furnace) "furnace"

function SaveSprite($bmp, $key) {
    SavePng $bmp (Join-Path $Root ("assets/building/{0}/{1}.png" -f $folders[$key], $key))
}
SaveSprite $door "wood_door"
SaveSprite $rdoor "reinforced_wood_door"
SaveSprite $gate "wood_gate"
SaveSprite $bench "workbench"
SaveSprite $anvilBmp "anvil"
SaveSprite $furnace "furnace"
SaveSprite (CropTile $atlas 2 11) "wood_chest"
SaveSprite (CropTile $atlas 1 11) "wall_torch"

function Write-BlockTres($rel, $map) {
    $path = Join-Path $Root ("resources/blocks/building/{0}.tres" -f $rel)
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $lines = @(
        "[gd_resource type=`"Resource`" script_class=`"BlockData`" format=3]",
        "",
        "[ext_resource type=`"Script`" path=`"res://scripts/world/block_data.gd`" id=`"1_script`"]",
        "",
        "[resource]",
        "script = ExtResource(`"1_script`")"
    )
    foreach ($k in $map.Keys) { $lines += ("{0} = {1}" -f $k, $map[$k]) }
    [IO.File]::WriteAllText($path, ($lines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
}

function B($file, $id, $name, $atlas, $auto, $hard, $drop, $solid, $vis, $mapc, $tool, $pow, $se, $role, $w, $str, $mh, $found, $beam, $eb, $imp, $mat, $part, $flam) {
    $m = [ordered]@{
        id = $id; display_name = "`"$name`""; atlas_coords = $atlas; atlas_source_id = 1; autotile_count = $auto
        hardness = $hard; drop_item_id = $drop; solid = $solid; vision_occlusion = $vis; map_color = $mapc
        required_tool = $tool; required_tool_power = $pow; structural_enabled = $se; structural_role = $role
        structural_weight = $w; support_strength = $str; max_horizontal_support = $mh
        is_foundation_material = $found; is_support_beam = $beam; enemy_break_cost = $eb; structural_importance = $imp
        building_material = $mat; building_part_type = $part; flammable = $flam
    }
    return @{ file = $file; map = $m }
}

$AXE = 2; $PICK = 1
$blockList = @()
function Add-B { param($h) $script:blockList += $h }

Add-B (B "foundations/wood_foundation" 31 "Holzfundament" "Vector2i(0, 0)" 16 1.1 62 "true" 0.7 "Color(0.45, 0.28, 0.14, 1)" $AXE 1 "true" 1 2 8 4 "true" "false" 3 4 1 1 "true")
Add-B (B "foundations/stone_foundation" 32 "Steinfundament" "Vector2i(0, 1)" 16 1.8 63 "true" 0.85 "Color(0.42, 0.44, 0.48, 1)" $PICK 1 "true" 1 4 14 6 "true" "false" 6 6 2 1 "false")
Add-B (B "walls/wood_wall" 33 "Holzwand" "Vector2i(0, 2)" 16 1.0 64 "true" 0.75 "Color(0.52, 0.32, 0.16, 1)" $AXE 1 "true" 2 1 5 5 "false" "false" 2 2 1 2 "true")
Add-B (B "walls/stone_wall" 34 "Steinwand" "Vector2i(0, 3)" 16 1.6 65 "true" 0.9 "Color(0.5, 0.52, 0.56, 1)" $PICK 1 "true" 2 3 10 6 "false" "false" 5 3 2 2 "false")
$h = B "backgrounds/wood_background" 35 "Holz-Hintergrundwand" "Vector2i(0, 4)" 16 0.6 66 "false" 0.12 "Color(0.32, 0.2, 0.12, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 1 0 1 3 "true"
$h.map["is_background"] = "true"; Add-B $h
$h = B "backgrounds/stone_background" 36 "Stein-Hintergrundwand" "Vector2i(0, 5)" 16 0.9 67 "false" 0.16 "Color(0.3, 0.32, 0.36, 1)" $PICK 1 "false" 0 0 0 0 "false" "false" 2 0 2 3 "false"
$h.map["is_background"] = "true"; Add-B $h
Add-B (B "floors/wood_floor" 37 "Holzboden" "Vector2i(0, 6)" 16 0.9 68 "true" 0.55 "Color(0.48, 0.3, 0.16, 1)" $AXE 1 "true" 2 1 4 6 "false" "false" 2 1 1 4 "true")
Add-B (B "floors/stone_floor" 38 "Steinboden" "Vector2i(0, 7)" 16 1.4 69 "true" 0.7 "Color(0.46, 0.48, 0.52, 1)" $PICK 1 "true" 2 2 8 7 "false" "false" 4 2 2 4 "false")
Add-B (B "roofs/wood_roof" 39 "Holzdach" "Vector2i(0, 8)" 7 0.8 70 "true" 0.5 "Color(0.4, 0.22, 0.12, 1)" $AXE 1 "true" 5 1 3 4 "false" "false" 2 3 1 5 "true")
Add-B (B "roofs/straw_roof" 40 "Strohdach" "Vector2i(0, 9)" 7 0.45 71 "true" 0.35 "Color(0.7, 0.52, 0.18, 1)" $AXE 1 "true" 5 1 2 3 "false" "false" 1 2 1 5 "true")
Add-B (B "supports/wood_beam" 41 "Holzbalken" "Vector2i(0, 10)" 1 1.0 72 "false" 0.15 "Color(0.4, 0.24, 0.12, 1)" $AXE 1 "true" 4 1 8 10 "false" "false" 3 5 1 7 "true")
$h = B "stairs/wood_stairs" 42 "Holztreppe" "Vector2i(1, 10)" 1 0.9 73 "true" 0.2 "Color(0.5, 0.32, 0.16, 1)" $AXE 1 "true" 2 1 4 3 "false" "false" 2 1 1 9 "true"
$h.map["uses_orientation"] = "true"; Add-B $h
$h = B "stairs/stone_stairs" 43 "Steintreppe" "Vector2i(3, 10)" 1 1.5 74 "true" 0.25 "Color(0.48, 0.5, 0.54, 1)" $PICK 1 "true" 2 2 7 4 "false" "false" 4 2 2 9 "false"
$h.map["uses_orientation"] = "true"; Add-B $h
$h = B "stairs/wood_ladder" 44 "Holzleiter" "Vector2i(5, 10)" 1 0.7 75 "false" 0.08 "Color(0.42, 0.26, 0.14, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 1 0 1 10 "true"
$h.map["is_climbable"] = "true"; Add-B $h
$h = B "platforms/wood_platform" 45 "Holzplattform" "Vector2i(6, 10)" 1 0.8 76 "true" 0.1 "Color(0.46, 0.3, 0.16, 1)" $AXE 1 "true" 2 1 3 8 "false" "false" 2 1 1 8 "true"
$h.map["is_one_way"] = "true"; Add-B $h
$h = B "platforms/stone_platform" 46 "Steinplattform" "Vector2i(7, 10)" 1 1.3 77 "true" 0.12 "Color(0.44, 0.46, 0.5, 1)" $PICK 1 "true" 2 2 6 10 "false" "false" 4 2 2 8 "false"
$h.map["is_one_way"] = "true"; Add-B $h
Add-B (B "windows/wood_window" 47 "Holzfenster" "Vector2i(8, 10)" 1 0.7 80 "true" 0.18 "Color(0.35, 0.5, 0.55, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 2 0 1 12 "true")
Add-B (B "windows/glass_window" 48 "Glasfenster" "Vector2i(9, 10)" 1 0.5 81 "true" 0.12 "Color(0.4, 0.62, 0.72, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 1 0 4 12 "false")
Add-B (B "defense/wood_barricade" 49 "Holzbarrikade" "Vector2i(10, 10)" 1 1.3 93 "true" 0.4 "Color(0.36, 0.22, 0.12, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 8 0 1 16 "true")
Add-B (B "furniture/wood_barrel" 50 "Holzfass" "Vector2i(11, 10)" 1 0.6 84 "false" 0.1 "Color(0.4, 0.24, 0.12, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 1 0 1 17 "true")
Add-B (B "furniture/wood_shelf" 51 "Holzregal" "Vector2i(12, 10)" 1 0.5 85 "false" 0.08 "Color(0.38, 0.24, 0.14, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 1 0 1 17 "true")
Add-B (B "furniture/wood_table" 52 "Holztisch" "Vector2i(13, 10)" 1 0.6 86 "false" 0.08 "Color(0.42, 0.26, 0.14, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 1 0 1 17 "true")
Add-B (B "furniture/wood_chair" 53 "Holzstuhl" "Vector2i(14, 10)" 1 0.45 87 "false" 0.06 "Color(0.4, 0.25, 0.13, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 1 0 1 17 "true")
Add-B (B "furniture/wood_sign" 54 "Holzschild" "Vector2i(15, 10)" 1 0.4 88 "false" 0.05 "Color(0.44, 0.3, 0.16, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 1 0 1 17 "true")
Add-B (B "furniture/weapon_rack" 55 "Waffenhalter" "Vector2i(0, 11)" 1 0.55 89 "false" 0.08 "Color(0.36, 0.24, 0.14, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 1 0 1 17 "true")
$h = B "doors/wood_door" 56 "Holztür" "Vector2i(3, 11)" 1 1.2 78 "false" 0.2 "Color(0.4, 0.24, 0.12, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 5 0 1 11 "true"
$h.map["footprint"] = "Vector2i(1, 3)"; Add-B $h
$h = B "doors/reinforced_wood_door" 57 "Verstärkte Holztür" "Vector2i(4, 11)" 1 2.0 79 "false" 0.25 "Color(0.34, 0.22, 0.14, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 12 0 1 11 "true"
$h.map["footprint"] = "Vector2i(1, 3)"; Add-B $h
$h = B "defense/wood_gate" 58 "Holztor" "Vector2i(5, 11)" 1 1.8 94 "false" 0.3 "Color(0.32, 0.2, 0.1, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 14 0 1 16 "true"
$h.map["footprint"] = "Vector2i(2, 3)"; Add-B $h
Add-B (B "furniture/wood_chest" 59 "Holzkiste" "Vector2i(2, 11)" 1 0.8 83 "false" 0.12 "Color(0.42, 0.26, 0.12, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 2 0 1 14 "true")
$h = B "stations/workbench" 60 "Werkbank" "Vector2i(6, 11)" 1 1.1 90 "false" 0.15 "Color(0.4, 0.26, 0.14, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 3 0 1 15 "true"
$h.map["footprint"] = "Vector2i(2, 1)"; Add-B $h
$h = B "stations/anvil" 61 "Amboss" "Vector2i(7, 11)" 1 2.4 91 "false" 0.18 "Color(0.45, 0.46, 0.5, 1)" $PICK 1 "false" 0 0 0 0 "false" "false" 6 0 4 15 "false"
$h.map["footprint"] = "Vector2i(2, 1)"; Add-B $h
$h = B "stations/furnace" 62 "Schmelzofen" "Vector2i(8, 11)" 1 2.0 92 "false" 0.3 "Color(0.55, 0.28, 0.16, 1)" $PICK 1 "false" 0 0 0 0 "false" "false" 6 0 2 15 "false"
$h.map["footprint"] = "Vector2i(2, 2)"; Add-B $h
$h = B "lights/wall_torch" 63 "Wandfackel" "Vector2i(1, 11)" 1 0.3 82 "false" 0.02 "Color(0.9, 0.55, 0.18, 1)" $AXE 1 "false" 0 0 0 0 "false" "false" 1 0 1 13 "true"
$h.map["light_energy"] = "1.1"; Add-B $h

$blockPaths = @()
foreach ($b in $blockList) {
    Write-BlockTres $b.file $b.map
    $blockPaths += "res://resources/blocks/building/$($b.file).tres"
}

$CAT_BUILD = 6; $CAT_DEF = 13; $CAT_TECH = 14
$items = @(
    @{ key = "wood_foundation"; id = 62; name = "Holzfundament"; desc = "Hölzerne Bodenverankerung für Spielergebäude."; block = 31; mat = 1; part = 1; cat = $CAT_BUILD },
    @{ key = "stone_foundation"; id = 63; name = "Steinfundament"; desc = "Schweres Stein-Fundament. Stabiler als Holz."; block = 32; mat = 2; part = 1; cat = $CAT_BUILD },
    @{ key = "wood_wall"; id = 64; name = "Holzwand"; desc = "Tragende Holzwand. Varianten entstehen anhand der Nachbarn."; block = 33; mat = 1; part = 2; cat = $CAT_BUILD },
    @{ key = "stone_wall"; id = 65; name = "Steinwand"; desc = "Tragende Steinwand."; block = 34; mat = 2; part = 2; cat = $CAT_BUILD },
    @{ key = "wood_background"; id = 66; name = "Holz-Hintergrundwand"; desc = "Optische Hinterwand. Trägt kein Dach."; block = 35; mat = 1; part = 3; cat = $CAT_BUILD },
    @{ key = "stone_background"; id = 67; name = "Stein-Hintergrundwand"; desc = "Optische Stein-Hinterwand ohne Spielerkollision."; block = 36; mat = 2; part = 3; cat = $CAT_BUILD },
    @{ key = "wood_floor"; id = 68; name = "Holzboden"; desc = "Sichtbarer Gebäudeboden aus Holz."; block = 37; mat = 1; part = 4; cat = $CAT_BUILD },
    @{ key = "stone_floor"; id = 69; name = "Steinboden"; desc = "Sichtbarer Gebäudeboden aus Stein."; block = 38; mat = 2; part = 4; cat = $CAT_BUILD },
    @{ key = "wood_roof"; id = 70; name = "Holzdach"; desc = "Modulares Holzdach. Die Form folgt den Nachbarn."; block = 39; mat = 1; part = 5; cat = $CAT_BUILD },
    @{ key = "straw_roof"; id = 71; name = "Strohdach"; desc = "Leichtes, brennbares Dach für frühe Hütten."; block = 40; mat = 1; part = 5; cat = $CAT_BUILD },
    @{ key = "wood_beam"; id = 72; name = "Holzbalken"; desc = "Horizontaler Balken. Überträgt Last über begrenzte Distanz."; block = 41; mat = 1; part = 7; cat = $CAT_BUILD },
    @{ key = "wood_stairs"; id = 73; name = "Holztreppe"; desc = "Treppe. Beim Platzieren drehen für die Richtung."; block = 42; mat = 1; part = 9; cat = $CAT_BUILD; rot = $true },
    @{ key = "stone_stairs"; id = 74; name = "Steintreppe"; desc = "Stabile Steintreppe. Drehen bestimmt die Steigung."; block = 43; mat = 2; part = 9; cat = $CAT_BUILD; rot = $true },
    @{ key = "wood_ladder"; id = 75; name = "Holzleiter"; desc = "Klettern nach oben und unten, ohne volle Blockkollision."; block = 44; mat = 1; part = 10; cat = $CAT_BUILD },
    @{ key = "wood_platform"; id = 76; name = "Holzplattform"; desc = "Einweg-Plattform. Von unten durchspringen, mit Ducken fallen."; block = 45; mat = 1; part = 8; cat = $CAT_BUILD },
    @{ key = "stone_platform"; id = 77; name = "Steinplattform"; desc = "Schwerere Einweg-Plattform."; block = 46; mat = 2; part = 8; cat = $CAT_BUILD },
    @{ key = "wood_door"; id = 78; name = "Holztür"; desc = "Öffnen und schließen mit Interagieren."; block = 56; mat = 1; part = 11; cat = $CAT_BUILD; rot = $true },
    @{ key = "reinforced_wood_door"; id = 79; name = "Verstärkte Holztür"; desc = "Dickeres Holz mit Metallbeschlägen. Später belagerungsfest."; block = 57; mat = 1; part = 11; cat = $CAT_BUILD; rot = $true },
    @{ key = "wood_window"; id = 80; name = "Holzfenster"; desc = "Holzrahmen mit Öffnung. Später zerstörbar durch Gegner."; block = 47; mat = 1; part = 12; cat = $CAT_BUILD },
    @{ key = "glass_window"; id = 81; name = "Glasfenster"; desc = "Teiltransparentes Glas, klar von Wänden unterscheidbar."; block = 48; mat = 4; part = 12; cat = $CAT_BUILD },
    @{ key = "wall_torch"; id = 82; name = "Wandfackel"; desc = "Platzierbares Licht an Wänden und Hinterwänden."; block = 63; mat = 1; part = 13; cat = $CAT_BUILD },
    @{ key = "wood_chest"; id = 83; name = "Holzkiste"; desc = "Platzierbare Kiste. Lager folgt später."; block = 59; mat = 1; part = 14; cat = $CAT_BUILD },
    @{ key = "wood_barrel"; id = 84; name = "Holzfass"; desc = "Einrichtung. Später als Lager nutzbar."; block = 50; mat = 1; part = 17; cat = $CAT_BUILD },
    @{ key = "wood_shelf"; id = 85; name = "Holzregal"; desc = "Dekoration ohne Statik."; block = 51; mat = 1; part = 17; cat = $CAT_BUILD },
    @{ key = "wood_table"; id = 86; name = "Holztisch"; desc = "Möbel / Einrichtung."; block = 52; mat = 1; part = 17; cat = $CAT_BUILD; rot = $true },
    @{ key = "wood_chair"; id = 87; name = "Holzstuhl"; desc = "Möbel / Einrichtung."; block = 53; mat = 1; part = 17; cat = $CAT_BUILD; rot = $true },
    @{ key = "wood_sign"; id = 88; name = "Holzschild"; desc = "Platzierbares Schild. Texteditor folgt später."; block = 54; mat = 1; part = 17; cat = $CAT_BUILD },
    @{ key = "weapon_rack"; id = 89; name = "Waffenhalter"; desc = "Dekoration. Später Item-Display möglich."; block = 55; mat = 1; part = 17; cat = $CAT_BUILD },
    @{ key = "workbench"; id = 90; name = "Werkbank"; desc = "Arbeitsstation. Crafting kann später andocken."; block = 60; mat = 1; part = 15; cat = $CAT_TECH },
    @{ key = "anvil"; id = 91; name = "Amboss"; desc = "Metall-Station für spätere Schmiede."; block = 61; mat = 4; part = 15; cat = $CAT_TECH },
    @{ key = "furnace"; id = 92; name = "Schmelzofen"; desc = "Steinofen mit Glutöffnung. Animation folgt später."; block = 62; mat = 2; part = 15; cat = $CAT_TECH },
    @{ key = "wood_barricade"; id = 93; name = "Holzbarrikade"; desc = "Zerstörbare Barriere. Später Gegnerblockade."; block = 49; mat = 1; part = 16; cat = $CAT_DEF },
    @{ key = "wood_gate"; id = 94; name = "Holztor"; desc = "Großes Tor. Öffnen und schließen mit Interagieren."; block = 58; mat = 1; part = 16; cat = $CAT_DEF; rot = $true }
)

$itemPaths = @()
foreach ($it in $items) {
    $folder = $folders[$it.key]
    $icon = "res://assets/building/$folder/$($it.key)_icon.png"
    $path = Join-Path $Root "resources/items/building/$folder/$($it.key).tres"
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $rot = if ($it.rot) { "true" } else { "false" }
    $text = @"
[gd_resource type="Resource" script_class="ItemData" format=3]

[ext_resource type="Script" path="res://scripts/items/item_data.gd" id="1_script"]
[ext_resource type="Texture2D" path="$icon" id="2_icon"]

[resource]
script = ExtResource("1_script")
id = $($it.id)
display_name = "$($it.name)"
description = "$($it.desc)"
icon = ExtResource("2_icon")
max_stack = 999
item_type = 0
category = $($it.cat)
equipment_slot = 0
placeable_block_id = $($it.block)
building_material = $($it.mat)
building_part_type = $($it.part)
can_rotate = $rot
held_scale = 1.0
"@
    [IO.File]::WriteAllText($path, $text.Replace("`r`n", "`n") + "`n", [Text.UTF8Encoding]::new($false))
    $itemPaths += "res://resources/items/building/$folder/$($it.key).tres"
}

function Patch-Catalog([string]$catalogPath, [string]$arrayName, [string]$marker, [string[]]$paths, [int]$idStart) {
    $text = [IO.File]::ReadAllText($catalogPath)
    $kept = New-Object System.Collections.Generic.List[string]
    foreach ($ln in $text -split "`n") {
        if ($ln -notmatch [regex]::Escape($marker)) { $kept.Add($ln.TrimEnd("`r")) }
    }
    $text = ($kept -join "`n")
    $inject = New-Object System.Collections.Generic.List[string]
    $names = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $paths.Count; $i++) {
        $eid = "{0}_bp" -f ($idStart + $i)
        $inject.Add("[ext_resource type=`"Resource`" path=`"$($paths[$i])`" id=`"$eid`"]")
        $names.Add("ExtResource(`"$eid`")")
    }
    $parts = $text -split "\[resource\]", 2
    $head = $parts[0].TrimEnd() + "`n" + ($inject -join "`n") + "`n`n[resource]"
    $rest = $parts[1]
    $rx = [regex]"$arrayName = \[([^\]]*)\]"
    $m = $rx.Match($rest)
    if (-not $m.Success) { throw "$arrayName missing" }
    $inner = $m.Groups[1].Value.TrimEnd()
    if (-not $inner.EndsWith(",")) { $inner += "," }
    $inner += " " + ($names -join ", ")
    $rest = $rest.Substring(0, $m.Groups[1].Index) + $inner + $rest.Substring($m.Groups[1].Index + $m.Groups[1].Length)
    [IO.File]::WriteAllText($catalogPath, ($head + $rest).Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false))
}

Patch-Catalog (Join-Path $Root "resources/items/item_catalog.tres") "items" "items/building/" $itemPaths 100
Patch-Catalog (Join-Path $Root "resources/blocks/block_catalog.tres") "blocks" "blocks/building/" $blockPaths 200

$atlas.Dispose(); $door.Dispose(); $rdoor.Dispose(); $gate.Dispose(); $bench.Dispose(); $anvilBmp.Dispose(); $furnace.Dispose()
Write-Output "OK blocks=$($blockList.Count) items=$($items.Count)"

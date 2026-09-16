Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
function Ensure-Dir([string]$rel) {
    $p = Join-Path $root $rel
    New-Item -ItemType Directory -Force -Path $p | Out-Null
    return $p
}

$vegDir = Ensure-Dir "assets\world\vegetation"
$itemDir = Ensure-Dir "assets\items\plants"
$bgDir = Ensure-Dir "assets\world\background"
$celDir = Ensure-Dir "assets\world\celestial"

function Col([int]$r, [int]$g, [int]$b, [int]$a = 255) {
    return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}
function NewBmp([int]$w, [int]$h) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $g.Clear([System.Drawing.Color]::Transparent)
    return @{ Bmp = $bmp; G = $g }
}
function SaveBmp($ctx, [string]$path) {
    $ctx.G.Dispose()
    $ctx.Bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $ctx.Bmp.Dispose()
    Write-Output $path
}
function Brush([System.Drawing.Color]$c) { return New-Object System.Drawing.SolidBrush $c }
function Fill($g, $c, $x, $y, $w, $h) {
    $b = Brush $c
    $g.FillRectangle($b, [int]$x, [int]$y, [int]$w, [int]$h)
    $b.Dispose()
}
function Pix($bmp, $x, $y, $c) {
    if ($x -lt 0 -or $y -lt 0 -or $x -ge $bmp.Width -or $y -ge $bmp.Height) { return }
    $bmp.SetPixel([int]$x, [int]$y, $c)
}

function DrawStem($bmp, [int]$x, [int]$y0, [int]$y1, $c, $c2) {
    for ($y = $y0; $y -le $y1; $y++) {
        Pix $bmp $x $y $c
        if (($y % 2) -eq 0) { Pix $bmp ($x + 1) $y $c2 }
    }
}

function DrawFlower([string]$name, $petal, $center, $stem, $leaf) {
    $ctx = NewBmp 16 16
    $bmp = $ctx.Bmp
    DrawStem $bmp 7 8 15 $stem (Col 40 110 42)
    Pix $bmp 6 11 $leaf
    Pix $bmp 6 12 $leaf
    Pix $bmp 9 12 $leaf
    Pix $bmp 9 13 $leaf
    $cx = 7; $cy = 5
    foreach ($o in @(@(0,-2),@(0,2),@(-2,0),@(2,0),@(-1,-1),@(1,-1),@(-1,1),@(1,1))) {
        Pix $bmp ($cx + $o[0]) ($cy + $o[1]) $petal
        Pix $bmp ($cx + $o[0] + 1) ($cy + $o[1]) $petal
    }
    Pix $bmp $cx $cy $center
    Pix $bmp ($cx+1) $cy $center
    Pix $bmp $cx ($cy+1) $center
    Pix $bmp ($cx+1) ($cy+1) (Col ([Math]::Min(255,$center.R+20)) ([Math]::Min(255,$center.G+20)) $center.B)
    SaveBmp $ctx (Join-Path $vegDir "$name.png")
    Copy-Item (Join-Path $vegDir "$name.png") (Join-Path $itemDir "$name.png") -Force
}

# Flowers
DrawFlower "white_wildflower" (Col 245 245 248) (Col 232 196 70) (Col 52 128 48) (Col 46 140 52)
DrawFlower "yellow_wildflower" (Col 236 196 48) (Col 180 90 28) (Col 52 128 48) (Col 46 140 52)
DrawFlower "red_wildflower" (Col 196 52 48) (Col 232 180 70) (Col 52 120 46) (Col 40 130 48)
DrawFlower "blue_wildflower" (Col 72 124 210) (Col 236 220 90) (Col 48 122 50) (Col 40 128 52)
DrawFlower "purple_wildflower" (Col 148 78 188) (Col 236 210 90) (Col 48 118 52) (Col 42 132 58)

function DrawWildGrass {
    $ctx = NewBmp 16 16
    $bmp = $ctx.Bmp
    $g1 = Col 62 150 58; $g2 = Col 42 118 46; $g3 = Col 88 168 64
    foreach ($pair in @(@(3,15,8),@(5,15,11),@(7,15,9),@(9,15,13),@(11,15,10),@(13,15,12))) {
        $x = $pair[0]; $base = $pair[1]; $top = $pair[2]
        $c = if (($x % 3) -eq 0) { $g3 } elseif (($x % 2) -eq 0) { $g1 } else { $g2 }
        for ($y = $base; $y -ge $top; $y--) {
            $dx = [int][Math]::Round(($base - $y) * 0.15 * (($x % 2) * 2 - 1))
            Pix $bmp ($x + $dx) $y $c
        }
    }
    SaveBmp $ctx (Join-Path $vegDir "wild_grass.png")
    Copy-Item (Join-Path $vegDir "wild_grass.png") (Join-Path $itemDir "wild_grass.png") -Force
}
DrawWildGrass

function DrawTallGrass {
    $ctx = NewBmp 16 24
    $bmp = $ctx.Bmp
    $cols = @((Col 48 132 52), (Col 70 158 60), (Col 38 110 44), (Col 92 172 68))
    $blades = @(@(2,23,4,0),@(4,23,2,1),@(6,23,5,2),@(8,23,1,3),@(10,23,3,0),@(12,23,6,1),@(14,23,4,2))
    foreach ($b in $blades) {
        $x = $b[0]; $base = $b[1]; $top = $b[2]; $c = $cols[$b[3]]
        $dir = (($x % 2) * 2 - 1)
        for ($y = $base; $y -ge $top; $y--) {
            $t = ($base - $y) / [Math]::Max(1, ($base - $top))
            $dx = [int][Math]::Round($t * $t * 2 * $dir)
            Pix $bmp ($x + $dx) $y $c
            if ($t -gt 0.55) { Pix $bmp ($x + $dx + $dir) $y $c }
        }
    }
    SaveBmp $ctx (Join-Path $vegDir "tall_grass.png")
    $icon = NewBmp 16 16
    $src = [System.Drawing.Image]::FromFile((Join-Path $vegDir "tall_grass.png"))
    $icon.G.DrawImage($src, 2, 0, 12, 16)
    $src.Dispose()
    SaveBmp $icon (Join-Path $itemDir "tall_grass.png")
}
DrawTallGrass

function DrawFern {
    $ctx = NewBmp 16 24
    $bmp = $ctx.Bmp
    $stem = Col 46 108 52
    $leaf = Col 58 140 64
    $leafD = Col 36 96 48
    $leafL = Col 86 168 78
    for ($y = 23; $y -ge 4; $y--) { Pix $bmp 8 $y $stem; Pix $bmp 7 $y $stem }
    foreach ($row in @(5,8,11,14,17,20)) {
        $spread = [Math]::Max(2, [int]((23 - $row) / 4))
        for ($i = 1; $i -le $spread; $i++) {
            Pix $bmp (8 - $i) ($row + ($i % 2)) $leaf
            Pix $bmp (8 + $i) ($row + ($i % 2)) $leaf
            if ($i -eq $spread) {
                Pix $bmp (8 - $i) ($row - 1) $leafL
                Pix $bmp (8 + $i) ($row - 1) $leafL
            }
        }
        Pix $bmp 6 ($row + 1) $leafD
        Pix $bmp 10 ($row + 1) $leafD
    }
    SaveBmp $ctx (Join-Path $vegDir "fern.png")
    $icon = NewBmp 16 16
    $src = [System.Drawing.Image]::FromFile((Join-Path $vegDir "fern.png"))
    $icon.G.DrawImage($src, 1, 0, 14, 16)
    $src.Dispose()
    SaveBmp $icon (Join-Path $itemDir "fern.png")
}
DrawFern

function DrawBush {
    $ctx = NewBmp 16 20
    $bmp = $ctx.Bmp
    $wood = Col 92 62 36
    $g1 = Col 48 118 52
    $g2 = Col 70 148 62
    $g3 = Col 34 96 44
    for ($y = 17; $y -le 19; $y++) { Pix $bmp 7 $y $wood; Pix $bmp 8 $y $wood }
    foreach ($p in @(@(4,12),@(5,10),@(6,9),@(7,8),@(8,8),@(9,9),@(10,10),@(11,12),@(3,14),@(12,14),@(4,16),@(11,16),@(6,13),@(9,13),@(5,15),@(10,15),@(7,11),@(8,11),@(6,15),@(9,15))) {
        $c = if (($p[0] + $p[1]) % 3 -eq 0) { $g3 } elseif (($p[0] % 2) -eq 0) { $g2 } else { $g1 }
        Pix $bmp $p[0] $p[1] $c
        Pix $bmp ($p[0]+1) $p[1] $c
        Pix $bmp $p[0] ($p[1]+1) $c
    }
    Pix $bmp 5 9 (Col 210 70 80)
    Pix $bmp 10 11 (Col 210 70 80)
    SaveBmp $ctx (Join-Path $vegDir "bush.png")
    $icon = NewBmp 16 16
    $src = [System.Drawing.Image]::FromFile((Join-Path $vegDir "bush.png"))
    $icon.G.DrawImage($src, 0, -2, 16, 20)
    $src.Dispose()
    SaveBmp $icon (Join-Path $itemDir "bush.png")
}
DrawBush

function DrawDryGrass {
    $ctx = NewBmp 16 16
    $bmp = $ctx.Bmp
    $c1 = Col 176 148 72; $c2 = Col 148 118 52; $c3 = Col 196 168 88
    foreach ($pair in @(@(4,15,7),@(6,15,6),@(8,15,9),@(10,15,5),@(12,15,8))) {
        $x = $pair[0]; $base = $pair[1]; $top = $pair[2]
        $c = if ($x % 3 -eq 0) { $c3 } elseif ($x % 2 -eq 0) { $c1 } else { $c2 }
        $dir = (($x % 2) * 2 - 1)
        for ($y = $base; $y -ge $top; $y--) {
            $dx = [int][Math]::Round(($base - $y) * 0.28 * $dir)
            Pix $bmp ($x + $dx) $y $c
        }
    }
    SaveBmp $ctx (Join-Path $vegDir "dry_grass.png")
    Copy-Item (Join-Path $vegDir "dry_grass.png") (Join-Path $itemDir "dry_grass.png") -Force
}
DrawDryGrass

# Sun
$sun = NewBmp 32 32
for ($y = 0; $y -lt 32; $y++) {
    for ($x = 0; $x -lt 32; $x++) {
        $dx = $x - 15.5; $dy = $y - 15.5
        $d = [Math]::Sqrt($dx*$dx + $dy*$dy)
        if ($d -lt 9.2) {
            Pix $sun.Bmp $x $y (Col 255 228 110)
        } elseif ($d -lt 10.6) {
            Pix $sun.Bmp $x $y (Col 255 186 70)
        } elseif ($d -lt 13.5) {
            $a = [int](90 * (1.0 - (($d - 10.6) / 2.9)))
            Pix $sun.Bmp $x $y (Col 255 210 90 $a)
        }
    }
}
# simple rays
foreach ($ang in 0,45,90,135,180,225,270,315) {
    $rad = $ang * [Math]::PI / 180
    for ($i = 11; $i -le 15; $i++) {
        $x = [int](15.5 + [Math]::Cos($rad) * $i)
        $y = [int](15.5 + [Math]::Sin($rad) * $i)
        Pix $sun.Bmp $x $y (Col 255 214 96 160)
    }
}
SaveBmp $sun (Join-Path $celDir "sun.png")

# Moon
$moon = NewBmp 28 28
for ($y = 0; $y -lt 28; $y++) {
    for ($x = 0; $x -lt 28; $x++) {
        $dx = $x - 13.5; $dy = $y - 13.5
        $d = [Math]::Sqrt($dx*$dx + $dy*$dy)
        if ($d -lt 9.0) {
            $shade = [int](210 + 30 * ($dx / 9.0))
            Pix $moon.Bmp $x $y (Col $shade $shade 230)
        } elseif ($d -lt 10.2) {
            Pix $moon.Bmp $x $y (Col 170 176 210 180)
        }
    }
}
foreach ($cr in @(@(9,10,2),@(16,8,1),@(14,16,2),@(8,16,1))) {
    for ($y = $cr[1] - $cr[2]; $y -le $cr[1] + $cr[2]; $y++) {
        for ($x = $cr[0] - $cr[2]; $x -le $cr[0] + $cr[2]; $x++) {
            $dx = $x - $cr[0]; $dy = $y - $cr[1]
            if (($dx*$dx + $dy*$dy) -le ($cr[2]*$cr[2])) {
                $p = $moon.Bmp.GetPixel([Math]::Max(0,$x), [Math]::Max(0,$y))
                if ($p.A -gt 0) { Pix $moon.Bmp $x $y (Col 170 174 198) }
            }
        }
    }
}
SaveBmp $moon (Join-Path $celDir "moon.png")

function DrawHills([string]$file, $base, $hi, $lo, [int]$h) {
    $w = 512
    $ctx = NewBmp $w $h
    $bmp = $ctx.Bmp
    for ($x = 0; $x -lt $w; $x++) {
        $n = [Math]::Sin($x * 0.018) * 10 + [Math]::Sin($x * 0.041 + 1.2) * 6 + [Math]::Sin($x * 0.09) * 3
        $top = [int]($h * 0.42 + $n)
        for ($y = $top; $y -lt $h; $y++) {
            $t = ($y - $top) / [Math]::Max(1, ($h - $top))
            $r = [int]($hi.R + ($lo.R - $hi.R) * $t)
            $g = [int]($hi.G + ($lo.G - $hi.G) * $t)
            $b = [int]($hi.B + ($lo.B - $hi.B) * $t)
            Pix $bmp $x $y (Col $r $g $b)
        }
        Pix $bmp $x $top $base
    }
    SaveBmp $ctx (Join-Path $bgDir $file)
}
DrawHills "hills_grass.png" (Col 58 86 78) (Col 48 72 70) (Col 28 42 48) 80
DrawHills "hills_sand.png" (Col 176 142 88) (Col 158 122 70) (Col 120 88 52) 72

function DrawTreeSilhouette($bmp, [int]$baseX, [int]$baseY, [int]$height, [string]$style, $col, $colD) {
    $trunkW = [Math]::Max(2, [int]($height / 14))
    $trunkH = [int]($height * 0.32)
    for ($y = $baseY - $trunkH; $y -le $baseY; $y++) {
        for ($x = $baseX - $trunkW; $x -le $baseX + $trunkW; $x++) { Pix $bmp $x $y $colD }
    }
    if ($style -eq "pine") {
        $top = $baseY - $height
        $layers = 4
        for ($i = 0; $i -lt $layers; $i++) {
            $ly = $top + [int]($i * $height * 0.18)
            $hw = 2 + $i * [int]($height / 10)
            for ($y = 0; $y -lt [int]($height / 6); $y++) {
                $w = [int]($hw * ($y + 1) / ($height / 6.0))
                for ($x = -$w; $x -le $w; $x++) {
                    Pix $bmp ($baseX + $x) ($ly + $y) $(if ($x -lt 0) { $colD } else { $col })
                }
            }
        }
    } elseif ($style -eq "narrow") {
        $top = $baseY - $height
        for ($y = $top; $y -lt $baseY - $trunkH + 2; $y++) {
            $t = ($y - $top) / [Math]::Max(1.0, ($baseY - $trunkH - $top))
            $hw = 1 + [int](2.2 * [Math]::Sin($t * [Math]::PI))
            for ($x = -$hw; $x -le $hw; $x++) { Pix $bmp ($baseX + $x) $y $col }
        }
    } else {
        $cy = $baseY - $trunkH - [int]($height * 0.22)
        $r = [int]($height * 0.28)
        for ($y = -$r; $y -le $r; $y++) {
            for ($x = -$r; $x -le [int]($r * 1.15); $x++) {
                if (($x*$x + $y*$y * 1.15) -le ($r*$r)) {
                    Pix $bmp ($baseX + $x) ($cy + $y) $(if ($x -lt -1) { $colD } else { $col })
                }
            }
        }
    }
}

function DrawTreeStrip([string]$file, [int]$w, [int]$h, $col, $colD, [int]$count, [int]$minH, [int]$maxH, [int]$seed) {
    $ctx = NewBmp $w $h
    $rnd = New-Object System.Random $seed
    $x = 18
    for ($i = 0; $i -lt $count; $i++) {
        $style = @("round","pine","narrow","round","pine")[$rnd.Next(0,5)]
        $th = $rnd.Next($minH, $maxH + 1)
        $baseY = $h - 2 - $rnd.Next(0, 4)
        DrawTreeSilhouette $ctx.Bmp $x $baseY $th $style $col $colD
        $x += $rnd.Next(18, 42)
        if ($x -gt $w - 20) { break }
    }
    SaveBmp $ctx (Join-Path $bgDir $file)
}
DrawTreeStrip "far_trees.png" 1024 96 (Col 52 66 72) (Col 36 48 56) 38 28 52 11
DrawTreeStrip "mid_trees.png" 1024 128 (Col 40 72 52) (Col 28 52 40) 28 48 92 23
DrawTreeStrip "far_trees_sand.png" 1024 80 (Col 110 92 64) (Col 86 70 48) 18 18 36 41

# Fog haze
$fog = NewBmp 256 48
for ($y = 0; $y -lt 48; $y++) {
    for ($x = 0; $x -lt 256; $x++) {
        $v = [Math]::Sin(($x / 256.0) * 6.28) * 0.25 + 0.75
        $a = [int]((1.0 - [Math]::Abs($y - 24) / 24.0) * 42 * $v)
        if ($a -lt 0) { $a = 0 }
        Pix $fog.Bmp $x $y (Col 214 226 230 $a)
    }
}
SaveBmp $fog (Join-Path $bgDir "fog_haze.png")

function DrawCloud([string]$file, [int]$w, [int]$h, [int]$seed) {
    $ctx = NewBmp $w $h
    $rnd = New-Object System.Random $seed
    $blobs = $rnd.Next(3, 6)
    for ($i = 0; $i -lt $blobs; $i++) {
        $cx = [int]($w * (0.22 + $i * 0.16)) + $rnd.Next(-3, 4)
        $cy = [int]($h * 0.52) + $rnd.Next(-3, 3)
        $rx = $rnd.Next([int]($w/7), [int]($w/4))
        $ry = $rnd.Next([int]($h/4), [int]($h/2.4))
        for ($y = 0; $y -lt $h; $y++) {
            for ($x = 0; $x -lt $w; $x++) {
                $dx = ($x - $cx) / [Math]::Max(1.0, $rx)
                $dy = ($y - $cy) / [Math]::Max(1.0, $ry)
                if ($dx*$dx + $dy*$dy -le 1.0) {
                    $shade = if ($y -gt $cy + 1) { Col 214 222 232 } else { Col 248 250 252 }
                    Pix $ctx.Bmp $x $y $shade
                }
            }
        }
    }
    SaveBmp $ctx (Join-Path $bgDir $file)
}
DrawCloud "cloud_wispy.png" 48 18 7
DrawCloud "cloud_puff.png" 36 20 19

Write-Output "done"

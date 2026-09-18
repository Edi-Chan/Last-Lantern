Add-Type -AssemblyName System.Drawing

function New-PxBitmap([int]$w, [int]$h) {
	$bmp = New-Object System.Drawing.Bitmap $w, $h
	for ($y = 0; $y -lt $h; $y++) {
		for ($x = 0; $x -lt $w; $x++) {
			$bmp.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
		}
	}
	return $bmp
}

function Set-Px($bmp, [int]$x, [int]$y, [string]$hex) {
	if ($x -lt 0 -or $y -lt 0 -or $x -ge $bmp.Width -or $y -ge $bmp.Height) { return }
	if ($hex -eq "" -or $hex -eq "-") { return }
	$hex = $hex.TrimStart("#")
	$a = 255
	if ($hex.Length -eq 8) {
		$a = [Convert]::ToInt32($hex.Substring(0, 2), 16)
		$hex = $hex.Substring(2)
	}
	$r = [Convert]::ToInt32($hex.Substring(0, 2), 16)
	$g = [Convert]::ToInt32($hex.Substring(2, 2), 16)
	$b = [Convert]::ToInt32($hex.Substring(4, 2), 16)
	$bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($a, $r, $g, $b))
}

function Draw-Rows($bmp, [int]$ox, [int]$oy, $rows) {
	for ($y = 0; $y -lt $rows.Count; $y++) {
		$line = $rows[$y]
		for ($x = 0; $x -lt $line.Count; $x++) {
			Set-Px $bmp ($ox + $x) ($oy + $y) $line[$x]
		}
	}
}

$root = "c:\github\Last-Lantern\terraria"
New-Item -ItemType Directory -Force -Path "$root\assets\items\buildings" | Out-Null
New-Item -ItemType Directory -Force -Path "$root\assets\buildings" | Out-Null

# Blueprint scroll with hammer
$bp = New-PxBitmap 16 16
$p = "#E8D5A3"; $p2 = "#C4A06A"; $p3 = "#8A6A3A"; $ink = "#3A2A18"
$h = "#8B5A2B"; $h2 = "#5C3A1A"; $steel = "#9AA3A8"; $s2 = "#6D7578"
$rows = @(
	@("-","-","-","-","-","-","-","-","-","-","-","-","-","-","-","-"),
	@("-","-","-","$p3","$p2","$p","$p","$p","$p","$p","$p2","$p3","-","-","-","-"),
	@("-","-","$p3","$p2","$p","$p","$p","$p","$p","$p","$p","$p2","$p3","-","-","-"),
	@("-","-","$p2","$p","$p","$ink","$ink","$p","$p","$ink","$p","$p","$p2","-","-","-"),
	@("-","-","$p2","$p","$p","$p","$ink","$p","$p","$ink","$p","$p","$p2","-","-","-"),
	@("-","-","$p2","$p","$p","$p","$ink","$ink","$ink","$ink","$p","$p","$p2","-","-","-"),
	@("-","-","$p2","$p","$p","$p","$p","$p","$p","$p","$p","$p","$p2","-","-","-"),
	@("-","-","$p3","$p2","$p","$steel","$s2","$steel","$p","$p","$p","$p2","$p3","-","-","-"),
	@("-","-","-","$p3","$p2","$s2","$steel","$s2","$p2","$p3","-","-","-","-","-","-"),
	@("-","-","-","-","-","$h","$h2","$h","-","-","-","-","-","-","-","-"),
	@("-","-","-","-","-","$h","$h2","$h","-","-","-","-","-","-","-","-"),
	@("-","-","-","-","-","$h","$h2","$h","-","-","-","-","-","-","-","-"),
	@("-","-","-","-","-","$h2","$h","$h2","-","-","-","-","-","-","-","-"),
	@("-","-","-","-","-","-","$h2","-","-","-","-","-","-","-","-","-"),
	@("-","-","-","-","-","-","-","-","-","-","-","-","-","-","-","-"),
	@("-","-","-","-","-","-","-","-","-","-","-","-","-","-","-","-")
)
Draw-Rows $bp 0 0 $rows
$bp.Save("$root\assets\items\buildings\forge_blueprint.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bp.Dispose()

# Forge core 16x16: dark iron with ember
$fc = New-PxBitmap 16 16
$i1 = "#2A2A30"; $i2 = "#3C3C44"; $i3 = "#1A1A20"; $i4 = "#55555E"
$e1 = "#E67A22"; $e2 = "#FFCC55"; $e3 = "#A33A10"; $e4 = "#FFEEAA"
$core = @(
	@("-","$i3","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i3","-","-"),
	@("$i3","$i1","$i2","$i4","$i2","$i2","$i2","$i2","$i2","$i2","$i2","$i4","$i2","$i1","$i3","-"),
	@("$i1","$i2","$i3","$i1","$i1","$i1","$e3","$e1","$e3","$i1","$i1","$i1","$i3","$i2","$i1","-"),
	@("$i1","$i2","$i1","$i3","$e3","$e1","$e1","$e2","$e1","$e3","$i3","$i1","$i1","$i2","$i1","-"),
	@("$i1","$i2","$i1","$e3","$e1","$e2","$e4","$e2","$e1","$e1","$e3","$i1","$i1","$i2","$i1","-"),
	@("$i1","$i2","$i1","$e3","$e1","$e2","$e2","$e1","$e3","$e3","$i1","$i1","$i1","$i2","$i1","-"),
	@("$i1","$i2","$i1","$i1","$e3","$e1","$e3","$i3","$i1","$i1","$i1","$i1","$i1","$i2","$i1","-"),
	@("$i1","$i4","$i2","$i1","$i1","$i3","$i1","$i1","$i1","$i1","$i1","$i2","$i4","$i2","$i1","-"),
	@("$i1","$i2","$i2","$i2","$i1","$i1","$i1","$i1","$i1","$i1","$i2","$i2","$i2","$i2","$i1","-"),
	@("$i1","$i2","$i3","$i1","$i2","$i2","$i2","$i2","$i2","$i2","$i1","$i3","$i2","$i2","$i1","-"),
	@("$i1","$i2","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i2","$i1","-"),
	@("$i1","$i2","$i4","$i2","$i2","$i2","$i2","$i2","$i2","$i2","$i2","$i2","$i4","$i2","$i1","-"),
	@("$i3","$i1","$i2","$i2","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i2","$i2","$i1","$i3","-"),
	@("-","$i3","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i3","-","-"),
	@("-","-","$i3","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i1","$i3","-","-","-"),
	@("-","-","-","$i3","$i3","$i3","$i3","$i3","$i3","$i3","$i3","$i3","-","-","-","-")
)
Draw-Rows $fc 0 0 $core
$fc.Save("$root\assets\world\tiles\forge_core.png", [System.Drawing.Imaging.ImageFormat]::Png)
$fc.Dispose()

# Patch terrain atlas at 5,3
$atlasPath = "$root\assets\world\tiles\terrain_atlas.png"
$atlas = [System.Drawing.Bitmap]::FromFile($atlasPath)
$g = [System.Drawing.Graphics]::FromImage($atlas)
$coreBmp = [System.Drawing.Bitmap]::FromFile("$root\assets\world\tiles\forge_core.png")
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$g.DrawImage($coreBmp, 80, 48, 16, 16)
$g.Dispose()
$coreBmp.Dispose()
$tmp = "$root\assets\world\tiles\terrain_atlas_tmp.png"
$atlas.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
$atlas.Dispose()
Move-Item -Force $tmp $atlasPath

# Door 16x48
$door = New-PxBitmap 16 48
$d1 = "#6B4226"; $d2 = "#8B5A2B"; $d3 = "#4A2E18"; $d4 = "#C4A06A"; $iron = "#4A4A52"; $knob = "#D4B45A"
for ($y = 0; $y -lt 48; $y++) {
	for ($x = 0; $x -lt 16; $x++) {
		$col = $d1
		if ($x -eq 0 -or $x -eq 15 -or $y -eq 0 -or $y -eq 47) { $col = $d3 }
		elseif (($x + $y) % 7 -eq 0) { $col = $d2 }
		elseif ($x -ge 3 -and $x -le 5) { $col = $d2 }
		Set-Px $door $x $y $col
	}
}
# planks
for ($band = 0; $band -lt 3; $band++) {
	$yy = 2 + $band * 15
	for ($x = 1; $x -lt 15; $x++) { Set-Px $door $x $yy $d3 }
}
# iron bands
foreach ($yy in @(10, 24, 38)) {
	for ($x = 1; $x -lt 15; $x++) { Set-Px $door $x $yy $iron }
}
# knob
Set-Px $door 12 24 $knob
Set-Px $door 13 24 $knob
Set-Px $door 12 25 $d4
$door.Save("$root\assets\buildings\forge_door.png", [System.Drawing.Imaging.ImageFormat]::Png)
$door.Dispose()

Write-Output "forge art ok"

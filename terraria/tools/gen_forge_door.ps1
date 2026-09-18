Add-Type -AssemblyName System.Drawing

function C([string]$hex) {
	$hex = $hex.TrimStart("#")
	return [System.Drawing.Color]::FromArgb(255, [Convert]::ToInt32($hex.Substring(0, 2), 16), [Convert]::ToInt32($hex.Substring(2, 2), 16), [Convert]::ToInt32($hex.Substring(4, 2), 16))
}

$w = 32
$h = 48
$bmp = New-Object System.Drawing.Bitmap $w, $h
$empty = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
$edge = C "3A2414"
$dark = C "5A3820"
$mid = C "7A4C28"
$lit = C "9A6434"
$iron = C "6A6E74"
$ironD = C "3E4248"
$ironL = C "A8ACB0"
$handle = C "C4A24A"
$cx = 15.5
$cy = 15.5
$rx = 14.2
$ry = 15.2
for ($y = 0; $y -lt $h; $y++) {
	for ($x = 0; $x -lt $w; $x++) {
		$inArch = $true
		if ($y -lt 16) {
			$dx = ($x - $cx) / $rx
			$dy = ($y - $cy) / $ry
			$inArch = ($dx * $dx + $dy * $dy) -le 1.0
		}
		if (-not $inArch -or $x -lt 1 -or $x -gt ($w - 2)) {
			$bmp.SetPixel($x, $y, $empty)
			continue
		}
		$nx = $x - 1
		$ny = $y
		$col = $mid
		if ($y -lt 16) {
			$dx2 = ($x - $cx) / ($rx - 1.2)
			$dy2 = ($y - $cy) / ($ry - 1.2)
			$inner = ($dx2 * $dx2 + $dy2 * $dy2) -le 1.0
			if (-not $inner) { $col = $edge }
			elseif ((([int][Math]::Floor($nx / 4.0)) % 2) -eq 0) { $col = $lit }
			else { $col = $dark }
		}
		else {
			if ($x -le 2 -or $x -ge ($w - 3) -or $y -ge ($h - 2)) { $col = $edge }
			elseif ((([int][Math]::Floor($nx / 4.0)) % 2) -eq 0) { $col = $lit }
			else { $col = $dark }
		}
		$bmp.SetPixel($x, $y, $col)
	}
}
for ($y = 18; $y -lt ($h - 3); $y += 8) {
	for ($x = 4; $x -lt ($w - 4); $x++) {
		$bmp.SetPixel($x, $y, $ironD)
	}
}
for ($y = 20; $y -lt 28; $y++) {
	$bmp.SetPixel(22, $y, $handle)
	$bmp.SetPixel(23, $y, $handle)
}
$bmp.SetPixel(24, 23, $handle)
$bmp.SetPixel(25, 24, $ironL)
$out = "c:\github\Last-Lantern\terraria\assets\buildings\forge_door.png"
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "wrote $out"

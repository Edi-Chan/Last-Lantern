$utf8 = New-Object System.Text.UTF8Encoding $false
# UTF-8 bytes for mojibake of umlauts (UTF-8 interpreted as Latin-1, then re-encoded)
$repl = @(
    ,@(0xC3,0x83,0xC2,0xBC), (0xC3,0xBC)  # ü
    ,@(0xC3,0x83,0xC2,0xB6), (0xC3,0xB6)  # ö
    ,@(0xC3,0x83,0xC2,0xA4), (0xC3,0xA4)  # ä
    ,@(0xC3,0x83,0xC5,0xB8), (0xC3,0x9F)  # ß sometimes
    ,@(0xC3,0x83,0xE2,0x80,0x9E), (0xC3,0x9F) # ß another
    ,@(0xC3,0x83,0xC2,0x96), (0xC3,0x96)  # Ö
)
function Replace-Bytes([byte[]]$data, [byte[]]$find, [byte[]]$rep) {
    $out = New-Object System.Collections.Generic.List[byte]
    $i = 0
    while ($i -lt $data.Length) {
        $match = $true
        if ($i + $find.Length -le $data.Length) {
            for ($k = 0; $k -lt $find.Length; $k++) {
                if ($data[$i + $k] -ne $find[$k]) { $match = $false; break }
            }
        } else { $match = $false }
        if ($match) {
            foreach ($b in $rep) { $out.Add($b) }
            $i += $find.Length
        } else {
            $out.Add($data[$i])
            $i++
        }
    }
    return [byte[]]$out.ToArray()
}
$n = 0
Get-ChildItem -Path "c:\github\Last-Lantern\terraria\resources\items\building","c:\github\Last-Lantern\terraria\resources\blocks\building" -Recurse -Filter *.tres | ForEach-Object {
    $data = [IO.File]::ReadAllBytes($_.FullName)
    $orig = $data
    $data = Replace-Bytes $data @(0xC3,0x83,0xC2,0xBC) @(0xC3,0xBC)
    $data = Replace-Bytes $data @(0xC3,0x83,0xC2,0xB6) @(0xC3,0xB6)
    $data = Replace-Bytes $data @(0xC3,0x83,0xC2,0xA4) @(0xC3,0xA4)
    $data = Replace-Bytes $data @(0xC3,0x83,0xC2,0x9F) @(0xC3,0x9F)
    $data = Replace-Bytes $data @(0xC3,0x83,0xC5,0xB8) @(0xC3,0x9F)
    $data = Replace-Bytes $data @(0xC3,0x83,0xC2,0x96) @(0xC3,0x96)
    $changed = $false
    if ($data.Length -ne $orig.Length) { $changed = $true }
    else { for ($i=0; $i -lt $data.Length; $i++) { if ($data[$i] -ne $orig[$i]) { $changed = $true; break } } }
    if ($changed) {
        [IO.File]::WriteAllBytes($_.FullName, $data)
        $n++
        Write-Output $_.Name
    }
}
Write-Output "fixed=$n"

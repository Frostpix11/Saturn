# raw-<name>.png -> ico\<name>.ico (256..16, PNG entries): hard alpha, crop to content, centered with 8% padding
Add-Type -AssemblyName System.Drawing
$D = $PSScriptRoot   # put the 1024px raw-<name>.png renders here; New-Item -ItemType Directory -Force "$D\ico", "$D\clean" | Out-Null
$sizes = 256,128,64,48,40,32,24,20,16
foreach ($raw in Get-ChildItem "$D\raw-*.png") {
  $name = $raw.BaseName.Substring(4)
  $src = New-Object Drawing.Bitmap ([Drawing.Image]::FromFile($raw.FullName))
  $r = New-Object Drawing.Rectangle 0, 0, $src.Width, $src.Height
  $bd = $src.LockBits($r, 'ReadWrite', 'Format32bppArgb'); $px = New-Object byte[] ($bd.Stride * $src.Height)
  [Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $px, 0, $px.Length)
  $minX = $src.Width; $minY = $src.Height; $maxX = 0; $maxY = 0
  for ($y = 0; $y -lt $src.Height; $y++) { $row = $y * $bd.Stride
    for ($x = 0; $x -lt $src.Width; $x++) { $i = $row + $x * 4
      if ($px[$i+3] -lt 140) { $px[$i+3] = 0 } else { $px[$i+3] = 255; if ($x -lt $minX) {$minX=$x}; if ($x -gt $maxX) {$maxX=$x}; if ($y -lt $minY) {$minY=$y}; if ($y -gt $maxY) {$maxY=$y} } } }
  [Runtime.InteropServices.Marshal]::Copy($px, 0, $bd.Scan0, $px.Length); $src.UnlockBits($bd)
  $w = $maxX - $minX + 1; $h = $maxY - $minY + 1; $side = [int]([Math]::Max($w, $h) * 1.08)
  $sq = New-Object Drawing.Bitmap $side, $side, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [Drawing.Graphics]::FromImage($sq); $g.DrawImage($src, (New-Object Drawing.Rectangle ([int](($side-$w)/2)), ([int](($side-$h)/2)), $w, $h), (New-Object Drawing.Rectangle $minX, $minY, $w, $h), 'Pixel'); $g.Dispose(); $src.Dispose()
  $sq.Save("$D\clean\$name.png")
  $pngs = foreach ($s in $sizes) {
    $b = New-Object Drawing.Bitmap $s, $s, ([Drawing.Imaging.PixelFormat]::Format32bppArgb); $g = [Drawing.Graphics]::FromImage($b)
    $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'; $g.CompositingQuality = 'HighQuality'
    $g.DrawImage($sq, 0, 0, $s, $s); $g.Dispose()
    $ms = New-Object IO.MemoryStream; $b.Save($ms, [Drawing.Imaging.ImageFormat]::Png); $b.Dispose(); ,@($s, $ms.ToArray()) }
  $sq.Dispose()
  $fs = [IO.File]::Create("$D\ico\$name.ico"); $wr = New-Object IO.BinaryWriter $fs
  $wr.Write([uint16]0); $wr.Write([uint16]1); $wr.Write([uint16]$pngs.Count); $off = 6 + 16 * $pngs.Count
  foreach ($p in $pngs) { $s = $p[0]; $len = $p[1].Length; $bs = $(if ($s -ge 256) {0} else {$s})
    $wr.Write([byte]$bs); $wr.Write([byte]$bs); $wr.Write([byte]0); $wr.Write([byte]0); $wr.Write([uint16]1); $wr.Write([uint16]32); $wr.Write([uint32]$len); $wr.Write([uint32]$off); $off += $len }
  foreach ($p in $pngs) { $wr.Write($p[1]) }; $wr.Close(); "ico $name ($w x $h)"
}

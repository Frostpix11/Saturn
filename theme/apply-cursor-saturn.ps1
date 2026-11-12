# Qogir Saturn cursor (recolored Mauve: gold fill, dark teal outline) for the current user (HKCU)
$ErrorActionPreference = 'Stop'
$D = "$HOME\Icons\Catmocha\cursors\Cursors\Qogir-Saturn-Windows"
$K = 'HKCU:\Control Panel\Cursors'
# backup already made earlier
#reg.exe export 'HKCU\Control Panel\Cursors' "$PSScriptRoot\backup\cursors-backup.reg" /y | Out-Null

$map = [ordered]@{
  Arrow='default.cur'; Help='help.cur'; AppStarting='half-busy.ani'; Wait='wait.ani'
  IBeam='text.cur'; No='forbidden.cur'; SizeNS='size_ver.cur'; SizeWE='size_hor.cur'
  SizeNWSE='size_fdiag.cur'; SizeNESW='size_bdiag.cur'; SizeAll='fleur.cur'; Hand='hand1.cur'
  Crosshair='cross.cur'; NWPen='pencil.cur'; UpArrow='up-arrow.cur'
}
foreach ($name in $map.Keys) {
  $f = Join-Path $D $map[$name]; if (-not (Test-Path $f)) { throw "missing $f" }
  New-ItemProperty $K -Name $name -Value $f -PropertyType ExpandString -Force | Out-Null
}
Set-ItemProperty $K -Name '(default)' -Value 'Qogir Saturn'
New-ItemProperty $K -Name 'Scheme Source' -Value 1 -PropertyType DWord -Force | Out-Null
# save as a user scheme so it shows up in the Mouse settings list
$list = ($map.Keys | ForEach-Object { Join-Path $D $map[$_] }) -join ','
if (-not (Test-Path "$K\Schemes")) { New-Item "$K\Schemes" | Out-Null }
New-ItemProperty "$K\Schemes" -Name 'Qogir Saturn' -Value $list -PropertyType ExpandString -Force | Out-Null

Add-Type -Namespace W -Name U -MemberDefinition '[DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint a, uint b, System.IntPtr c, uint d);'
[W.U]::SystemParametersInfo(0x57, 0, [IntPtr]::Zero, 3) | Out-Null   # SPI_SETCURSORS
'cursor ok'

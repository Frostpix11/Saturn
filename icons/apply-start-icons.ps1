# Point every .lnk in a Start menu folder at the matching Saturn icon (icons\ico\<name>.ico).
# Match is by the shortcut's CURRENT icon file name (e.g. ...\discord.ico -> ico\discord.ico),
# or pass -map @{ 'Discord' = 'discord' } to match by shortcut name. Same .lnk + AUMID -> pins stay.
param([string]$dir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs", [hashtable]$map = @{})
$sh = New-Object -ComObject Shell.Application; $ws = New-Object -ComObject WScript.Shell
foreach ($f in Get-ChildItem $dir -Filter *.lnk) {
  $name = $map[$f.BaseName]
  if (-not $name) { $cur = ($ws.CreateShortcut($f.FullName).IconLocation -split ',')[0]; $name = [IO.Path]::GetFileNameWithoutExtension($cur) }
  $ico = "$PSScriptRoot\ico\$name.ico"; if (-not (Test-Path $ico)) { continue }
  $l = $sh.NameSpace($dir).ParseName($f.Name).GetLink; $l.SetIconLocation($ico, 0); $l.Save(); "{0,-16} -> {1}" -f $f.BaseName, $ico
}

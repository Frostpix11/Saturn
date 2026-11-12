# Import the Saturn settings for Windhawk mods from windhawk\settings\*.json.
# 1) Install the mods in Windhawk first (names = file names, see README). 2) Run this as admin.
# Writes HKLM\SOFTWARE\Windhawk\Engine\Mods\<mod>\Settings and bumps SettingsChangeTime so the mods reload.
# Each mod's current settings are exported to windhawk\backup\<mod>.reg before overwriting.
#Requires -RunAsAdministrator
param([string[]]$only)
$base = 'HKLM:\SOFTWARE\Windhawk\Engine\Mods'
New-Item -ItemType Directory -Force "$PSScriptRoot\backup" | Out-Null
foreach ($f in Get-ChildItem "$PSScriptRoot\settings\*.json") {
  $id = $f.BaseName -replace '^local_', 'local@'
  if ($only -and $id -notin $only) { continue }
  if (-not (Test-Path "$base\$id")) { Write-Warning "$id is not installed in Windhawk, skipped"; continue }
  reg.exe export "HKLM\SOFTWARE\Windhawk\Engine\Mods\$id" "$PSScriptRoot\backup\$($f.BaseName).reg" /y | Out-Null
  $key = Get-Item "$base\$id"
  $set = $key.CreateSubKey('Settings', $true)
  # drop old values first (names with [] break PowerShell wildcards -> .NET API)
  foreach ($n in $set.GetValueNames()) { $set.DeleteValue($n) }
  $o = Get-Content $f.FullName -Raw | ConvertFrom-Json
  foreach ($p in $o.PSObject.Properties) {
    if ($p.Value -is [long] -or $p.Value -is [int]) { $set.SetValue($p.Name, [int]$p.Value, 'DWord') }
    else { $set.SetValue($p.Name, ([string]$p.Value).Replace('C:\Users\YOU', $env:USERPROFILE), 'String') }
  }
  $set.Close()
  $key2 = $key.OpenSubKey('', $true); if (-not $key2) { $key2 = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SOFTWARE\Windhawk\Engine\Mods\$id", $true) }
  $key2.SetValue('SettingsChangeTime', [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds(), 'DWord'); $key2.Close()
  "{0,-40} {1} values" -f $id, @($o.PSObject.Properties).Count
}

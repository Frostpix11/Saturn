# Celestia session start. Order matters:
#   1) shell pieces: komorebi + whkd hotkeys, masir (focus follows mouse), edge scrolling, "+" watcher, widgets
#   2) komorebi lands on desk 1 (not on the clean desk "+")
#   3) only then (-boot) the heavy apps that used to sit in HKCU Run, so they open on desk 1 / their own desk
# Runs at logon from HKCU Run "CelestiaShell" with -boot; restart-shell.ps1 calls it without -boot.
param([switch]$boot)
$k = 'C:\Program Files\komorebi\bin\komorebic.exe'
if (-not (Get-Process komorebi -ErrorAction SilentlyContinue)) { Start-Process $k -ArgumentList 'start', '--whkd' -WindowStyle Hidden }
if (-not (Get-Process masir -ErrorAction SilentlyContinue)) { Start-Process 'C:\Program Files\masir\bin\masir.exe' -WindowStyle Hidden }

# wait until komorebi answers, then leave the clean desk
for ($i = 0; $i -lt 40; $i++) { $s = & $k state 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue; if ($s) { break }; Start-Sleep -Milliseconds 250 }
& $k focus-workspace 1 | Out-Null
& powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\cycle-columns.ps1" apply   # Win+R width presets

$ps = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"
foreach ($helper in 'komorebi-edge', 'komorebi-desk0') {
  if (-not ($ps | Where-Object CommandLine -match "$helper\.ps1")) {
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSScriptRoot\$helper.ps1"
  }
}
# Rainmeter widgets + media/GPU helper
if (-not ($ps | Where-Object CommandLine -match 'media-helper\.ps1')) {
  Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSScriptRoot\..\..\widgets\media-helper.ps1"
}
if (-not (Get-Process Rainmeter -ErrorAction SilentlyContinue)) { Start-Process 'C:\Program Files\Rainmeter\Rainmeter.exe' }

if ($boot) {
  Start-Sleep 2   # let the "+" watcher connect first
  $apps = @(
    @('Discord',           "$env:LOCALAPPDATA\Discord\Discord.exe",                                  '--processStart Discord.exe --process-start-args "--start-inactive"'),
    @('Spotify',           "$env:APPDATA\Spotify\Spotify.exe",                                       '--autostart --minimized'),
    @('steam',             'C:\Program Files (x86)\Steam\steam.exe',                                 '-silent'),
    @('EpicGamesLauncher', 'C:\Program Files\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe', '-silent -launchcontext=boot')
  )
  foreach ($a in $apps) {
    if (-not (Get-Process $a[0] -ErrorAction SilentlyContinue) -and (Test-Path $a[1])) { Start-Process $a[1] -ArgumentList $a[2] }
  }
}

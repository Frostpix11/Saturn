# Safe Explorer restart for the Celestia rice.
# Restarting explorer.exe while komorebi / YASB are running makes the new shell hang (no wallpaper, no taskbar).
# Order: stop everything that hooks the shell -> restart Explorer -> YASB -> komorebi -> fix window placement -> helpers.
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$k = 'C:\Program Files\komorebi\bin\komorebic.exe'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object CommandLine -match 'komorebi-(desk0|edge)\.ps1' | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Stop-Process -Name komorebi, komorebic, whkd, masir, yasb, Rainmeter -Force -ErrorAction SilentlyContinue
Start-Sleep 2
Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep 3
Start-Process explorer.exe
Start-Sleep 10
& 'C:\Program Files\YASB\yasbc.exe' start | Out-Null
Start-Sleep 4
Start-Process $k -ArgumentList 'start', '--whkd' -WindowStyle Hidden
Start-Sleep 8
# komorebi re-adopts open windows one desk too low (they land on "+"): put them back before the "+" watcher starts
$s = & $k state | ConvertFrom-Json
$zero = $s.monitors.elements[0].workspaces.elements[0]
if (@($zero.containers.elements).Count -gt 0) { & "$PSScriptRoot\..\komorebi\scripts\shift-windows.ps1" | Out-Null }
& "$PSScriptRoot\..\komorebi\scripts\start-all.ps1"

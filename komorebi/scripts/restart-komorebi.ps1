# Restart komorebi only (needed when a rule was REMOVED from komorebi.json: reload-configuration only adds rules).
# komorebi re-adopts open windows one desk too low on restart -> put them back before the "+" watcher starts.
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$k = 'C:\Program Files\komorebi\bin\komorebic.exe'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object CommandLine -match 'komorebi-desk0\.ps1' | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Stop-Process -Name komorebi, komorebic -Force -ErrorAction SilentlyContinue
Start-Sleep 2
Start-Process $k -ArgumentList 'start' -WindowStyle Hidden
Start-Sleep 8
$s = & $k state | ConvertFrom-Json
if (@($s.monitors.elements[0].workspaces.elements[0].containers.elements).Count -gt 0) { & "$PSScriptRoot\shift-windows.ps1" | Out-Null }
& "$PSScriptRoot\cycle-columns.ps1" apply
Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$PSScriptRoot\komorebi-desk0.ps1"

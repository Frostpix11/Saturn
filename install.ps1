<#
  Celestia Saturn rice - installer.
  Run from the repo folder, which must be  %USERPROFILE%\Saturn  (hotkeys point there):

    git clone https://github.com/Frostpix11/Saturn "$env:USERPROFILE\Saturn"
    cd "$env:USERPROFILE\Saturn"
    powershell -ExecutionPolicy Bypass -File .\install.ps1

  Every config it replaces is backed up next to the original as *.bak-celestia.
  Skip parts with switches:  -NoPackages -NoWallpaper -NoAccent -NoAutostart
  Windhawk mods are installed by hand (see README), then: windhawk\import-settings.ps1 (as admin).
#>
param([switch]$NoPackages, [switch]$NoWallpaper, [switch]$NoAccent, [switch]$NoAutostart)
$ErrorActionPreference = 'Stop'
$R = $PSScriptRoot
$H = $env:USERPROFILE
if ($R -ne "$H\Saturn") { Write-Warning "Repo is at $R, expected $H\Saturn. Hotkeys (Win+R) will not find their scripts. Move it and run again."; return }

function Step($t) { Write-Host "`n== $t" -ForegroundColor Yellow }
function Backup($p) { if (Test-Path $p) { Copy-Item $p "$p.bak-celestia" -Recurse -Force } }
function Put($src, $dst, [switch]$utf16) {
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  $t = [IO.File]::ReadAllText($src).Replace('C:\Users\YOU', $H).Replace('C:\\Users\\YOU', $H.Replace('\', '\\'))
  if ($utf16) { [IO.File]::WriteAllText($dst, $t, [Text.Encoding]::Unicode) } else { [IO.File]::WriteAllText($dst, $t, (New-Object Text.UTF8Encoding $false)) }
}

# 1. packages ---------------------------------------------------------------------------------
if (-not $NoPackages) {
  Step 'Packages (winget, official sources)'
  $pkgs = 'LGUG2Z.komorebi', 'LGUG2Z.whkd', 'LGUG2Z.masir', 'AmN.yasb', 'Rainmeter.Rainmeter', 'RamenSoftware.Windhawk',
          'Microsoft.PowerToys', 'voidtools.Everything', 'DEVCOM.JetBrainsMonoNerdFont', 'Microsoft.WindowsTerminal'
  foreach ($p in $pkgs) {
    Write-Host "  $p"
    winget install --id $p -e --silent --accept-package-agreements --accept-source-agreements | Out-Null
  }
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

# 2. tiling: komorebi + whkd -----------------------------------------------------------------
Step 'komorebi + whkd'
Backup "$H\komorebi.json"; Copy-Item "$R\komorebi\komorebi.json" "$H\komorebi.json" -Force
Backup "$H\.config\whkdrc"; Put "$R\komorebi\whkdrc" "$H\.config\whkdrc"
if (-not (Test-Path "$H\applications.json")) { try { & 'C:\Program Files\komorebi\bin\komorebic.exe' fetch-asc | Out-Null } catch { Write-Warning 'komorebic fetch-asc failed, run it later' } }

# 3. YASB bar --------------------------------------------------------------------------------
Step 'YASB'
Backup "$H\.config\yasb"
foreach ($f in 'config.yaml', 'styles.css', 'yasb_colors.css') { Put "$R\yasb\$f" "$H\.config\yasb\$f" }

# 4. Rainmeter widgets + weather location ---------------------------------------------------
Step 'Rainmeter widgets'
$skins = "$H\Documents\Rainmeter\Skins\Saturn"; Backup $skins
foreach ($f in Get-ChildItem "$R\rainmeter\Saturn" -Recurse -File) { Put $f.FullName ($f.FullName.Replace("$R\rainmeter\Saturn", $skins)) -utf16 }
$loc = "$env:LOCALAPPDATA\Celestia\location.ini"
if (-not (Test-Path $loc)) {
  New-Item -ItemType Directory -Force (Split-Path $loc) | Out-Null
  $city = Read-Host 'Weather: your city (empty = Kyiv)'
  $lat = '50.45'; $lon = '30.52'
  if ($city) {
    try {
      $g = (Invoke-RestMethod "https://geocoding-api.open-meteo.com/v1/search?count=1&name=$([uri]::EscapeDataString($city))").results[0]
      $lat = '{0:0.00}' -f $g.latitude; $lon = '{0:0.00}' -f $g.longitude; Write-Host "  $($g.name), $($g.country): $lat $lon"
    } catch { Write-Warning 'city not found, using Kyiv; edit the file later' }
  }
  Set-Content $loc "Lat=$($lat.Replace(',', '.'))`r`nLon=$($lon.Replace(',', '.'))"
}
Write-Host '  load them in Rainmeter: Saturn\Clock, Saturn\Music, Saturn\System (positions are in the .ini files)'

# 5. Windows Terminal + Spotify colors -----------------------------------------------------
Step 'Terminal / Spotify'
Write-Host '  Terminal: paste terminal\saturn.json "schemes" + "themes" into settings.json (manual, keeps your profiles)'
$sp = "$env:APPDATA\spicetify"
if (Test-Path "$sp\Themes") {
  Write-Host '  Spicetify found: copy spicetify\color-saturn.ini into your theme color.ini, then: spicetify config color_scheme saturn; spicetify apply'
}

# 6. accent + wallpaper ---------------------------------------------------------------------
if (-not $NoAccent) { Step 'Accent color'; & "$R\theme\apply-accent.ps1" }
if (-not $NoWallpaper) {
  Step 'Wallpaper'
  $wp = "$H\Pictures\Wallpapers\saturn-eclipse.png"; New-Item -ItemType Directory -Force (Split-Path $wp) | Out-Null
  Copy-Item "$R\wallpaper\saturn-eclipse.png" $wp -Force
  Add-Type 'using System.Runtime.InteropServices; public class WP { [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int SystemParametersInfo(int a, int b, string c, int d); }'
  [WP]::SystemParametersInfo(20, 0, $wp, 3) | Out-Null
  # lock screen needs WinRT -> Windows PowerShell 5.1
  powershell -NoProfile -Command "[Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime]|Out-Null; [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]|Out-Null; Add-Type -AssemblyName System.Runtime.WindowsRuntime; `$m=([System.WindowsRuntimeSystemExtensions].GetMethods()|?{`$_.Name -eq 'AsTask' -and `$_.GetParameters().Count -eq 1 -and `$_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation``1'})[0]; `$t=`$m.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke(`$null,@([Windows.Storage.StorageFile]::GetFileFromPathAsync('$wp'))); `$t.Wait(); [Windows.System.UserProfile.LockScreen]::SetImageFileAsync(`$t.Result)|Out-Null" 2>$null
  $we = 'C:\Program Files (x86)\Steam\steamapps\common\wallpaper_engine'
  if (Test-Path $we) {
    $dst = "$we\projects\myprojects\saturn-eclipse"; Copy-Item "$R\wallpaper\wallpaper-engine\saturn-eclipse" (Split-Path $dst) -Recurse -Force
    Write-Host "  live wallpaper copied to Wallpaper Engine (My Projects -> Saturn Eclipse)"
  }
}

# 7. autostart ------------------------------------------------------------------------------
if (-not $NoAutostart) {
  Step 'Autostart'
  & 'C:\Program Files\YASB\yasbc.exe' enable-autostart --task | Out-Null
  $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$R\komorebi\scripts\start-all.ps1`" -boot"
  Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' CelestiaShell $cmd
  Write-Host '  YASB = scheduled task, komorebi/masir/widgets = HKCU Run "CelestiaShell"'
  Write-Host '  tip: remove Discord/Spotify/Steam/Epic from their own autostart; start-all.ps1 -boot opens them AFTER the tiling is up'
}

Step 'Done'
Write-Host @"
  Next:
   1. Windhawk: install the mods listed in README, then run windhawk\import-settings.ps1 as admin
   2. PowerToys Keyboard Manager (optional): Caps Lock -> Win+Space, Win+Shift+Space -> Caps Lock
   3. Start everything now:  powershell -File "$R\komorebi\scripts\start-all.ps1"
"@

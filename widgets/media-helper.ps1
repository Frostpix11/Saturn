# Celestia media helper for the Rainmeter "Saturn\Music" widget.
# Reads the current media session (Windows SMTC: Spotify, browsers...) and writes
#   %LOCALAPPDATA%\Celestia\nowplaying.ini   [NP] Title, Artist, Status(playing|paused|none)
#   %LOCALAPPDATA%\Celestia\cover.png        album art
# Rainmeter buttons write [Cmd] Action=prev|toggle|next|<stamp> into cmd.ini; this script executes it.
# Run hidden with Windows PowerShell 5.1 (WinRT): powershell -NoProfile -WindowStyle Hidden -File media-helper.ps1
$ErrorActionPreference = 'SilentlyContinue'
$mtx = New-Object System.Threading.Mutex($false, 'Local\celestia-media-helper')
if (-not $mtx.WaitOne(0)) { return }

$dir = "$env:LOCALAPPDATA\Celestia"; New-Item -ItemType Directory -Force $dir | Out-Null
$npFile = "$dir\nowplaying.ini"; $coverFile = "$dir\cover.png"; $cmdFile = "$env:USERPROFILE\Documents\Rainmeter\Skins\Saturn\@Resources\cmd.ini"   # Rainmeter may only write inside its skins folder
if (-not (Test-Path $cmdFile)) { Set-Content $cmdFile "[Cmd]`r`nAction=" -Encoding Unicode }

Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type @'
using System; using System.IO; using System.Runtime.InteropServices; using System.Runtime.InteropServices.ComTypes;
public static class RasCopy {
  [DllImport("shcore.dll")] static extern int CreateStreamOverRandomAccessStream([MarshalAs(UnmanagedType.IUnknown)] object ras, ref Guid riid, out IStream stream);
  public static int Save(object ras, string path) {
    Guid g = new Guid("0000000c-0000-0000-C000-000000000046"); IStream st;
    int hr = CreateStreamOverRandomAccessStream(ras, ref g, out st); if (hr != 0) return hr;
    byte[] buf = new byte[65536]; IntPtr pRead = Marshal.AllocHGlobal(4); int total = 0;
    using (var f = File.Create(path)) { while (true) { st.Read(buf, buf.Length, pRead); int n = Marshal.ReadInt32(pRead); if (n <= 0) break; f.Write(buf, 0, n); total += n; } }
    Marshal.FreeHGlobal(pRead); Marshal.ReleaseComObject(st); return total;
  }
}
'@
$asTaskG = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, [Type]$t) { $task = $asTaskG.MakeGenericMethod($t).Invoke($null, @($op)); $task.Wait(3000) | Out-Null; $task.Result }
[Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime] | Out-Null
[Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime] | Out-Null
$mgrT = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
$mgr = Await ($mgrT::RequestAsync()) $mgrT
$propsT = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]

function Save-Cover($thumb) {
  # unique file name per track: Rainmeter caches images by path
  $script:coverFile = "$dir\cover_$([DateTime]::Now.Ticks).png"
  Get-ChildItem "$dir\cover_*.png" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -Skip 2 | Remove-Item -Force
  try {
    # PowerShell can't use the projected WinRT stream, so go through a COM IStream (shcore)
    $s = Await ($thumb.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
    [RasCopy]::Save($s, $script:coverFile) | Out-Null
  } catch {}
}
function Write-NP($title, $artist, $status) {
  $txt = "[NP]`r`nTitle=$title`r`nArtist=$artist`r`nStatus=$status`r`nCover=$script:coverFile`r`nEnd=1`r`n"
  [IO.File]::WriteAllText($npFile, $txt, [Text.Encoding]::Unicode)
}

# freshGram rewrites tdata\AyuGram-default.ico and its two shortcuts on every start -> put the Catmocha icon back
$fgIco = "$env:LOCALAPPDATA\Programs\freshGram\tdata\AyuGram-default.ico"
$fgCat = "$env:USERPROFILE\Saturn\taskbar\icons\telegram.ico"
$fgLnks = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\freshGram.lnk", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\freshGram.lnk"
$fgCatHash = (Get-FileHash $fgCat).Hash   # optional freshGram fix: only runs if you put a telegram.ico there
$shellApp = New-Object -ComObject Shell.Application; $wsh = New-Object -ComObject WScript.Shell
function Fix-FreshGramIcon {
  if (-not (Test-Path $fgCat)) { return }
  if ((Test-Path $fgIco) -and (Get-FileHash $fgIco).Hash -ne $fgCatHash) {
    try { Set-ItemProperty $fgIco IsReadOnly $false; Copy-Item $fgCat $fgIco -Force } catch {}
  }
  foreach ($l in $fgLnks) {
    if (-not (Test-Path $l)) { continue }
    if ($wsh.CreateShortcut($l).IconLocation -notlike "*telegram.ico*") {
      try { $lnk = $shellApp.NameSpace((Split-Path $l)).ParseName((Split-Path $l -Leaf)).GetLink; $lnk.SetIconLocation($fgCat, 0); $lnk.Save() } catch {}
    }
  }
}

# weather for the Saturn\Clock widget (Open-Meteo, no key; only the city coordinates are sent)
# your city: %LOCALAPPDATA%\Celestia\location.ini  ->  Lat=50.45 / Lon=30.52 (install.ps1 asks for it)
$loc = @{ Lat = '50.45'; Lon = '30.52' }
if (Test-Path "$dir\location.ini") { Get-Content "$dir\location.ini" | % { if ($_ -match '^(Lat|Lon)=(.+)$') { $loc[$matches[1]] = $matches[2].Trim() } } }
$wxUrl = "https://api.open-meteo.com/v1/forecast?latitude=$($loc.Lat)&longitude=$($loc.Lon)&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,is_day&daily=temperature_2m_max,temperature_2m_min&forecast_days=1&timezone=auto&wind_speed_unit=ms"
function Update-Weather {
  try {
    $r = Invoke-RestMethod $wxUrl -TimeoutSec 10
    $c = [int]$r.current.weather_code; $day = [int]$r.current.is_day -eq 1
    # WMO code -> nerd-font glyph + short Russian text
    $map = @{
      0 = @(($(if ($day) { [char]0xE30D } else { [char]0xE32B })), 'ясно'); 1 = @(($(if ($day) { [char]0xE30C } else { [char]0xE379 })), 'малооблачно')
      2 = @(($(if ($day) { [char]0xE302 } else { [char]0xE37E })), 'облачно'); 3 = @([char]0xE312, 'пасмурно')
      45 = @([char]0xE313, 'туман'); 48 = @([char]0xE313, 'изморозь')
      51 = @([char]0xE31B, 'морось'); 53 = @([char]0xE31B, 'морось'); 55 = @([char]0xE31B, 'морось')
      61 = @([char]0xE318, 'дождь'); 63 = @([char]0xE318, 'дождь'); 65 = @([char]0xE318, 'ливень')
      66 = @([char]0xE3AD, 'ледяной дождь'); 67 = @([char]0xE3AD, 'ледяной дождь')
      71 = @([char]0xE31A, 'снег'); 73 = @([char]0xE31A, 'снег'); 75 = @([char]0xE31A, 'снегопад'); 77 = @([char]0xE31A, 'снег')
      80 = @([char]0xE319, 'ливень'); 81 = @([char]0xE319, 'ливень'); 82 = @([char]0xE319, 'ливень')
      85 = @([char]0xE35E, 'снег'); 86 = @([char]0xE35E, 'снегопад'); 95 = @([char]0xE31D, 'гроза'); 96 = @([char]0xE31D, 'гроза'); 99 = @([char]0xE31D, 'гроза')
    }
    $m = $map[$c]; if (-not $m) { $m = @([char]0xE312, '') }
    $t = [math]::Round([double]$r.current.temperature_2m); $f = [math]::Round([double]$r.current.apparent_temperature)
    $hi = [math]::Round([double]$r.daily.temperature_2m_max[0]); $lo = [math]::Round([double]$r.daily.temperature_2m_min[0])
    $w = [math]::Round([double]$r.current.wind_speed_10m)
    $txt = "[WX]`r`nIcon=$($m[0])`r`nTemp=$($t)°`r`nDesc=$($m[1])`r`nMore=ощущ. $($f)°  ·  $($lo)…$($hi)°  ·  $w м/с`r`nEnd=1`r`n"
    [IO.File]::WriteAllText("$dir\weather.ini", $txt, [Text.Encoding]::Unicode)
  } catch {}
}
Update-Weather; $lastWx = [DateTime]::UtcNow

$lastKey = ''; $lastCmd = ''; $tick = 0
while ($true) {
  Start-Sleep -Milliseconds 80; $tick++
  $ses = $mgr.GetCurrentSession()
  # commands from Rainmeter buttons
  $raw = [IO.File]::ReadAllText($cmdFile)
  if ($raw -match 'Action=(\S+)' -and $matches[1] -ne $lastCmd) {
    $lastCmd = $matches[1]; $act = ($lastCmd -split '\|')[0]
    if ($ses) {
      switch ($act) { 'prev' { $ses.TrySkipPreviousAsync() | Out-Null } 'toggle' { $ses.TryTogglePlayPauseAsync() | Out-Null } 'next' { $ses.TrySkipNextAsync() | Out-Null } }
      $tick = 2   # re-read metadata right after a button press
    }
  }
  if ($tick % 25 -eq 0) {   # GPU load + temp every 2 s (NVIDIA driver tool) for Saturn\System
    $g = (& nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>$null) -split ',\s*'
    if ($g.Count -ge 2) { [IO.File]::WriteAllText("$dir\gpu.ini", "[GPU]`r`nLoad=$($g[0].Trim())`r`nTemp=$([int][double]::Parse($g[1].Trim(), [Globalization.CultureInfo]::InvariantCulture))`r`nEnd=1`r`n", [Text.Encoding]::Unicode) }
  }
  if ($tick % 25 -eq 5) { Fix-FreshGramIcon }
  if (([DateTime]::UtcNow - $lastWx).TotalMinutes -ge 15) { Update-Weather; $lastWx = [DateTime]::UtcNow }
  if ($tick % 3 -ne 0) { continue }   # metadata every ~240 ms
  if (-not $ses) { if ($lastKey -ne 'none') { Write-NP '' '' 'none'; $lastKey = 'none' }; continue }
  $p = Await ($ses.TryGetMediaPropertiesAsync()) $propsT
  $st = if ($ses.GetPlaybackInfo().PlaybackStatus -eq 4) { 'playing' } else { 'paused' }
  $key = "$($p.Title)|$($p.Artist)|$st"
  if ($key -ne $lastKey) {
    if (($lastKey -split '\|')[0] -ne $p.Title -and $p.Thumbnail) { Save-Cover $p.Thumbnail }
    Write-NP $p.Title $p.Artist $st; $lastKey = $key
  }
}

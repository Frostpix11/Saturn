# komorebi-desk0: niri-style dynamic workspaces for komorebi.
#  - workspace 0 "+" is the clean desk: a window that lands there (opened on it, or Win+Ctrl+0)
#    moves to a new desk appended at the end (unnamed -> the bar shows its number), focus follows;
#  - desks 1-5 come from komorebi.json and are permanent;
#  - a dynamic desk (index 6+) that you leave empty is closed (numbers after it shift down, like niri).
# Listens to komorebi events via `komorebic subscribe-pipe`; idle = no CPU.
$k = 'C:\Program Files\komorebi\bin\komorebic.exe'
$pipeName = 'celestia-desk0'
$widthFile = "$env:LOCALAPPDATA\komorebi\celestia-widths.json"
$log = "$env:LOCALAPPDATA\komorebi\celestia-desk0.log"
$FIXED = 6   # "+", 1..5

Add-Type @'
using System; using System.Runtime.InteropServices;
public class D0 { [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte sc, uint f, UIntPtr e); }
'@
$mtx = New-Object System.Threading.Mutex($false, 'Local\komorebi-desk0')
if (-not $mtx.WaitOne(0)) { return }

function Count-Wins($ws) { @($ws.containers.elements).Count + @($ws.floating_windows.elements | Where-Object { $_.hwnd }).Count }
function Width-For([int]$ws) { try { $v = (Get-Content -Raw $widthFile | ConvertFrom-Json)."$ws"; if ($v) { return [double]$v } } catch {}; 0.5 }
function Log($s) { "$(Get-Date -f HH:mm:ss.fff) $s" | Add-Content $log }
function State { & $k state | ConvertFrom-Json }

# window landed on "+": move it to a fresh desk at the end
function Spill($state) {
  $mi = $state.monitors.focused; $mon = $state.monitors.elements[$mi]; $wss = $mon.workspaces
  if ($wss.focused -ne 0) { return }
  $zero = $wss.elements[0]
  $win = @(@($zero.containers.elements) | ForEach-Object { $_.windows.elements }) + @($zero.floating_windows.elements | Where-Object { $_.hwnd })
  if (-not $win.Count) { return }
  $new = $wss.elements.Count
  & $k new-workspace | Out-Null
  & $k focus-workspace 0 | Out-Null          # new-workspace switches to the new desk; come back so the window is the focused one
  & $k workspace-layout $mi $new scrolling | Out-Null
  $W = [int]$mon.work_area_size.right; $L = [int](($W - $W * (Width-For $new)) / 2)
  & $k workspace-work-area-offset $mi $new $L 0 (2 * $L) 0 | Out-Null
  [D0]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [D0]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
  [D0]::SetForegroundWindow([IntPtr][long]$win[0].hwnd) | Out-Null; Start-Sleep -Milliseconds 250
  & $k move-to-workspace $new | Out-Null
  & $k scrolling-layout-columns 1 | Out-Null
  & $k retile | Out-Null
  Log "spill $($win[0].exe) -> ws$new"
}

# left an empty dynamic desk: close it (close-workspace works only on the focused, empty, unnamed one)
function Reap($state, [int]$left) {
  $mi = $state.monitors.focused; $wss = $state.monitors.elements[$mi].workspaces
  if ($left -lt $FIXED -or $left -ge $wss.elements.Count) { return }
  $ws = $wss.elements[$left]
  if ((Count-Wins $ws) -gt 0 -or $ws.name) { return }
  $target = [int]$wss.focused; if ($target -gt $left) { $target-- }
  & $k focus-workspace $left | Out-Null
  & $k close-workspace | Out-Null
  & $k focus-workspace $target | Out-Null
  Log "reap ws$left (back to ws$target)"
}

$script:quietUntil = [DateTime]::MinValue
$script:lastFocus = -1
while ($true) {
  try {
    # big in-buffer: komorebi writes every event synchronously; while we wait on komorebic nobody reads,
    # and with a small buffer komorebi blocks on the write -> deadlock (seen 2026-11-12)
    $srv = New-Object System.IO.Pipes.NamedPipeServerStream($pipeName, [System.IO.Pipes.PipeDirection]::In, 1,
      [System.IO.Pipes.PipeTransmissionMode]::Byte, [System.IO.Pipes.PipeOptions]::None, 8MB, 0)
    Start-Process $k -ArgumentList 'subscribe-pipe', $pipeName -WindowStyle Hidden
    $srv.WaitForConnection(); Log 'pipe connected'
    $rd = New-Object System.IO.StreamReader($srv)
    while ($srv.IsConnected) {
      $line = $rd.ReadLine(); if ($null -eq $line) { break }
      if ($line.Length -lt 2 -or [DateTime]::UtcNow -lt $script:quietUntil) { continue }   # skip echoes of our own commands
      try {
        $msg = $line | ConvertFrom-Json; if (-not $msg.state) { continue }
        $wss = $msg.state.monitors.elements[$msg.state.monitors.focused].workspaces
        $focus = [int]$wss.focused; $acted = $false
        if ((Count-Wins $wss.elements[0]) -gt 0 -and $focus -eq 0) { Spill (State); $acted = $true }
        elseif ($script:lastFocus -ge $FIXED -and $script:lastFocus -ne $focus) { Reap (State) $script:lastFocus; $acted = $true }
        if ($acted) { $script:quietUntil = [DateTime]::UtcNow.AddMilliseconds(1200); $focus = [int](State).monitors.elements[0].workspaces.focused }
        $script:lastFocus = $focus
      } catch {}
    }
  } catch {}
  try { $srv.Dispose() } catch {}
  Start-Sleep 3
}

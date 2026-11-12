# move every managed window from workspace i to i+1 (highest first) - fixes the off-by-one after inserting "+"
$k = 'C:\Program Files\komorebi\bin\komorebic.exe'
Add-Type @'
using System; using System.Runtime.InteropServices;
public class SH { [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte sc, uint f, UIntPtr e); }
'@
$s = & $k state | ConvertFrom-Json; $wss = $s.monitors.elements[0].workspaces.elements
for ($i = $wss.Count - 2; $i -ge 0; $i--) {
  $wins = @(@($wss[$i].containers.elements) | % { $_.windows.elements }) + @($wss[$i].floating_windows.elements | ? { $_.hwnd })
  if (-not $wins.Count) { continue }
  & $k focus-workspace $i | Out-Null; Start-Sleep -Milliseconds 500
  foreach ($w in $wins) {
    [SH]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [SH]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    [SH]::SetForegroundWindow([IntPtr][long]$w.hwnd) | Out-Null; Start-Sleep -Milliseconds 400
    & $k send-to-workspace ($i + 1) | Out-Null; Start-Sleep -Milliseconds 400
  }
}
& $k focus-workspace 1 | Out-Null; Start-Sleep 1
$s = & $k state | ConvertFrom-Json; $wss = $s.monitors.elements[0].workspaces.elements
for ($i = 0; $i -lt $wss.Count; $i++) { "ws$i '$($wss[$i].name)': " + (((@($wss[$i].containers.elements) | % { $_.windows.elements[0].exe }) + (@($wss[$i].floating_windows.elements) | % { $_.exe })) -join ',') }

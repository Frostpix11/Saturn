# niri-style Win+R / Win+Alt+R: cycle the column width preset of the FOCUSED workspace (1/3, 1/2, 2/3, full).
# niri-style centering in komorebi: Scrolling with ONE visible column + a centered, narrowed work area
# (workspace-work-area-offset) -> the focused column always sits in the middle and neighbours peek at the sides.
# Each workspace keeps its own width (state file: JSON map "workspace index" -> fraction).
# 'apply' re-applies every stored width (used at startup).
param([ValidateSet('next','prev','apply')][string]$dir = 'next')
$k = 'C:\Program Files\komorebi\bin\komorebic.exe'
$presets = 0.33333, 0.5, 0.66667, 1.0
$inv = [Globalization.CultureInfo]::InvariantCulture
$stateFile = "$env:LOCALAPPDATA\komorebi\celestia-widths.json"
$widths = @{}
if (Test-Path $stateFile) { try { (Get-Content -Raw $stateFile | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $widths[$_.Name] = [double]$_.Value } } catch {} }

$st = & $k state | ConvertFrom-Json
$mon = $st.monitors.elements[0]
$W = [int]$mon.work_area_size.right
$count = $mon.workspaces.elements.Count

function Set-Width([int]$ws, [double]$f) {
  $L = [int](($W - $W * $f) / 2)
  & $k workspace-work-area-offset 0 $ws $L 0 (2 * $L) 0 | Out-Null
}

if ($dir -eq 'apply') {
  for ($ws = 0; $ws -lt $count; $ws++) { $f = 0.5; if ($widths.ContainsKey("$ws")) { $f = $widths["$ws"] }; Set-Width $ws $f }
} else {
  $ws = [int]$mon.workspaces.focused
  $cur = 0.5; if ($widths.ContainsKey("$ws")) { $cur = $widths["$ws"] }
  $i = 1; for ($n = 0; $n -lt $presets.Count; $n++) { if ([math]::Abs($presets[$n] - $cur) -lt 0.01) { $i = $n } }
  $i = if ($dir -eq 'next') { ($i + 1) % $presets.Count } else { ($i - 1 + $presets.Count) % $presets.Count }
  $widths["$ws"] = $presets[$i]
  Set-Width $ws $presets[$i]
}
$out = '{' + (($widths.Keys | Sort-Object | ForEach-Object { '"' + $_ + '":' + $widths[$_].ToString($inv) }) -join ',') + '}'
Set-Content $stateFile $out
& $k retile | Out-Null

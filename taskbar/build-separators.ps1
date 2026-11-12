# Build taskbar separators: N copies of a tiny exe with a thin-line icon. Each copy pins as its own taskbar button.
# Uses the C# compiler that ships with Windows (.NET Framework 4). Usage: .\build-separators.ps1 -count 4, then run each with --pin.
param([int]$count = 4)
$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$out = "$PSScriptRoot\separators"; New-Item -ItemType Directory -Force $out | Out-Null
& $csc /nologo /target:winexe /win32icon:"$PSScriptRoot\separator.ico" /out:"$out\Separator.exe" /r:System.Windows.Forms.dll /r:System.Drawing.dll "$PSScriptRoot\Separator.cs"
1..$count | ForEach-Object { Copy-Item "$out\Separator.exe" "$out\sep$_.exe" -Force }
Remove-Item "$out\Separator.exe"
"built $count separators in $out  ->  run: & '$out\sep1.exe' --pin   (then right-click its taskbar icon -> Pin)"

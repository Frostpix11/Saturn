# komorebi-edge.ps1: runs komorebi-edge.cs in-memory (a compiled .exe is blocked by Smart App Control)
# start hidden: powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File komorebi-edge.ps1
$src = Get-Content -Raw "$PSScriptRoot\komorebi-edge.cs"
$src = $src -replace 'static class KomorebiEdge', 'public static class KomorebiEdge' -replace 'static void Main\(\)', 'public static void Main()'
Add-Type -TypeDefinition $src -Language CSharp
[KomorebiEdge]::Main()

// komorebi-edge: niri-like "push the cursor into the screen edge to scroll the strip".
// Cursor resting on the left/right edge (not corners, not the top bar / taskbar zone) for DwellMs
// focuses the neighbour column (komorebic focus left|right); holding it there keeps scrolling.
// Ignored while a mouse button is held and while a game from GameExes is in the foreground.
// Build: csc /target:winexe /out:komorebi-edge.exe komorebi-edge.cs
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

static class KomorebiEdge {
    const int PollMs = 25, DwellMs = 180, RepeatMs = 450, TopSafe = 45, BottomSafe = 70;
    static readonly string[] GameExes = { "FortniteClient-Win64-Shipping.exe" };
    const string Komorebic = @"C:\Program Files\komorebi\bin\komorebic.exe";

    [StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }
    [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
    [DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern bool QueryFullProcessImageNameW(IntPtr h, uint f, StringBuilder s, ref uint n);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);

    static bool GameInFront() {
        uint pid; GetWindowThreadProcessId(GetForegroundWindow(), out pid);
        IntPtr h = OpenProcess(0x1000, false, pid);
        if (h == IntPtr.Zero) return false;
        var sb = new StringBuilder(512); uint n = 512;
        bool ok = QueryFullProcessImageNameW(h, 0, sb, ref n); CloseHandle(h);
        if (!ok) return false;
        string name = System.IO.Path.GetFileName(sb.ToString());
        foreach (var g in GameExes) if (string.Equals(name, g, StringComparison.OrdinalIgnoreCase)) return true;
        return false;
    }

    static void Focus(string dir) {
        try {
            var psi = new ProcessStartInfo(Komorebic, "focus " + dir) { CreateNoWindow = true, UseShellExecute = false };
            using (Process.Start(psi)) { }
        } catch { }
    }

    static void Main() {
        bool created;
        using (new Mutex(true, "Local\\komorebi-edge", out created)) {
            if (!created) return;
            int side = 0; DateTime since = DateTime.MinValue, last = DateTime.MinValue;
            while (true) {
                Thread.Sleep(PollMs);
                POINT p; if (!GetCursorPos(out p)) continue;
                int w = GetSystemMetrics(0), h = GetSystemMetrics(1);
                bool buttons = (GetAsyncKeyState(0x01) & 0x8000) != 0 || (GetAsyncKeyState(0x02) & 0x8000) != 0;
                int now = (p.Y > TopSafe && p.Y < h - BottomSafe && !buttons) ? (p.X <= 0 ? -1 : (p.X >= w - 1 ? 1 : 0)) : 0;
                if (now != side) { side = now; since = DateTime.UtcNow; last = DateTime.MinValue; continue; }
                if (side == 0) continue;
                var t = DateTime.UtcNow;
                if ((t - since).TotalMilliseconds < DwellMs) continue;
                if (last != DateTime.MinValue && (t - last).TotalMilliseconds < RepeatMs) continue;
                if (GameInFront()) { last = t; continue; }
                Focus(side < 0 ? "left" : "right");
                last = t;
            }
        }
    }
}

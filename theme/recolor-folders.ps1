# Copies the Catmocha black theme to "Catmocha saturn" and recolors the folder icons in its imageres.dll to the Saturn palette
param([switch]$preview)
$src = "$HOME\Icons\Catmocha\themes\black\Catmocha black"
$dst = "$HOME\Icons\Catmocha\themes\black\Catmocha saturn"
if (-not $preview) { if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }; Copy-Item $src $dst -Recurse }
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing @'
using System; using System.IO; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class Rec {
  delegate bool LCB(IntPtr m, IntPtr t, IntPtr n, ushort l, IntPtr p);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr LoadLibraryEx(string f, IntPtr h, uint fl);
  [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr FindResourceEx(IntPtr m, IntPtr t, IntPtr n, ushort l);
  [DllImport("kernel32.dll")] static extern bool EnumResourceLanguages(IntPtr m, IntPtr t, IntPtr n, LCB cb, IntPtr p);
  [DllImport("kernel32.dll")] static extern IntPtr LoadResource(IntPtr m, IntPtr r);
  [DllImport("kernel32.dll")] static extern IntPtr LockResource(IntPtr r);
  [DllImport("kernel32.dll")] static extern uint SizeofResource(IntPtr m, IntPtr r);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr BeginUpdateResource(string f, bool del);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool UpdateResource(IntPtr h, IntPtr type, IntPtr name, ushort lang, byte[] d, uint n);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool EndUpdateResource(IntPtr h, bool discard);
  static int[][] map = {
    new[]{0x45,0x47,0x5A, 0x1F,0x4D,0x46}, new[]{0x44,0x46,0x59, 0x1F,0x4D,0x46},
    new[]{0x56,0x56,0x67, 0x2B,0x60,0x56}, new[]{0x37,0x39,0x48, 0x15,0x38,0x32},
    new[]{0xF5,0xE0,0xDC, 0xE3,0xB0,0x5C}, new[]{0xBA,0xC2,0xDE, 0xF1,0xE6,0xC4},
    new[]{0x7C,0x81,0x98, 0x8F,0xB5,0xA3} };
  static void Px(ref byte r, ref byte g, ref byte b) {
    int best = -1, bd = 1 << 30;
    for (int i = 0; i < map.Length; i++) { int dr = r - map[i][0], dg = g - map[i][1], db = b - map[i][2]; int d = dr*dr + dg*dg + db*db; if (d < bd) { bd = d; best = i; } }
    if (bd > 30*30*3) return;
    var m = map[best];
    r = (byte)Math.Max(0, Math.Min(255, m[3] + (r - m[0]))); g = (byte)Math.Max(0, Math.Min(255, m[4] + (g - m[1]))); b = (byte)Math.Max(0, Math.Min(255, m[5] + (b - m[2])));
  }
  static byte[] Res(IntPtr mod, int type, int id, out ushort lang) {
    ushort found = 0; EnumResourceLanguages(mod, (IntPtr)type, (IntPtr)id, (a,b,c,l,p) => { found = l; return false; }, IntPtr.Zero); lang = found;
    IntPtr r = FindResourceEx(mod, (IntPtr)type, (IntPtr)id, found); if (r == IntPtr.Zero) return null;
    uint n = SizeofResource(mod, r); byte[] d = new byte[n]; Marshal.Copy(LockResource(LoadResource(mod, r)), d, 0, (int)n); return d;
  }
  static byte[] RecolorPng(byte[] d) {
    using (var ms = new MemoryStream(d)) using (var src = new Bitmap(ms)) using (var bm = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb)) {
      using (var g = Graphics.FromImage(bm)) g.DrawImage(src, 0, 0, src.Width, src.Height);
      var bd = bm.LockBits(new Rectangle(0, 0, bm.Width, bm.Height), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
      byte[] px = new byte[bd.Stride * bm.Height]; Marshal.Copy(bd.Scan0, px, 0, px.Length);
      for (int i = 0; i < px.Length; i += 4) Px(ref px[i+2], ref px[i+1], ref px[i]);
      Marshal.Copy(px, 0, bd.Scan0, px.Length); bm.UnlockBits(bd);
      using (var o = new MemoryStream()) { bm.Save(o, ImageFormat.Png); return o.ToArray(); } }
  }
  static void RecolorDib(byte[] d) {
    int hs = BitConverter.ToInt32(d, 0), bpp = BitConverter.ToUInt16(d, 14); if (bpp != 32) return;
    int w = BitConverter.ToInt32(d, 4), h = BitConverter.ToInt32(d, 8) / 2;
    for (int i = hs; i < hs + w * h * 4 && i + 3 < d.Length; i += 4) Px(ref d[i+2], ref d[i+1], ref d[i]);
  }
  public static string Run(string srcDll, string dstDll, int[] groups) {
    IntPtr mod = LoadLibraryEx(srcDll, IntPtr.Zero, 0x22); if (mod == IntPtr.Zero) return "load fail";
    IntPtr h = BeginUpdateResource(dstDll, false); if (h == IntPtr.Zero) return "begin " + Marshal.GetLastWin32Error();
    int imgs = 0, png = 0, dib = 0;
    foreach (int gid in groups) {
      ushort gl; byte[] grp = Res(mod, 14, gid, out gl); if (grp == null) continue;
      int count = BitConverter.ToUInt16(grp, 4);
      for (int i = 0; i < count; i++) {
        int iid = BitConverter.ToUInt16(grp, 6 + i * 14 + 12);
        ushort il; byte[] img = Res(mod, 3, iid, out il); if (img == null) continue;
        byte[] outb;
        if (img.Length > 8 && img[0] == 0x89 && img[1] == 0x50) { outb = RecolorPng(img); png++; } else { outb = (byte[])img.Clone(); RecolorDib(outb); dib++; }
        if (!UpdateResource(h, (IntPtr)3, (IntPtr)iid, il, outb, (uint)outb.Length)) return "update " + iid + " err " + Marshal.GetLastWin32Error();
        imgs++;
      }
    }
    return EndUpdateResource(h, false) ? ("ok images=" + imgs + " png=" + png + " dib=" + dib) : ("end " + Marshal.GetLastWin32Error());
  }
}
'@
$groups = 3,4,5,6,9,10,18,73,74,77,108,112,113,115,123,129,143,162,181,184,185,186,189,190,198,1001,1002,1003,1004,1005,1014,1020,1040,5353
[Rec]::Run("$src\Windhawk Resources\imageres.dll", "$dst\Windhawk Resources\imageres.dll", $groups)

# recolors an .ico (PNG and 32bpp DIB entries) with a nearest-anchor map: "RRGGBB=RRGGBB,..."
param([string]$in, [string]$out, [string]$map)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing @'
using System; using System.IO; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class RI {
  public static int[][] M;
  static void Px(ref byte r, ref byte g, ref byte b) {
    int best = -1, bd = 1 << 30;
    for (int i = 0; i < M.Length; i++) { int dr = r - M[i][0], dg = g - M[i][1], db = b - M[i][2]; int d = dr*dr + dg*dg + db*db; if (d < bd) { bd = d; best = i; } }
    if (bd > 30*30*3) return; var m = M[best];
    r = (byte)Math.Max(0, Math.Min(255, m[3] + (r - m[0]))); g = (byte)Math.Max(0, Math.Min(255, m[4] + (g - m[1]))); b = (byte)Math.Max(0, Math.Min(255, m[5] + (b - m[2])));
  }
  static byte[] Png(byte[] d) {
    using (var ms = new MemoryStream(d)) using (var src = new Bitmap(ms)) using (var bm = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb)) {
      using (var g = Graphics.FromImage(bm)) g.DrawImage(src, 0, 0, src.Width, src.Height);
      var bd = bm.LockBits(new Rectangle(0, 0, bm.Width, bm.Height), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
      byte[] px = new byte[bd.Stride * bm.Height]; Marshal.Copy(bd.Scan0, px, 0, px.Length);
      for (int i = 0; i < px.Length; i += 4) Px(ref px[i+2], ref px[i+1], ref px[i]);
      Marshal.Copy(px, 0, bd.Scan0, px.Length); bm.UnlockBits(bd);
      using (var o = new MemoryStream()) { bm.Save(o, ImageFormat.Png); return o.ToArray(); } }
  }
  public static string Run(string inp, string outp) {
    byte[] f = File.ReadAllBytes(inp); int n = BitConverter.ToUInt16(f, 4);
    var imgs = new byte[n][];
    for (int i = 0; i < n; i++) { int o = 6 + i * 16; int sz = BitConverter.ToInt32(f, o + 8), off = BitConverter.ToInt32(f, o + 12);
      byte[] d = new byte[sz]; Array.Copy(f, off, d, 0, sz);
      if (d[0] == 0x89 && d[1] == 0x50) d = Png(d);
      else if (BitConverter.ToUInt16(d, 14) == 32) { int hs = BitConverter.ToInt32(d, 0), w = BitConverter.ToInt32(d, 4), h = BitConverter.ToInt32(d, 8) / 2; for (int p = hs; p < hs + w*h*4; p += 4) Px(ref d[p+2], ref d[p+1], ref d[p]); }
      imgs[i] = d; }
    using (var w = new BinaryWriter(File.Create(outp))) {
      w.Write(f, 0, 6); int off2 = 6 + 16 * n;
      for (int i = 0; i < n; i++) { int o = 6 + i * 16; w.Write(f, o, 8); w.Write(imgs[i].Length); w.Write(off2); off2 += imgs[i].Length; }
      foreach (var d in imgs) w.Write(d); }
    return "ok " + n + " images";
  }
}
'@
[RI]::M = @($map -split ',' | % { $a, $b = $_ -split '='; ,[int[]]@([Convert]::ToInt32($a.Substring(0,2),16),[Convert]::ToInt32($a.Substring(2,2),16),[Convert]::ToInt32($a.Substring(4,2),16),[Convert]::ToInt32($b.Substring(0,2),16),[Convert]::ToInt32($b.Substring(2,2),16),[Convert]::ToInt32($b.Substring(4,2),16)) })
[RI]::Run($in, $out)

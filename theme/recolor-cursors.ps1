# Qogir Catppuccin Mauve -> "Qogir Saturn": recolors .cur and .ani (fill -> gold, outline -> dark teal), keeps hotspots
$src = "$HOME\Icons\Catmocha\cursors\Cursors\Qogir-Catppuccin-Mauve-Windows"
$dst = "$HOME\Icons\Catmocha\cursors\Cursors\Qogir-Saturn-Windows"
New-Item -ItemType Directory -Force $dst | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing @'
using System; using System.IO; using System.Collections.Generic; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class RC {
  // old outline O, old fill F  ->  new outline O2, new fill F2 (linear along the O..F line, so antialiasing stays smooth)
  static int[] O = {0x29,0x21,0x31}, F = {0xCB,0xA6,0xF7}, O2 = {0x04,0x13,0x12}, F2 = {0xE3,0xB0,0x5C};
  public static int Touched, Skipped;
  static void Px(ref byte r, ref byte g, ref byte b) {
    double[] v = {r - O[0], g - O[1], b - O[2]}, d = {F[0]-O[0], F[1]-O[1], F[2]-O[2]};
    double dd = d[0]*d[0]+d[1]*d[1]+d[2]*d[2], t = (v[0]*d[0]+v[1]*d[1]+v[2]*d[2]) / dd;
    double tc = Math.Max(0, Math.Min(1, t));
    double ex = v[0]-d[0]*tc, ey = v[1]-d[1]*tc, ez = v[2]-d[2]*tc;
    if (ex*ex+ey*ey+ez*ez > 45*45) { Skipped++; return; }
    Touched++;
    r = (byte)Math.Round(O2[0] + (F2[0]-O2[0])*tc); g = (byte)Math.Round(O2[1] + (F2[1]-O2[1])*tc); b = (byte)Math.Round(O2[2] + (F2[2]-O2[2])*tc);
  }
  static byte[] Png(byte[] d) {
    using (var ms = new MemoryStream(d)) using (var src = new Bitmap(ms)) using (var bm = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb)) {
      using (var g = Graphics.FromImage(bm)) { g.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy; g.DrawImage(src, 0, 0, src.Width, src.Height); }
      var bd = bm.LockBits(new Rectangle(0, 0, bm.Width, bm.Height), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
      byte[] px = new byte[bd.Stride * bm.Height]; Marshal.Copy(bd.Scan0, px, 0, px.Length);
      for (int i = 0; i < px.Length; i += 4) if (px[i+3] > 0) Px(ref px[i+2], ref px[i+1], ref px[i]);
      Marshal.Copy(px, 0, bd.Scan0, px.Length); bm.UnlockBits(bd);
      using (var o = new MemoryStream()) { bm.Save(o, ImageFormat.Png); return o.ToArray(); } }
  }
  public static byte[] Cur(byte[] f) {
    int n = BitConverter.ToUInt16(f, 4); var imgs = new byte[n][];
    for (int i = 0; i < n; i++) { int o = 6 + i*16; int sz = BitConverter.ToInt32(f, o+8), off = BitConverter.ToInt32(f, o+12);
      byte[] d = new byte[sz]; Array.Copy(f, off, d, 0, sz);
      if (d[0] == 0x89 && d[1] == 0x50) d = Png(d);
      else if (BitConverter.ToUInt16(d, 14) == 32) { int hs = BitConverter.ToInt32(d, 0), w = BitConverter.ToInt32(d, 4), h = BitConverter.ToInt32(d, 8)/2; for (int p = hs; p < hs + w*h*4 && p+3 < d.Length; p += 4) if (d[p+3] > 0) Px(ref d[p+2], ref d[p+1], ref d[p]); }
      imgs[i] = d; }
    var ms = new MemoryStream(); var w2 = new BinaryWriter(ms);
    w2.Write(f, 0, 6); int off2 = 6 + 16*n;
    for (int i = 0; i < n; i++) { int o = 6 + i*16; w2.Write(f, o, 8); w2.Write(imgs[i].Length); w2.Write(off2); off2 += imgs[i].Length; }
    foreach (var d in imgs) w2.Write(d); return ms.ToArray();
  }
  // RIFF rebuild: recolor every 'icon' chunk, recompute sizes of LIST/RIFF containers
  static byte[] Chunks(byte[] f, int start, int end) {
    var ms = new MemoryStream(); int p = start;
    while (p + 8 <= end) {
      string id = System.Text.Encoding.ASCII.GetString(f, p, 4); int sz = BitConverter.ToInt32(f, p+4);
      byte[] body;
      if (id == "LIST") { byte[] inner = Chunks(f, p+12, p+8+sz); body = new byte[4 + inner.Length]; Array.Copy(f, p+8, body, 0, 4); Array.Copy(inner, 0, body, 4, inner.Length); }
      else { body = new byte[sz]; Array.Copy(f, p+8, body, 0, sz); if (id == "icon") body = Cur(body); }
      ms.Write(f, p, 4); ms.Write(BitConverter.GetBytes(body.Length), 0, 4); ms.Write(body, 0, body.Length); if ((body.Length & 1) == 1) ms.WriteByte(0);
      p += 8 + sz + (sz & 1);
    }
    return ms.ToArray();
  }
  public static byte[] Ani(byte[] f) {
    byte[] inner = Chunks(f, 12, 8 + BitConverter.ToInt32(f, 4));
    var ms = new MemoryStream(); ms.Write(f, 0, 4); ms.Write(BitConverter.GetBytes(inner.Length + 4), 0, 4); ms.Write(f, 8, 4); ms.Write(inner, 0, inner.Length); return ms.ToArray();
  }
}
'@
foreach ($fi in Get-ChildItem $src -File) {
  $b = [IO.File]::ReadAllBytes($fi.FullName); [RC]::Touched = 0; [RC]::Skipped = 0
  if ($fi.Extension -eq '.cur') { $o = [RC]::Cur($b) } elseif ($fi.Extension -eq '.ani') { $o = [RC]::Ani($b) } else { $o = $b }
  [IO.File]::WriteAllBytes("$dst\$($fi.Name)", $o)
  "{0,-16} recolored={1} kept={2}" -f $fi.Name, [RC]::Touched, [RC]::Skipped
}

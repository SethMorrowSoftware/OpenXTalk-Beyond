<#
.SYNOPSIS
    Builds the OXT-Beyond icon and splash images from Tom Perry's
    OpenXTalk Lite artwork.

.DESCRIPTION
    Takes the largest image in ide/OpenXTalk-lite_1024.ico (Tom Perry's
    OpenXTalk Lite icon), removes the word "Lite", fills in the circle behind
    it, and draws "Beyond" in its place in the orange and dark outline of the
    "OXT" lettering (the "OXT" letters stay in front, with the same drop
    shadow they cast on "Lite"). Then it writes:

      Installer/oxt-beyond/branding/source/oxt-lite-icon-512.png
          the unmodified source image, for reference
      Installer/oxt-beyond/branding/png/oxt-beyond-<size>.png
          16, 24, 32, 48, 64, 128, 256, 512 and 1024 px
      ide/OXT-Beyond.ico
          16, 24, 32, 48, 64 and 128 px as 32-bit bitmaps, 256 px as PNG
      engine/rsrc/oxt-beyond.ico
          the same icon, for engine/rsrc/development.rc
      ide/Toolset/resources/community/ideSkin/splash*.png (with -Splash)
          the IDE splash screens with the icon replaced; the originals are
          read from git (-SplashSourceRev) so the step can be repeated

    The source image is 512 px, so the 1024 px PNG is the source enlarged
    with the "Beyond" lettering drawn at full resolution.

    Uses only Windows PowerShell / PowerShell 7 and System.Drawing (GDI+),
    with the "Arial Black" font that ships with Windows.

.PARAMETER RepoRoot
    Repository root. Default: three levels up from this script.

.PARAMETER FillColor
    Fill colour of "Beyond" as #RRGGBB. Default #FF7700, the orange of "OXT".
    (#FFE400 is the yellow that "Lite" used.)

.PARAMETER Splash
    Also rewrite the four splash images.

.PARAMETER SplashSourceRev
    Git revision to read the original splash images from.
    Default: 523b3b208 (the OpenXTalk Lite 1.15 IDE import).

.PARAMETER Preview
    Optional path of an extra 256 px PNG preview to write.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$FillColor = '#FF7700',
    [switch]$Splash,
    [string]$SplashSourceRev = '523b3b208',
    [string]$Preview
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path }
$sourceIco = Join-Path $RepoRoot 'ide\OpenXTalk-lite_1024.ico'
if (-not (Test-Path -LiteralPath $sourceIco -PathType Leaf)) { throw "Source icon not found: $sourceIco" }

if ($PSVersionTable.PSEdition -eq 'Core') {
    $refs = @('System.Drawing.Common', 'System.Drawing.Primitives', 'System.Runtime.InteropServices', 'System.Collections')
}
else {
    $refs = @('System.Drawing')
}

$code = @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class OxtBeyondBranding
{
    // Geometry of the source artwork at 512 px, measured from the image:
    // the outer edge of the circle (where its alpha crosses 50%).
    const double CircleX = 255.75, CircleY = 254.0, CircleR = 251.5;

    // ------------------------------------------------------------------
    // Pixels (straight ARGB)

    public static int[] Pixels(Bitmap bmp)
    {
        int w = bmp.Width, h = bmp.Height;
        Bitmap src = bmp;
        if (bmp.PixelFormat != PixelFormat.Format32bppArgb)
        {
            src = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (Graphics g = Graphics.FromImage(src))
            {
                g.CompositingMode = CompositingMode.SourceCopy;
                g.DrawImage(bmp, new Rectangle(0, 0, w, h));
            }
        }
        BitmapData d = src.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        int[] px = new int[w * h];
        for (int y = 0; y < h; y++)
            Marshal.Copy(new IntPtr(d.Scan0.ToInt64() + (long)y * d.Stride), px, y * w, w);
        src.UnlockBits(d);
        if (!object.ReferenceEquals(src, bmp)) src.Dispose();
        return px;
    }

    public static Bitmap ToBitmap(int[] px, int w, int h)
    {
        Bitmap b = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        BitmapData d = b.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
        for (int y = 0; y < h; y++)
            Marshal.Copy(px, y * w, new IntPtr(d.Scan0.ToInt64() + (long)y * d.Stride), w);
        b.UnlockBits(d);
        return b;
    }

    static int A(int c) { return (c >> 24) & 255; }
    static int R(int c) { return (c >> 16) & 255; }
    static int G(int c) { return (c >> 8) & 255; }
    static int B(int c) { return c & 255; }
    static int Argb(int a, int r, int g, int b)
    {
        return (Clamp(a) << 24) | (Clamp(r) << 16) | (Clamp(g) << 8) | Clamp(b);
    }
    static int Clamp(int v) { return v < 0 ? 0 : (v > 255 ? 255 : v); }

    // ------------------------------------------------------------------
    // ICO input: the largest image (PNG or 32-bit bitmap entry)

    static int BE32(byte[] d, int o) { return (d[o] << 24) | (d[o + 1] << 16) | (d[o + 2] << 8) | d[o + 3]; }
    static bool IsPng(byte[] d, int o) { return d[o] == 0x89 && d[o + 1] == 0x50 && d[o + 2] == 0x4E && d[o + 3] == 0x47; }

    public static Bitmap LargestIcoImage(string path, out byte[] pngBytes)
    {
        byte[] d = File.ReadAllBytes(path);
        int count = BitConverter.ToUInt16(d, 4);
        int best = -1; long bestArea = -1; int bw = 0, bh = 0;
        for (int i = 0; i < count; i++)
        {
            int o = 6 + 16 * i;
            int off = BitConverter.ToInt32(d, o + 12);
            int w, h;
            if (IsPng(d, off)) { w = BE32(d, off + 16); h = BE32(d, off + 20); }
            else { w = BitConverter.ToInt32(d, off + 4); h = BitConverter.ToInt32(d, off + 8) / 2; }
            if ((long)w * h > bestArea) { bestArea = (long)w * h; best = i; bw = w; bh = h; }
        }
        int eo = 6 + 16 * best;
        int size = BitConverter.ToInt32(d, eo + 8);
        int start = BitConverter.ToInt32(d, eo + 12);
        pngBytes = null;
        if (IsPng(d, start))
        {
            pngBytes = new byte[size];
            Array.Copy(d, start, pngBytes, 0, size);
            using (MemoryStream ms = new MemoryStream(pngBytes))
            using (Bitmap tmp = new Bitmap(ms))
            {
                return ToBitmap(Pixels(tmp), tmp.Width, tmp.Height);
            }
        }
        int bpp = BitConverter.ToUInt16(d, start + 14);
        if (bpp != 32) throw new Exception("Largest icon entry is a " + bpp + "-bit bitmap; only 32-bit is supported");
        int hdr = BitConverter.ToInt32(d, start);
        int[] px = new int[bw * bh];
        for (int y = 0; y < bh; y++)
            for (int x = 0; x < bw; x++)
            {
                int p = start + hdr + ((bh - 1 - y) * bw + x) * 4;
                px[y * bw + x] = Argb(d[p + 3], d[p + 2], d[p + 1], d[p]);
            }
        return ToBitmap(px, bw, bh);
    }

    // ------------------------------------------------------------------
    // Resampling

    public static Bitmap Resize(Bitmap src, int w, int h)
    {
        Bitmap cur = src;
        // Halve in steps first so that large reductions stay smooth.
        while (cur.Width >= w * 2 && cur.Height >= h * 2 && cur.Width / 2 >= w)
        {
            Bitmap half = Draw(cur, cur.Width / 2, cur.Height / 2);
            if (!object.ReferenceEquals(cur, src)) cur.Dispose();
            cur = half;
        }
        Bitmap result = Draw(cur, w, h);
        if (!object.ReferenceEquals(cur, src)) cur.Dispose();
        return result;
    }

    static Bitmap Draw(Bitmap src, int w, int h)
    {
        Bitmap dst = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(dst))
        using (ImageAttributes ia = new ImageAttributes())
        {
            g.Clear(Color.Transparent);
            g.CompositingMode = CompositingMode.SourceCopy;
            g.CompositingQuality = CompositingQuality.HighQuality;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.SmoothingMode = SmoothingMode.HighQuality;
            ia.SetWrapMode(WrapMode.TileFlipXY);
            g.DrawImage(src, new Rectangle(0, 0, w, h), 0, 0, src.Width, src.Height, GraphicsUnit.Pixel, ia);
        }
        return dst;
    }

    // ------------------------------------------------------------------
    // Separate the 512 px source into the parts we keep

    static bool IsOrangeCore(int c)
    {
        return A(c) > 200 && R(c) > 200 && G(c) >= 80 && G(c) <= 170 && B(c) < 70 && R(c) - G(c) > 70;
    }

    static bool IsYellowish(int c)
    {
        return A(c) > 200 && R(c) > 90 && G(c) > 80 && B(c) < 90 && Math.Abs(R(c) - G(c)) < 45 && R(c) - B(c) > 80;
    }

    static bool IsDark(int c) { return Math.Max(R(c), Math.Max(G(c), B(c))) < 90; }

    // Dark pixels with the olive tint of the shaded "Lite" letters (the
    // outline of "OXT" is black, or tinted orange where it meets the fill).
    static bool IsOliveTint(int c) { return R(c) - B(c) > 12 && G(c) > 0.7 * R(c); }

    static float[] DistanceField(bool[] core, int w, int h, int radius)
    {
        float[] dist = new float[w * h];
        for (int i = 0; i < dist.Length; i++) dist[i] = float.MaxValue;
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                if (!core[y * w + x]) continue;
                for (int dy = -radius; dy <= radius; dy++)
                {
                    int yy = y + dy; if (yy < 0 || yy >= h) continue;
                    for (int dx = -radius; dx <= radius; dx++)
                    {
                        int xx = x + dx; if (xx < 0 || xx >= w) continue;
                        float dd = (float)Math.Sqrt(dx * dx + dy * dy);
                        int k = yy * w + xx;
                        if (dd < dist[k]) dist[k] = dd;
                    }
                }
            }
        return dist;
    }

    public class Parts
    {
        public int Size;
        public int[] Plate;     // source with "Lite" removed and the circle filled in
        public int[] Overlay;   // the lower "OXT" letters and their outline, to draw in front
        public int[] Shadow;    // alpha mask of the lower "OXT" letters, for their drop shadow
    }

    public static Parts Separate(Bitmap source)
    {
        int w = source.Width, h = source.Height;
        if (w != 512 || h != 512) throw new Exception("Expected a 512 px source image, got " + w + "x" + h);
        int[] src = Pixels(source);
        const int LetterTop = 300;   // "OXT" letters that can touch "Beyond" start below this row
        const int LiteTop = 330;     // "Lite" starts below this row
        bool[] orange = new bool[w * h], yellow = new bool[w * h];
        for (int y = LetterTop - 20; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int c = src[y * w + x];
                orange[y * w + x] = IsOrangeCore(c);
                yellow[y * w + x] = y >= LiteTop && IsYellowish(c);
            }
        float[] distO = DistanceField(orange, w, h, 16);
        float[] distY = DistanceField(yellow, w, h, 16);

        bool[] oxt = new bool[w * h], lite = new bool[w * h];
        for (int y = LetterTop; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int k = y * w + x, c = src[k];
                if (A(c) == 0) continue;
                if (distO[k] <= 2.5f || (distO[k] <= 12f && IsDark(c) && !IsYellowish(c) && !IsOliveTint(c))) oxt[k] = true;
            }
        for (int y = LiteTop; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int k = y * w + x;
                if (!oxt[k] && distY[k] <= 14f && !IsOrangeCore(src[k])) lite[k] = true;
            }

        int[] plate = (int[])src.Clone();
        for (int y = LiteTop; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int k = y * w + x;
                if (!lite[k]) continue;
                double dx = x + 0.5 - CircleX, dy = y + 0.5 - CircleY;
                double r = Math.Sqrt(dx * dx + dy * dy);
                if (r > CircleR + 1.0) { plate[k] = 0; continue; }
                plate[k] = FillAlongArc(src, lite, oxt, distO, distY, w, h, r, Math.Atan2(dy, dx));
            }

        int[] overlay = new int[w * h], shadow = new int[w * h];
        for (int k = 0; k < w * h; k++)
            if (oxt[k]) { overlay[k] = src[k]; shadow[k] = Argb(255, 0, 0, 0); }

        Parts p = new Parts();
        p.Size = w; p.Plate = plate; p.Overlay = overlay; p.Shadow = shadow;
        return p;
    }

    // Fill a pixel of the circle that was behind "Lite" by following the
    // circle (same radius) left and right until the background shows, and
    // blending the two samples by angle. The shading of the circle is
    // concentric, so this continues it.
    static int FillAlongArc(int[] src, bool[] lite, bool[] oxt, float[] distO, float[] distY, int w, int h, double r, double theta)
    {
        double step = 0.75 / Math.Max(r, 20.0);
        double limit = 70.0 * Math.PI / 180.0;
        int[] found = new int[2]; double[] dist = new double[2]; bool[] ok = new bool[2];
        for (int side = 0; side < 2; side++)
        {
            double sign = side == 0 ? -1.0 : 1.0;
            for (double a = step; a <= limit; a += step)
            {
                double t = theta + sign * a;
                int qx = (int)Math.Floor(CircleX + r * Math.Cos(t));
                int qy = (int)Math.Floor(CircleY + r * Math.Sin(t));
                if (qx < 0 || qy < 0 || qx >= w || qy >= h) break;
                int q = qy * w + qx;
                if (lite[q] || oxt[q] || distO[q] <= 14f || distY[q] <= 14f || IsYellowish(src[q])) continue;
                found[side] = src[q]; dist[side] = a; ok[side] = true;
                break;
            }
        }
        if (ok[0] && ok[1])
        {
            double t = dist[0] / (dist[0] + dist[1]);
            return BlendPremultiplied(found[0], found[1], t);
        }
        if (ok[0]) return found[0];
        if (ok[1]) return found[1];
        return Argb(255, 0, 0, 0);
    }

    static int BlendPremultiplied(int c0, int c1, double t)
    {
        double a0 = A(c0) / 255.0, a1 = A(c1) / 255.0;
        double a = a0 * (1 - t) + a1 * t;
        if (a <= 0) return 0;
        double r = (R(c0) * a0 * (1 - t) + R(c1) * a1 * t) / a;
        double g = (G(c0) * a0 * (1 - t) + G(c1) * a1 * t) / a;
        double b = (B(c0) * a0 * (1 - t) + B(c1) * a1 * t) / a;
        return Argb((int)Math.Round(a * 255), (int)Math.Round(r), (int)Math.Round(g), (int)Math.Round(b));
    }

    // ------------------------------------------------------------------
    // Compose the icon at 512 or 1024 px

    public static Bitmap Compose(Parts parts, int size, Color fill)
    {
        double k = size / (double)parts.Size;
        Bitmap plate = ToBitmap(parts.Plate, parts.Size, parts.Size);
        Bitmap overlay = ToBitmap(parts.Overlay, parts.Size, parts.Size);
        Bitmap shadowSrc = ToBitmap(parts.Shadow, parts.Size, parts.Size);
        Bitmap canvas = size == parts.Size ? (Bitmap)plate.Clone() : Draw(plate, size, size);
        Bitmap overlayS = size == parts.Size ? (Bitmap)overlay.Clone() : Draw(overlay, size, size);

        // The drop shadow the "OXT" letters cast downwards (9 px at 512 px).
        Bitmap shadow = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(shadow))
        {
            g.Clear(Color.Transparent);
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.DrawImage(shadowSrc, new RectangleF(0f, (float)(9 * k), size, size));
        }

        // "Beyond", in Arial Black, fitted to the band that "Lite" used.
        GraphicsPath path = new GraphicsPath();
        using (FontFamily family = new FontFamily("Arial Black"))
        {
            path.AddString("Beyond", family, (int)FontStyle.Regular, 1000f, new PointF(0, 0), StringFormat.GenericTypographic);
        }
        RectangleF b = path.GetBounds();
        double outline = 9 * k;
        double boxL = 25 * k, boxR = 487 * k, boxT = 399 * k, boxB = 501 * k;
        double s = Math.Min((boxR - boxL) / b.Width, (boxB - boxT) / b.Height);
        double inkW = b.Width * s;
        double tx = CircleX * k - inkW / 2 - b.X * s;
        double ty = boxB - b.Height * s - b.Y * s;
        using (Matrix m = new Matrix())
        {
            m.Translate((float)tx, (float)ty);
            m.Scale((float)s, (float)s);
            path.Transform(m);
        }

        // Fill of the letters on its own layer, to apply the shadow to.
        Bitmap letters = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(letters))
        using (SolidBrush brush = new SolidBrush(fill))
        {
            g.Clear(Color.Transparent);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.FillPath(brush, path);
        }
        int[] lp = Pixels(letters), sp = Pixels(shadow);
        for (int i = 0; i < lp.Length; i++)
        {
            int c = lp[i];
            if (A(c) == 0) continue;
            double f = 1.0 - (A(sp[i]) / 255.0) * (1.0 - 0.49);
            lp[i] = Argb(A(c), (int)Math.Round(R(c) * f), (int)Math.Round(G(c) * f), (int)Math.Round(B(c) * f));
        }
        Bitmap shaded = ToBitmap(lp, size, size);

        using (Graphics g = Graphics.FromImage(canvas))
        using (Pen pen = new Pen(Color.Black, (float)(2 * outline)))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.CompositingQuality = CompositingQuality.HighQuality;
            pen.LineJoin = LineJoin.Round;
            pen.StartCap = LineCap.Round;
            pen.EndCap = LineCap.Round;
            g.DrawPath(pen, path);
            g.DrawImage(shaded, new Rectangle(0, 0, size, size));
            g.DrawImage(overlayS, new Rectangle(0, 0, size, size));
        }

        path.Dispose(); plate.Dispose(); overlay.Dispose(); shadowSrc.Dispose(); overlayS.Dispose();
        shadow.Dispose(); letters.Dispose(); shaded.Dispose();
        return canvas;
    }

    // ------------------------------------------------------------------
    // Output

    public static void SavePng(Bitmap bmp, string path)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        using (Bitmap copy = ToBitmap(Pixels(bmp), bmp.Width, bmp.Height))
        {
            copy.Save(path, ImageFormat.Png);
        }
    }

    static byte[] PngBytes(Bitmap bmp)
    {
        using (MemoryStream ms = new MemoryStream())
        using (Bitmap copy = ToBitmap(Pixels(bmp), bmp.Width, bmp.Height))
        {
            copy.Save(ms, ImageFormat.Png);
            return ms.ToArray();
        }
    }

    static byte[] Dib32(Bitmap bmp)
    {
        int w = bmp.Width, h = bmp.Height;
        int[] px = Pixels(bmp);
        int maskStride = ((w + 31) / 32) * 4;
        using (MemoryStream ms = new MemoryStream())
        using (BinaryWriter bw = new BinaryWriter(ms))
        {
            bw.Write(40); bw.Write(w); bw.Write(h * 2); bw.Write((short)1); bw.Write((short)32);
            bw.Write(0); bw.Write(w * h * 4 + maskStride * h); bw.Write(0); bw.Write(0); bw.Write(0); bw.Write(0);
            for (int y = h - 1; y >= 0; y--)
                for (int x = 0; x < w; x++)
                {
                    int c = px[y * w + x];
                    bw.Write((byte)B(c)); bw.Write((byte)G(c)); bw.Write((byte)R(c)); bw.Write((byte)A(c));
                }
            for (int y = h - 1; y >= 0; y--)
            {
                byte[] row = new byte[maskStride];
                for (int x = 0; x < w; x++)
                    if (A(px[y * w + x]) == 0) row[x / 8] |= (byte)(0x80 >> (x % 8));
                bw.Write(row);
            }
            bw.Flush();
            return ms.ToArray();
        }
    }

    public static void WriteIco(string path, Bitmap[] images)
    {
        List<byte[]> blobs = new List<byte[]>();
        foreach (Bitmap img in images) blobs.Add(img.Width >= 256 ? PngBytes(img) : Dib32(img));
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        using (FileStream fs = new FileStream(path, FileMode.Create, FileAccess.Write))
        using (BinaryWriter bw = new BinaryWriter(fs))
        {
            bw.Write((short)0); bw.Write((short)1); bw.Write((short)images.Length);
            int offset = 6 + 16 * images.Length;
            for (int i = 0; i < images.Length; i++)
            {
                bw.Write((byte)(images[i].Width >= 256 ? 0 : images[i].Width));
                bw.Write((byte)(images[i].Height >= 256 ? 0 : images[i].Height));
                bw.Write((byte)0); bw.Write((byte)0); bw.Write((short)1); bw.Write((short)32);
                bw.Write(blobs[i].Length); bw.Write(offset);
                offset += blobs[i].Length;
            }
            foreach (byte[] blob in blobs) bw.Write(blob);
        }
    }

    // ------------------------------------------------------------------
    // Splash screens: find the old icon, cover it with the new one

    public static string ReplaceSplashIcon(string inPath, string outPath, Bitmap oldIcon, Bitmap newIcon, int approxSize)
    {
        Bitmap splash;
        using (Bitmap tmp = new Bitmap(inPath)) { splash = ToBitmap(Pixels(tmp), tmp.Width, tmp.Height); }
        int W = splash.Width, H = splash.Height;
        int[] sp = Pixels(splash);

        // Find the size and position of the old icon by least squares over
        // its opaque pixels: a coarse search, then a fine one around the best.
        int bestS = 0, bestX = 0, bestY = 0; double bestE = double.MaxValue;
        for (int pass = 0; pass < 2; pass++)
        {
            int sLo, sHi, xLo, xHi, yLo, yHi, step, stride;
            if (pass == 0) { sLo = approxSize - 10; sHi = approxSize + 10; xLo = W / 2 - 60; xHi = W - approxSize + 20; yLo = -20; yHi = H - approxSize + 20; step = 2; stride = 6; }
            else { sLo = bestS - 2; sHi = bestS + 2; xLo = bestX - 4; xHi = bestX + 4; yLo = bestY - 4; yHi = bestY + 4; step = 1; stride = 2; }
            int cS = bestS, cX = bestX, cY = bestY; double cE = double.MaxValue;
            for (int s = sLo; s <= sHi; s++)
            {
                int[] ip;
                using (Bitmap scaled = Resize(oldIcon, s, s)) { ip = Pixels(scaled); }
                for (int y0 = yLo; y0 <= yHi; y0 += step)
                    for (int x0 = xLo; x0 <= xHi; x0 += step)
                    {
                        double e = 0; int n = 0;
                        for (int y = 0; y < s; y += stride)
                        {
                            int yy = y0 + y; if (yy < 0 || yy >= H) continue;
                            for (int x = 0; x < s; x += stride)
                            {
                                int xx = x0 + x; if (xx < 0 || xx >= W) continue;
                                int c = ip[y * s + x]; if (A(c) < 255) continue;
                                int t = sp[yy * W + xx];
                                int dr = R(c) - R(t), dg = G(c) - G(t), db = B(c) - B(t);
                                e += dr * dr + dg * dg + db * db; n++;
                            }
                        }
                        if (n == 0) continue;
                        e /= n;
                        if (e < cE) { cE = e; cS = s; cX = x0; cY = y0; }
                    }
            }
            bestS = cS; bestX = cX; bestY = cY; bestE = cE;
        }

        int S = bestS;
        int[] oldP, newP;
        using (Bitmap o = Resize(oldIcon, S, S)) { oldP = Pixels(o); }
        using (Bitmap n = Resize(newIcon, S, S)) { newP = Pixels(n); }

        // Alpha of both icons in splash coordinates, and where the old icon
        // was (grown by 2 px).
        float[] mOld = new float[W * H], mNew = new float[W * H];
        bool[] oldFoot = new bool[W * H];
        for (int y = 0; y < S; y++)
            for (int x = 0; x < S; x++)
            {
                int xx0 = bestX + x, yy0 = bestY + y;
                if (xx0 >= 0 && yy0 >= 0 && xx0 < W && yy0 < H)
                {
                    mOld[yy0 * W + xx0] = A(oldP[y * S + x]) / 255f;
                    mNew[yy0 * W + xx0] = A(newP[y * S + x]) / 255f;
                }
                if (A(oldP[y * S + x]) <= 8) continue;
                for (int dy = -2; dy <= 2; dy++)
                    for (int dx = -2; dx <= 2; dx++)
                    {
                        int xx = xx0 + dx, yy = yy0 + dy;
                        if (xx >= 0 && yy >= 0 && xx < W && yy < H) oldFoot[yy * W + xx] = true;
                    }
            }

        // The splash draws a drop shadow under the icon: the icon's shape,
        // moved down and to the right and softened a little, darkening the
        // background by a fixed fraction. Find the offset at which the
        // outline of the moved shape has the strongest dark-to-light step
        // (outside the icon), then the fraction from the two sides of it.
        double k = S / 256.0;
        int blurR = Math.Max(1, (int)Math.Round(k));
        float[] sOld = BoxBlur(BoxBlur(mOld, W, H, blurR), W, H, blurR);
        float[] sNew = BoxBlur(BoxBlur(mNew, W, H, blurR), W, H, blurR);
        int critR = Math.Max(1, (int)Math.Round(2 * k));
        float[] sCrit = BoxBlur(BoxBlur(mOld, W, H, critR), W, H, critR);
        bool[] ring = Dilate(oldFoot, W, H, (int)Math.Round(24 * k));
        for (int i = 0; i < ring.Length; i++) if (oldFoot[i]) ring[i] = false;
        double[] lum = new double[W * H];
        for (int i = 0; i < lum.Length; i++) lum[i] = 0.299 * R(sp[i]) + 0.587 * G(sp[i]) + 0.114 * B(sp[i]);
        int sdx = 0, sdy = 0; double bestC = double.MinValue;
        int maxOff = (int)Math.Round(16 * k);
        int rx0 = W, ry0 = H, rx1 = 0, ry1 = 0;
        for (int yy = 0; yy < H; yy++)
            for (int xx = 0; xx < W; xx++)
                if (ring[yy * W + xx]) { rx0 = Math.Min(rx0, xx); ry0 = Math.Min(ry0, yy); rx1 = Math.Max(rx1, xx); ry1 = Math.Max(ry1, yy); }
        for (int dy = 0; dy <= maxOff; dy++)
            for (int dx = 0; dx <= maxOff; dx++)
            {
                double sumIn = 0, sumOut = 0; int nIn = 0, nOut = 0;
                for (int yy = Math.Max(dy, ry0); yy <= ry1; yy++)
                    for (int xx = Math.Max(dx, rx0); xx <= rx1; xx++)
                    {
                        int i = yy * W + xx;
                        if (!ring[i]) continue;
                        float s = sCrit[(yy - dy) * W + (xx - dx)];
                        if (s > 0.65f && s < 0.95f) { sumIn += lum[i]; nIn++; }
                        else if (s > 0.05f && s < 0.35f) { sumOut += lum[i]; nOut++; }
                    }
                if (nIn < 30 * k || nOut < 30 * k) continue;
                double c = sumOut / nOut - sumIn / nIn;
                if (c > bestC) { bestC = c; sdx = dx; sdy = dy; }
            }
        // Refine: offset +-1 px and edge softness, keeping the model that
        // leaves the smoothest background once the shadow is taken out.
        int wideR = Math.Max(1, (int)Math.Round(5 * k));
        float[] sWide = BoxBlur(BoxBlur(mOld, W, H, wideR), W, H, wideR);
        bool[] zone = new bool[W * H];
        for (int yy = sdy; yy < H; yy++)
            for (int xx = sdx; xx < W; xx++)
            {
                int i = yy * W + xx;
                float s = sCrit[(yy - sdy) * W + (xx - sdx)];
                if (ring[i] && s > 0.01f && s < 0.99f) zone[i] = true;
            }
        double alpha = 0, bestRough = double.MaxValue;
        int fdx = sdx, fdy = sdy, softUsed = blurR;
        float[] sOldBest = sOld;
        int[] softness = k > 1.5 ? new int[] { 0, 1, 2 } : new int[] { 0, 1 };
        foreach (int soft in softness)
        {
            float[] sb = BoxBlur(BoxBlur(mOld, W, H, soft), W, H, soft);
            for (int ddy = -1; ddy <= 1; ddy++)
                for (int ddx = -1; ddx <= 1; ddx++)
                {
                    int dx = sdx + ddx, dy = sdy + ddy;
                    if (dx < 0 || dy < 0) continue;
                    double mSh = 0, mUn = 0; int cSh = 0, cUn = 0;
                    for (int yy = Math.Max(dy, ry0); yy <= ry1; yy++)
                        for (int xx = Math.Max(dx, rx0); xx <= rx1; xx++)
                        {
                            int i = yy * W + xx;
                            if (!ring[i]) continue;
                            int j = (yy - dy) * W + (xx - dx);
                            if (sb[j] > 0.9f) { mSh += lum[i]; cSh++; }
                            else if (sb[j] < 0.02f && sWide[j] > 0.01f && sWide[j] < 0.25f) { mUn += lum[i]; cUn++; }
                        }
                    if (cSh == 0 || cUn == 0 || mUn <= 0) continue;
                    double a = 1.0 - (mSh / cSh) / (mUn / cUn);
                    if (a < 0) a = 0;
                    if (a > 0.8) a = 0.8;
                    double rough = 0;
                    for (int yy = Math.Max(dy, ry0); yy < ry1; yy++)
                        for (int xx = Math.Max(dx, rx0); xx < rx1; xx++)
                        {
                            int i = yy * W + xx;
                            if (!zone[i]) continue;
                            double c0 = lum[i] / (1.0 - a * sb[(yy - dy) * W + (xx - dx)]);
                            int[] nb = new int[] { i + 1, i + W };
                            int[] nj = new int[] { (yy - dy) * W + (xx + 1 - dx), (yy + 1 - dy) * W + (xx - dx) };
                            for (int q = 0; q < 2; q++)
                            {
                                if (!ring[nb[q]]) continue;
                                double c1 = lum[nb[q]] / (1.0 - a * sb[nj[q]]);
                                rough += Math.Abs(c0 - c1);
                            }
                        }
                    if (rough < bestRough) { bestRough = rough; alpha = a; fdx = dx; fdy = dy; sOldBest = sb; softUsed = soft; }
                }
        }
        sdx = fdx; sdy = fdy; sOld = sOldBest;
        // The new icon's shadow gets the same softness.
        sNew = BoxBlur(BoxBlur(mNew, W, H, softUsed), W, H, softUsed);

        // Background without the old shadow.
        int[] bg = (int[])sp.Clone();
        for (int yy = 0; yy < H; yy++)
            for (int xx = 0; xx < W; xx++)
            {
                int i = yy * W + xx;
                if (oldFoot[i]) continue;
                int sx = xx - sdx, sy = yy - sdy;
                float s = (sx >= 0 && sy >= 0) ? sOld[sy * W + sx] : 0f;
                if (s <= 0f) continue;
                double f = 1.0 - alpha * s;
                int c = sp[i];
                bg[i] = Argb(A(c), (int)Math.Round(R(c) / f), (int)Math.Round(G(c) / f), (int)Math.Round(B(c) / f));
            }

        // Where the old icon was and the new one is not fully opaque, put
        // back background by mirroring the pixels next to the old outline.
        int filled = 0;
        int[] fill = (int[])bg.Clone();
        for (int yy = 0; yy < H; yy++)
            for (int xx = 0; xx < W; xx++)
            {
                int i = yy * W + xx;
                if (!oldFoot[i] || mNew[i] >= 250f / 255f) continue;
                int xl = xx; while (xl >= 0 && oldFoot[yy * W + xl]) xl--;
                int xr = xx; while (xr < W && oldFoot[yy * W + xr]) xr++;
                int src = -1;
                int[] candidates = (xx - xl <= xr - xx) ? new int[] { 2 * xl - xx, 2 * xr - xx } : new int[] { 2 * xr - xx, 2 * xl - xx };
                foreach (int sx in candidates)
                    if (sx >= 0 && sx < W && !oldFoot[yy * W + sx]) { src = yy * W + sx; break; }
                if (src < 0)
                {
                    int yb = yy; while (yb < H && oldFoot[yb * W + xx]) yb++;
                    int sy = 2 * yb - yy;
                    if (sy >= 0 && sy < H && !oldFoot[sy * W + xx]) src = sy * W + xx;
                }
                if (src >= 0) { fill[i] = bg[src]; filled++; }
            }

        // The new icon's shadow, then the icon.
        int[] outP = new int[W * H];
        for (int yy = 0; yy < H; yy++)
            for (int xx = 0; xx < W; xx++)
            {
                int i = yy * W + xx;
                int sx = xx - sdx, sy = yy - sdy;
                float s = (sx >= 0 && sy >= 0) ? sNew[sy * W + sx] : 0f;
                double f = 1.0 - alpha * s;
                int c = fill[i];
                outP[i] = s <= 0f ? c : Argb(A(c), (int)Math.Round(R(c) * f), (int)Math.Round(G(c) * f), (int)Math.Round(B(c) * f));
            }
        Bitmap result = ToBitmap(outP, W, H);
        using (Bitmap n = ToBitmap(newP, S, S))
        using (Graphics g = Graphics.FromImage(result))
        {
            g.CompositingQuality = CompositingQuality.HighQuality;
            g.DrawImage(n, new Rectangle(bestX, bestY, S, S));
        }
        SavePng(result, outPath);
        result.Dispose(); splash.Dispose();
        return string.Format("{0}: icon {1}px at {2},{3} (fit error {4:F1}); shadow offset {5},{6}, softness {7}, {8:P0} darker; {9} background pixels restored",
            Path.GetFileName(outPath), S, bestX, bestY, bestE, sdx, sdy, softUsed, alpha, filled);
    }

    static float[] BoxBlur(float[] m, int w, int h, int r)
    {
        float[] tmp = new float[w * h], outM = new float[w * h];
        float n = 2 * r + 1;
        for (int y = 0; y < h; y++)
        {
            float acc = 0;
            for (int x = -r; x <= r; x++) acc += (x >= 0 && x < w) ? m[y * w + x] : 0f;
            for (int x = 0; x < w; x++)
            {
                tmp[y * w + x] = acc / n;
                int xo = x - r, xi = x + r + 1;
                if (xo >= 0) acc -= m[y * w + xo];
                if (xi < w) acc += m[y * w + xi];
            }
        }
        for (int x = 0; x < w; x++)
        {
            float acc = 0;
            for (int y = -r; y <= r; y++) acc += (y >= 0 && y < h) ? tmp[y * w + x] : 0f;
            for (int y = 0; y < h; y++)
            {
                outM[y * w + x] = acc / n;
                int yo = y - r, yi = y + r + 1;
                if (yo >= 0) acc -= tmp[yo * w + x];
                if (yi < h) acc += tmp[yi * w + x];
            }
        }
        return outM;
    }

    static bool[] Dilate(bool[] m, int w, int h, int r)
    {
        // Square dilation, done as a row pass and a column pass.
        bool[] tmp = new bool[w * h], outM = new bool[w * h];
        for (int y = 0; y < h; y++)
        {
            int last = int.MinValue / 2;
            for (int x = 0; x < w; x++) { if (m[y * w + x]) last = x; if (x - last <= r) tmp[y * w + x] = true; }
            last = int.MaxValue / 2;
            for (int x = w - 1; x >= 0; x--) { if (m[y * w + x]) last = x; if (last - x <= r) tmp[y * w + x] = true; }
        }
        for (int x = 0; x < w; x++)
        {
            int last = int.MinValue / 2;
            for (int y = 0; y < h; y++) { if (tmp[y * w + x]) last = y; if (y - last <= r) outM[y * w + x] = true; }
            last = int.MaxValue / 2;
            for (int y = h - 1; y >= 0; y--) { if (tmp[y * w + x]) last = y; if (last - y <= r) outM[y * w + x] = true; }
        }
        return outM;
    }
}
'@

if (-not ('OxtBeyondBranding' -as [type])) {
    Add-Type -TypeDefinition $code -ReferencedAssemblies $refs
}
Add-Type -AssemblyName System.Drawing

if ($FillColor -notmatch '^#[0-9A-Fa-f]{6}$') { throw "FillColor must be #RRGGBB" }
$fill = [System.Drawing.ColorTranslator]::FromHtml($FillColor)

$brandDir = Join-Path $RepoRoot 'Installer\oxt-beyond\branding'
$pngDir = Join-Path $brandDir 'png'
$srcDir = Join-Path $brandDir 'source'
New-Item -ItemType Directory -Force -Path $pngDir, $srcDir | Out-Null

$pngBytes = $null
$source = [OxtBeyondBranding]::LargestIcoImage($sourceIco, [ref]$pngBytes)
Write-Host ("Source: {0}x{1} from {2}" -f $source.Width, $source.Height, $sourceIco)
$sourcePng = Join-Path $srcDir 'oxt-lite-icon-512.png'
if ($pngBytes) { [System.IO.File]::WriteAllBytes($sourcePng, $pngBytes) } else { [OxtBeyondBranding]::SavePng($source, $sourcePng) }

$parts = [OxtBeyondBranding]::Separate($source)
$master512 = [OxtBeyondBranding]::Compose($parts, 512, $fill)
$master1024 = [OxtBeyondBranding]::Compose($parts, 1024, $fill)

$images = @{}
foreach ($size in 16, 24, 32, 48, 64, 128, 256) { $images[$size] = [OxtBeyondBranding]::Resize($master512, $size, $size) }
$images[512] = $master512
$images[1024] = $master1024
foreach ($size in ($images.Keys | Sort-Object)) {
    $out = Join-Path $pngDir ("oxt-beyond-{0}.png" -f $size)
    [OxtBeyondBranding]::SavePng($images[$size], $out)
    Write-Host "Wrote $out"
}

$icoImages = [System.Drawing.Bitmap[]]@(16, 24, 32, 48, 64, 128, 256 | ForEach-Object { $images[$_] })
$ideIco = Join-Path $RepoRoot 'ide\OXT-Beyond.ico'
$rsrcIco = Join-Path $RepoRoot 'engine\rsrc\oxt-beyond.ico'
[OxtBeyondBranding]::WriteIco($ideIco, $icoImages)
Copy-Item -LiteralPath $ideIco -Destination $rsrcIco -Force
Write-Host "Wrote $ideIco"
Write-Host "Wrote $rsrcIco"

if ($Preview) { [OxtBeyondBranding]::SavePng($images[256], $Preview); Write-Host "Wrote $Preview" }

if ($Splash) {
    $skin = 'ide/Toolset/resources/community/ideSkin'
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('oxtb-splash-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        foreach ($name in 'splash.png', 'splash-light.png', 'splash@extra-high.png', 'splash-light@extra-high.png') {
            $orig = Join-Path $tmp $name
            # Read the original bytes from git; PowerShell pipes would alter binary data.
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = 'git'
            $psi.Arguments = ('-C "{0}" show "{1}:{2}/{3}"' -f $RepoRoot, $SplashSourceRev, $skin, $name)
            $psi.RedirectStandardOutput = $true
            $psi.UseShellExecute = $false
            $proc = [System.Diagnostics.Process]::Start($psi)
            $ms = New-Object System.IO.MemoryStream
            $proc.StandardOutput.BaseStream.CopyTo($ms)
            $proc.WaitForExit()
            if ($proc.ExitCode -ne 0) { throw "git show $SplashSourceRev`:$skin/$name failed" }
            [System.IO.File]::WriteAllBytes($orig, $ms.ToArray())
            $approx = if ($name -like '*extra-high*') { 512 } else { 256 }
            $target = Join-Path $RepoRoot (($skin -replace '/', '\') + '\' + $name)
            Write-Host ([OxtBeyondBranding]::ReplaceSplashIcon($orig, $target, $source, $master512, $approx))
        }
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

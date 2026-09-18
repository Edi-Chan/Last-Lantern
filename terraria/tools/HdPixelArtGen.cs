using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

/// <summary>
/// Last Lantern HD Pixel-Art generator.
/// Overwrites existing asset PNGs in-place. Same sizes, same paths.
/// True pixel art: no interpolation, no anti-alias, shared palette.
/// </summary>
internal static class Gen
{
    const string Root = @"c:\github\Last-Lantern\terraria\assets";

    static int C(int r, int g, int b, int a = 255)
    {
        return (a << 24) | (r << 16) | (g << 8) | b;
    }

    static int Alpha(int v)
    {
        return (v >> 24) & 255;
    }

    static readonly int Trans = 0;

    // Shared Last Lantern palette — warm earth, lantern gold, fog violet.
    static readonly int[] Stone = { C(28, 32, 40), C(44, 50, 60), C(62, 70, 82), C(84, 92, 104), C(110, 118, 130), C(140, 148, 158) };
    static readonly int[] Granite = { C(40, 32, 36), C(62, 48, 52), C(88, 68, 72), C(114, 92, 94), C(140, 118, 118), C(168, 148, 146) };
    static readonly int[] Slate = { C(30, 36, 42), C(46, 56, 64), C(62, 76, 86), C(78, 96, 108), C(102, 120, 130), C(128, 146, 154) };
    static readonly int[] Dirt = { C(48, 30, 18), C(72, 48, 28), C(96, 66, 38), C(120, 84, 50), C(146, 104, 62), C(168, 126, 78) };
    static readonly int[] Grass = { C(26, 44, 14), C(40, 66, 20), C(54, 90, 26), C(74, 118, 34), C(98, 148, 44), C(124, 176, 58) };
    static readonly int[] Sand = { C(120, 92, 48), C(148, 116, 62), C(176, 142, 78), C(198, 166, 96), C(218, 190, 118), C(232, 210, 142) };
    static readonly int[] Bedrock = { C(18, 16, 22), C(32, 30, 38), C(48, 46, 56), C(64, 62, 74), C(88, 86, 98) };
    static readonly int[] Oak = { C(52, 30, 16), C(78, 48, 24), C(104, 68, 34), C(132, 90, 46), C(158, 112, 60), C(184, 138, 78) };
    static readonly int[] BirchBark = { C(168, 156, 132), C(188, 178, 154), C(210, 202, 180), C(228, 222, 204), C(92, 70, 52), C(58, 42, 32) };
    static readonly int[] Pine = { C(46, 28, 16), C(64, 40, 22), C(82, 54, 28), C(102, 70, 36), C(58, 78, 32) };
    static readonly int[] OakLeaf = { C(28, 52, 16), C(44, 78, 22), C(62, 108, 30), C(86, 138, 40), C(48, 72, 20) };
    static readonly int[] BirchLeaf = { C(70, 108, 28), C(96, 140, 36), C(124, 168, 48), C(154, 196, 64), C(88, 120, 32) };
    static readonly int[] PineNeedle = { C(22, 48, 24), C(32, 68, 32), C(44, 90, 40), C(58, 112, 50), C(28, 56, 28) };
    static readonly int[] WoodPlank = { C(74, 46, 22), C(102, 66, 32), C(128, 86, 42), C(154, 108, 54), C(178, 130, 68), C(48, 30, 16) };
    static readonly int[] StoneBrick = { C(52, 56, 64), C(72, 78, 88), C(94, 100, 110), C(118, 124, 134), C(36, 40, 48), C(150, 156, 164) };
    static readonly int[] Straw = { C(120, 88, 32), C(148, 112, 40), C(176, 138, 50), C(204, 164, 64), C(92, 66, 24), C(220, 186, 88) };
    static readonly int[] Metal = { C(48, 50, 56), C(72, 76, 84), C(104, 110, 120), C(140, 148, 158), C(188, 196, 206), C(28, 30, 34) };
    static readonly int[] Steel = { C(36, 38, 44), C(58, 62, 70), C(86, 92, 102), C(124, 132, 142), C(176, 184, 194), C(220, 226, 232) };
    static readonly int[] Gold = { C(92, 62, 18), C(132, 92, 24), C(176, 128, 32), C(212, 168, 48), C(240, 208, 88), C(255, 236, 150) };
    static readonly int[] Skin = { C(120, 72, 48), C(168, 110, 74), C(204, 148, 104), C(224, 176, 128), C(92, 52, 36) };
    static readonly int[] Hair = { C(48, 28, 16), C(72, 42, 22), C(98, 58, 28), C(124, 76, 36), C(36, 20, 12) };
    static readonly int[] Shirt = { C(28, 52, 92), C(40, 74, 128), C(56, 98, 164), C(78, 124, 188), C(22, 38, 70) };
    static readonly int[] Pants = { C(52, 34, 22), C(74, 50, 30), C(96, 66, 40), C(40, 26, 16) };
    static readonly int[] ArmorM = { C(42, 46, 54), C(68, 74, 84), C(98, 106, 118), C(136, 146, 158), C(180, 190, 202), C(28, 30, 36) };
    static readonly int[] Outline = { C(16, 12, 10) };
    static readonly int Ink = C(18, 14, 12);
    static readonly int InkSoft = C(36, 28, 22);

    // Ore crystal ramps: dark, mid, bright, gleam
    static readonly int[][] Ores =
    {
        new[] { C(96, 48, 16), C(168, 84, 28), C(220, 128, 48), C(255, 188, 96) },       // copper
        new[] { C(88, 100, 104), C(148, 164, 168), C(196, 212, 214), C(236, 244, 246) }, // tin
        new[] { C(72, 40, 32), C(128, 72, 52), C(176, 108, 76), C(220, 150, 110) },      // ferrite
        new[] { C(140, 108, 20), C(196, 160, 32), C(236, 204, 52), C(255, 240, 120) },   // aurel
        new[] { C(20, 48, 120), C(36, 80, 188), C(72, 128, 236), C(140, 188, 255) },     // cobalt
        new[] { C(64, 24, 96), C(112, 48, 160), C(164, 84, 214), C(214, 150, 255) },     // veyrite
        new[] { C(20, 92, 112), C(40, 160, 188), C(96, 216, 236), C(180, 244, 255) },    // cryonite
        new[] { C(120, 24, 12), C(196, 52, 16), C(244, 96, 28), C(255, 168, 64) },       // ignitium
        new[] { C(28, 12, 40), C(64, 24, 88), C(112, 40, 140), C(180, 72, 200) },        // voidium
        new[] { C(80, 64, 140), C(140, 120, 220), C(196, 188, 255), C(240, 248, 255) },  // astralith
    };

    static int Hash(int x, int y, int s)
    {
        unchecked
        {
            uint n = (uint)(x * 374761393 + y * 668265263 + s * 1274126177);
            n = (n ^ (n >> 13)) * 1274126177u;
            return (int)(n & 0x7fffffff);
        }
    }

    static int Shade(int[] ramp, int i)
    {
        if (i < 0) i = 0;
        if (i >= ramp.Length) i = ramp.Length - 1;
        return ramp[i];
    }

    sealed class Pix
    {
        public readonly int W, H;
        public readonly int[] D;
        public Pix(int w, int h)
        {
            W = w; H = h; D = new int[w * h];
        }
        public void Clear()
        {
            Array.Clear(D, 0, D.Length);
        }
        public void Set(int x, int y, int argb)
        {
            if ((uint)x < (uint)W && (uint)y < (uint)H) D[y * W + x] = argb;
        }
        public int Get(int x, int y)
        {
            if ((uint)x < (uint)W && (uint)y < (uint)H) return D[y * W + x];
            return 0;
        }
        public bool Opaque(int x, int y)
        {
            return Alpha(Get(x, y)) > 16;
        }
        public void Rect(int x, int y, int w, int h, int c)
        {
            for (int j = 0; j < h; j++)
                for (int i = 0; i < w; i++)
                    Set(x + i, y + j, c);
        }
        public void HLine(int x, int y, int w, int c)
        {
            for (int i = 0; i < w; i++) Set(x + i, y, c);
        }
        public void VLine(int x, int y, int h, int c)
        {
            for (int j = 0; j < h; j++) Set(x, y + j, c);
        }
        public void Dot(int x, int y, int c)
        {
            Set(x, y, c);
        }
        public void Blit(Pix src, int dx, int dy)
        {
            for (int y = 0; y < src.H; y++)
                for (int x = 0; x < src.W; x++)
                {
                    int v = src.Get(x, y);
                    if (Alpha(v) > 16) Set(dx + x, dy + y, v);
                }
        }
        public Pix Crop(int x, int y, int w, int h)
        {
            var d = new Pix(w, h);
            for (int j = 0; j < h; j++)
                for (int i = 0; i < w; i++)
                    d.Set(i, j, Get(x + i, y + j));
            return d;
        }
        public void OutlineDark()
        {
            var copy = (int[])D.Clone();
            for (int y = 0; y < H; y++)
                for (int x = 0; x < W; x++)
                {
                    if (Alpha(copy[y * W + x]) <= 16) continue;
                    bool edge = false;
                    if (x == 0 || y == 0 || x == W - 1 || y == H - 1) edge = true;
                    else
                    {
                        if (Alpha(copy[y * W + x - 1]) <= 16) edge = true;
                        if (Alpha(copy[y * W + x + 1]) <= 16) edge = true;
                        if (Alpha(copy[(y - 1) * W + x]) <= 16) edge = true;
                        if (Alpha(copy[(y + 1) * W + x]) <= 16) edge = true;
                    }
                    if (edge) Set(x, y, Ink);
                }
        }
        public void Save(string rel)
        {
            string path = Path.Combine(Root, rel.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            using (var bmp = new Bitmap(W, H, PixelFormat.Format32bppArgb))
            {
                for (int y = 0; y < H; y++)
                    for (int x = 0; x < W; x++)
                    {
                        int v = D[y * W + x];
                        bmp.SetPixel(x, y, Color.FromArgb((v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255));
                    }
                bmp.Save(path, ImageFormat.Png);
            }
        }
        public static Pix Load(string rel)
        {
            return LoadAbs(Path.Combine(Root, rel.Replace('/', Path.DirectorySeparatorChar)));
        }
        public static Pix LoadOriginal(string rel)
        {
            string bak = Path.Combine(Path.GetDirectoryName(Root), "tools", "_backup_pre_hd_pixelart", rel.Replace('/', Path.DirectorySeparatorChar));
            if (File.Exists(bak)) return LoadAbs(bak);
            return Load(rel);
        }
        public static Pix LoadAbs(string path)
        {
            using (var bmp = new Bitmap(path))
            {
                var p = new Pix(bmp.Width, bmp.Height);
                for (int y = 0; y < p.H; y++)
                    for (int x = 0; x < p.W; x++)
                    {
                        var c = bmp.GetPixel(x, y);
                        p.Set(x, y, C(c.R, c.G, c.B, c.A));
                    }
                return p;
            }
        }
    }

    static Pix Tile16(Action<Pix, int> draw, int seed)
    {
        var p = new Pix(16, 16);
        draw(p, seed);
        return p;
    }

    static void FillNoise(Pix p, int[] ramp, int seed, int groutX, int groutY)
    {
        for (int y = 0; y < p.H; y++)
            for (int x = 0; x < p.W; x++)
            {
                int n = Hash(x, y, seed);
                int shade = 2 + ((n >> 8) & 1) + (((x + y + (n & 3)) & 7) == 0 ? 1 : 0);
                shade -= (x + y) > 22 ? 1 : 0;
                if (y == 0 || x == 0) shade++;
                if (y == p.H - 1 || x == p.W - 1) shade--;
                bool grout = groutX > 0 && ((x + (Hash(y, 0, seed) & 3)) % groutX == 0)
                          || groutY > 0 && ((y + (Hash(x, 1, seed) & 3)) % groutY == 0);
                if (grout) shade = 0;
                if ((n & 255) < 10) shade = Math.Max(0, shade - 2);
                if ((n & 255) > 245) shade++;
                p.Set(x, y, Shade(ramp, shade));
            }
    }

    static void DrawDirt(Pix p, int seed)
    {
        FillNoise(p, Dirt, seed, 0, 0);
        for (int i = 0; i < 6; i++)
        {
            int x = Hash(i, 3, seed) % 14 + 1;
            int y = Hash(i, 7, seed) % 14 + 1;
            int pebble = C(118, 104, 84);
            p.Set(x, y, pebble);
            if ((i & 1) == 0) p.Set(x + 1, y, C(96, 84, 68));
        }
        for (int i = 0; i < 8; i++)
        {
            int x = Hash(i, 11, seed) % 16;
            int y = Hash(i, 13, seed) % 16;
            p.Set(x, y, Shade(Dirt, (Hash(i, 17, seed) & 3)));
        }
    }

    static void DrawGrass(Pix p, int seed)
    {
        DrawDirt(p, seed + 91);
        int cap = 4 + (Hash(0, 0, seed) & 1);
        for (int x = 0; x < 16; x++)
        {
            int h = cap + (Hash(x, 2, seed) & 1) + ((x & 3) == 1 ? 1 : 0);
            for (int y = 0; y < h && y < 8; y++)
            {
                int s = 4 - y + ((Hash(x, y, seed) >> 5) & 1);
                if (y == 0) s = 5;
                p.Set(x, y, Shade(Grass, s));
            }
            // blades
            if ((Hash(x, 9, seed) & 3) == 0 && x > 0 && x < 15)
            {
                p.Set(x, 0, Shade(Grass, 5));
                p.Set(x, -0, Shade(Grass, 5));
            }
        }
        // tiny flowers / seeds
        if ((seed & 3) == 0) p.Set(3 + (seed & 7), 1, C(220, 210, 170));
        if ((seed & 3) == 1) p.Set(9, 2, C(196, 72, 48));
        // dirt specks showing through
        p.Set(5, 6, Shade(Dirt, 3));
        p.Set(12, 7, Shade(Dirt, 2));
    }

    static void DrawStone(Pix p, int seed)
    {
        FillNoise(p, Stone, seed, 5 + (seed & 1), 4 + ((seed >> 1) & 1));
        // cracks
        int cx = 3 + (Hash(1, 1, seed) % 8);
        int cy = 4 + (Hash(2, 2, seed) % 7);
        for (int i = 0; i < 5; i++)
            p.Set(cx + i / 2, cy + (i & 1), Shade(Stone, 0));
        p.Set(2, 2, Shade(Stone, 5));
        p.Set(11, 3, Shade(Stone, 4));
    }

    static void DrawSand(Pix p, int seed)
    {
        FillNoise(p, Sand, seed, 0, 0);
        for (int i = 0; i < 10; i++)
        {
            int x = Hash(i, 4, seed) % 16;
            int y = Hash(i, 8, seed) % 16;
            p.Set(x, y, Shade(Sand, (i & 1) == 0 ? 1 : 4));
        }
        // ripples
        for (int x = 0; x < 16; x++)
            if ((x + seed) % 5 == 0)
                p.Set(x, 6 + (x & 1), Shade(Sand, 2));
    }

    static void DrawGranite(Pix p, int seed)
    {
        FillNoise(p, Granite, seed, 6, 5);
        for (int i = 0; i < 7; i++)
        {
            int x = Hash(i, 2, seed) % 15;
            int y = Hash(i, 5, seed) % 15;
            p.Set(x, y, C(210, 200, 196));
            p.Set(x + 1, y, Shade(Granite, 1));
        }
    }

    static void DrawSlate(Pix p, int seed)
    {
        for (int y = 0; y < 16; y++)
            for (int x = 0; x < 16; x++)
            {
                int band = (y + Hash(y, 0, seed) % 2) / 3;
                int s = 2 + (band & 1) + ((Hash(x, y, seed) >> 6) & 1);
                if (x == 0 || y % 3 == 0) s = 0;
                if (y == 0) s++;
                p.Set(x, y, Shade(Slate, s));
            }
    }

    static void DrawWoodLog(Pix p, int[] ramp, int seed, bool rings)
    {
        for (int y = 0; y < 16; y++)
            for (int x = 0; x < 16; x++)
            {
                int s = 2;
                if (rings)
                {
                    int dx = x - 8, dy = y - 8;
                    int r = dx * dx + dy * dy;
                    s = 1 + (r / 12) % 3;
                    if (r < 6) s = 4;
                }
                else
                {
                    s = 2 + ((x / 3 + Hash(x / 3, 0, seed)) & 1);
                    if (x % 4 == 0) s = 0;
                    if ((Hash(x, y, seed) & 31) == 0) s = 5 % ramp.Length;
                    if (y == 0) s++;
                }
                p.Set(x, y, Shade(ramp, s));
            }
        // knot
        int kx = 4 + (seed & 7), ky = 6 + ((seed >> 2) & 5);
        p.Set(kx, ky, Shade(ramp, 0));
        p.Set(kx + 1, ky, Shade(ramp, 1));
        p.Set(kx, ky + 1, Shade(ramp, 1));
    }

    static void DrawLeaves(Pix p, int[] ramp, int seed)
    {
        p.Clear();
        for (int y = 0; y < 16; y++)
            for (int x = 0; x < 16; x++)
            {
                int n = Hash(x, y, seed);
                if ((n & 7) == 0 && (x + y) % 2 == 0) continue;
                int s = 2 + ((n >> 4) & 1) - (y > 11 ? 1 : 0) + (y < 3 ? 1 : 0);
                p.Set(x, y, Shade(ramp, s));
            }
        // holes for leaf clusters
        p.Set(1, 1, Trans);
        p.Set(14, 2, Trans);
        p.Set(2, 14, Trans);
        p.Set(13, 13, Trans);
    }

    static void DrawSapling(Pix p, int[] wood, int[] leaf, int seed)
    {
        p.Clear();
        p.VLine(7, 8, 8, Shade(wood, 2));
        p.VLine(8, 9, 7, Shade(wood, 1));
        p.Set(7, 8, Shade(wood, 3));
        // crown
        for (int y = 1; y < 10; y++)
            for (int x = 3; x < 13; x++)
            {
                int dx = x - 7, dy = y - 5;
                if (dx * dx + dy * dy * 2 < 18 + (Hash(x, y, seed) & 3))
                    p.Set(x, y, Shade(leaf, 2 + ((Hash(x, y, seed) >> 3) & 1) + (y < 4 ? 1 : 0)));
            }
        p.Set(7, 1, Shade(leaf, 4 % leaf.Length));
        p.OutlineDark();
    }

    static void DrawOre(Pix p, int ore, int seed)
    {
        DrawStone(p, seed + 17);
        int[] cr = Ores[ore];
        int[] spots = { 3, 4, 8, 3, 11, 6, 5, 9, 9, 11, 6, 7, 12, 10, 4, 12 };
        for (int i = 0; i < 8; i++)
        {
            int x = (spots[i * 2] + (Hash(i, 1, seed) & 1)) % 15;
            int y = (spots[i * 2 + 1] + (Hash(i, 2, seed) & 1)) % 15;
            p.Set(x, y, cr[1]);
            p.Set(x + 1, y, cr[2]);
            p.Set(x, y + 1, cr[0]);
            if ((i & 1) == 0) p.Set(x + 1, y + 1, cr[3]);
        }
        // one bigger crystal
        int cx = 6 + (seed & 3), cy = 5 + ((seed >> 2) & 3);
        p.Set(cx, cy - 1, cr[2]);
        p.Set(cx, cy, cr[3]);
        p.Set(cx + 1, cy, cr[2]);
        p.Set(cx, cy + 1, cr[1]);
        p.Set(cx - 1, cy, cr[0]);
    }

    static void DrawBedrock(Pix p, int seed)
    {
        FillNoise(p, Bedrock, seed, 4, 4);
        for (int i = 0; i < 5; i++)
            p.Set(Hash(i, 1, seed) % 16, Hash(i, 2, seed) % 16, C(8, 8, 12));
    }

    static void DrawSupport(Pix p, int seed)
    {
        p.Clear();
        for (int y = 0; y < 16; y++)
        {
            p.Set(6, y, Shade(Oak, y == 0 ? 4 : 1));
            p.Set(7, y, Shade(Oak, 3));
            p.Set(8, y, Shade(Oak, 2));
            p.Set(9, y, Shade(Oak, 0));
            if (y % 4 == 0)
            {
                p.HLine(5, y, 6, Shade(Oak, 1));
                p.Set(5, y, Ink);
                p.Set(10, y, Ink);
            }
        }
        p.VLine(5, 0, 16, InkSoft);
        p.VLine(10, 0, 16, Ink);
    }

    static void DrawForgeCore(Pix p, int seed)
    {
        FillNoise(p, StoneBrick, seed, 5, 5);
        p.Rect(4, 4, 8, 8, C(48, 24, 16));
        p.Rect(5, 5, 6, 6, C(180, 64, 20));
        p.Rect(6, 6, 4, 4, C(240, 140, 32));
        p.Set(7, 7, C(255, 230, 140));
        p.Set(8, 8, C(255, 200, 80));
        p.HLine(4, 4, 8, Ink);
        p.HLine(4, 11, 8, Ink);
        p.VLine(4, 4, 8, Ink);
        p.VLine(11, 4, 8, Ink);
    }

    static Pix IconFromTile(Pix tile)
    {
        return tile; // 16x16 already
    }

    static Pix ItemOre(int ore, int seed)
    {
        var p = new Pix(16, 16);
        p.Clear();
        // chunk silhouette
        int[] shape =
        {
            0,0,0,1,1,1,1,1,1,1,1,0,0,0,0,0,
            0,0,1,1,1,1,1,1,1,1,1,1,1,0,0,0,
            0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,
            0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
            1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
            1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
            1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
            1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
            0,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,
            0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,
            0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,0,
            0,0,0,1,1,1,1,1,1,1,0,0,0,0,0,0,
        };
        for (int y = 2; y < 14; y++)
            for (int x = 0; x < 16; x++)
            {
                if (shape[(y - 2) * 16 + x] == 0) continue;
                int s = 2 + ((Hash(x, y, seed) >> 5) & 1) - (y > 10 ? 1 : 0) + (y < 5 ? 1 : 0);
                p.Set(x, y, Shade(Stone, s));
            }
        int[] cr = Ores[ore];
        for (int i = 0; i < 9; i++)
        {
            int x = 3 + (i * 3 + Hash(i, 0, seed)) % 10;
            int y = 4 + (i * 2 + Hash(i, 1, seed)) % 7;
            if (!p.Opaque(x, y)) continue;
            p.Set(x, y, cr[2]);
            p.Set(x + 1, y, cr[3]);
            p.Set(x, y + 1, cr[1]);
        }
        p.OutlineDark();
        return p;
    }

    static void DrawHandle(Pix p, int x0, int y0, int x1, int y1, int[] wood)
    {
        int steps = 12;
        for (int i = 0; i <= steps; i++)
        {
            int x = x0 + (x1 - x0) * i / steps;
            int y = y0 + (y1 - y0) * i / steps;
            p.Set(x, y, Shade(wood, 2));
            p.Set(x + 1, y, Shade(wood, 3));
            p.Set(x, y + 1, Shade(wood, 1));
        }
    }

    static Pix ToolPickaxe(int[] metal, int seed)
    {
        var p = new Pix(16, 16);
        DrawHandle(p, 3, 14, 8, 7, Oak);
        // wrapping
        p.Set(7, 8, Shade(Oak, 0));
        p.Set(8, 7, Shade(Oak, 0));
        // head
        p.HLine(6, 4, 8, Shade(metal, 3));
        p.HLine(5, 5, 10, Shade(metal, 2));
        p.HLine(6, 6, 8, Shade(metal, 1));
        p.Set(5, 5, Shade(metal, 4));
        p.Set(14, 5, Shade(metal, 0));
        p.Set(9, 3, Shade(metal, 4));
        p.Set(10, 3, Shade(metal, 3));
        p.Set(8, 7, Shade(metal, 1));
        p.OutlineDark();
        return p;
    }

    static Pix ToolAxe(int[] metal)
    {
        var p = new Pix(16, 16);
        DrawHandle(p, 3, 14, 8, 6, Oak);
        p.Rect(8, 3, 6, 6, Shade(metal, 2));
        p.HLine(8, 3, 6, Shade(metal, 4));
        p.VLine(13, 3, 6, Shade(metal, 3));
        p.Set(14, 5, Shade(metal, 4));
        p.Set(14, 6, Shade(metal, 2));
        p.Set(8, 8, Shade(metal, 1));
        p.Set(9, 4, Shade(metal, 3));
        p.OutlineDark();
        return p;
    }

    static Pix ToolHammer()
    {
        var p = new Pix(16, 16);
        DrawHandle(p, 7, 14, 7, 7, Oak);
        p.VLine(8, 7, 8, Shade(Oak, 3));
        p.Rect(4, 3, 9, 5, Shade(Steel, 2));
        p.HLine(4, 3, 9, Shade(Steel, 4));
        p.HLine(4, 7, 9, Shade(Steel, 0));
        p.Set(5, 4, Shade(Steel, 4));
        p.Set(11, 5, Shade(Steel, 1));
        p.OutlineDark();
        return p;
    }

    static Pix ToolWrench()
    {
        var p = new Pix(16, 16);
        p.VLine(7, 4, 10, Shade(Steel, 2));
        p.VLine(8, 4, 10, Shade(Steel, 3));
        p.Rect(5, 2, 6, 3, Shade(Steel, 2));
        p.Set(5, 2, Trans); p.Set(10, 2, Trans);
        p.Set(6, 3, Shade(Steel, 4));
        p.Rect(5, 12, 6, 3, Shade(Steel, 2));
        p.Set(5, 14, Trans); p.Set(10, 14, Trans);
        p.OutlineDark();
        return p;
    }

    static Pix ToolHoe()
    {
        var p = new Pix(16, 16);
        DrawHandle(p, 4, 14, 9, 6, Oak);
        p.HLine(8, 4, 6, Shade(Steel, 3));
        p.HLine(9, 5, 5, Shade(Steel, 2));
        p.Set(13, 4, Shade(Steel, 4));
        p.Set(13, 6, Shade(Steel, 1));
        p.OutlineDark();
        return p;
    }

    static Pix ToolSickle()
    {
        var p = new Pix(16, 16);
        DrawHandle(p, 4, 14, 7, 8, Oak);
        p.Set(8, 7, Shade(Steel, 2));
        p.Set(9, 6, Shade(Steel, 3));
        p.Set(10, 5, Shade(Steel, 3));
        p.Set(11, 4, Shade(Steel, 4));
        p.Set(12, 4, Shade(Steel, 3));
        p.Set(13, 5, Shade(Steel, 2));
        p.Set(13, 6, Shade(Steel, 2));
        p.Set(12, 7, Shade(Steel, 1));
        p.Set(11, 8, Shade(Steel, 1));
        p.Set(10, 4, Shade(Steel, 4));
        p.OutlineDark();
        return p;
    }

    static Pix ToolRod()
    {
        var p = new Pix(16, 16);
        DrawHandle(p, 3, 14, 12, 2, Oak);
        p.Set(12, 2, Shade(Steel, 4));
        p.Set(13, 3, Shade(Steel, 2));
        p.Set(13, 8, C(180, 60, 40));
        p.Set(13, 9, C(180, 60, 40));
        p.OutlineDark();
        return p;
    }

    static Pix ToolNet()
    {
        var p = new Pix(16, 16);
        DrawHandle(p, 3, 14, 7, 8, Oak);
        p.Rect(7, 2, 8, 7, C(40, 70, 90, 180));
        for (int y = 2; y < 9; y++)
            for (int x = 7; x < 15; x++)
                if (((x + y) & 1) == 0) p.Set(x, y, C(160, 190, 200));
        p.HLine(7, 2, 8, Shade(Oak, 2));
        p.HLine(7, 8, 8, Shade(Oak, 1));
        p.VLine(7, 2, 7, Shade(Oak, 2));
        p.VLine(14, 2, 7, Shade(Oak, 1));
        p.OutlineDark();
        return p;
    }

    static Pix ToolTorch()
    {
        var p = new Pix(16, 16);
        p.VLine(7, 7, 8, Shade(Oak, 2));
        p.VLine(8, 7, 8, Shade(Oak, 3));
        p.Set(7, 6, C(180, 60, 20));
        p.Set(8, 6, C(220, 90, 24));
        p.Set(7, 5, C(240, 140, 32));
        p.Set(8, 5, C(255, 190, 60));
        p.Set(8, 4, C(255, 230, 120));
        p.Set(7, 4, C(255, 160, 40));
        p.Set(8, 3, C(255, 240, 180));
        p.OutlineDark();
        return p;
    }

    static Pix ToolLantern()
    {
        var p = new Pix(16, 16);
        p.HLine(6, 2, 4, Shade(Gold, 2));
        p.Set(7, 1, Shade(Gold, 3));
        p.Set(8, 1, Shade(Gold, 4));
        p.Rect(5, 3, 6, 8, Shade(Gold, 1));
        p.Rect(6, 4, 4, 6, C(255, 170, 40));
        p.Set(7, 5, C(255, 230, 120));
        p.Set(8, 6, C(255, 200, 70));
        p.HLine(5, 3, 6, Shade(Gold, 4));
        p.HLine(5, 10, 6, Shade(Gold, 0));
        p.Set(6, 11, Shade(Gold, 2));
        p.Set(9, 11, Shade(Gold, 2));
        p.HLine(6, 12, 4, Shade(Gold, 1));
        p.OutlineDark();
        return p;
    }

    static Pix ToolScanner()
    {
        var p = new Pix(16, 16);
        p.Rect(4, 5, 8, 8, Shade(Steel, 2));
        p.Rect(5, 6, 6, 4, C(40, 120, 80));
        p.Set(7, 7, C(80, 255, 140));
        p.Set(8, 8, C(40, 200, 100));
        p.HLine(4, 5, 8, Shade(Steel, 4));
        p.VLine(11, 2, 4, Shade(Steel, 3));
        p.Set(11, 1, C(220, 40, 40));
        p.OutlineDark();
        return p;
    }

    static Pix ArmorIcon(string slot)
    {
        var p = new Pix(16, 16);
        p.Clear();
        if (slot == "helm")
        {
            p.Rect(4, 3, 8, 8, Shade(ArmorM, 2));
            p.HLine(4, 3, 8, Shade(ArmorM, 4));
            p.HLine(5, 7, 6, Ink);
            p.Set(6, 7, C(40, 80, 100));
            p.Set(9, 7, C(40, 80, 100));
            p.HLine(5, 2, 6, Shade(ArmorM, 3));
        }
        else if (slot == "chest")
        {
            p.Rect(3, 3, 10, 11, Shade(ArmorM, 2));
            p.HLine(3, 3, 10, Shade(ArmorM, 4));
            p.VLine(7, 4, 8, Shade(ArmorM, 3));
            p.VLine(8, 4, 8, Shade(ArmorM, 1));
            p.Set(5, 5, Shade(ArmorM, 4));
            p.Set(10, 5, Shade(ArmorM, 4));
        }
        else
        {
            p.Rect(4, 2, 3, 12, Shade(ArmorM, 2));
            p.Rect(9, 2, 3, 12, Shade(ArmorM, 2));
            p.HLine(4, 2, 8, Shade(ArmorM, 3));
            p.Set(5, 4, Shade(ArmorM, 4));
            p.Set(10, 4, Shade(ArmorM, 4));
        }
        p.OutlineDark();
        return p;
    }

    static Pix SeedIcon(int[] leaf)
    {
        var p = new Pix(16, 16);
        p.Clear();
        p.Rect(6, 8, 4, 5, Shade(Oak, 2));
        p.Set(7, 9, Shade(Oak, 3));
        p.Set(8, 10, Shade(Oak, 1));
        p.Set(7, 6, Shade(leaf, 3));
        p.Set(8, 5, Shade(leaf, 4 % leaf.Length));
        p.Set(6, 7, Shade(leaf, 2));
        p.Set(9, 7, Shade(leaf, 2));
        p.Set(8, 4, Shade(leaf, 3));
        p.OutlineDark();
        return p;
    }

    static Pix FlowerIcon(int petal, bool tall)
    {
        var p = new Pix(16, 16);
        p.Clear();
        p.VLine(7, tall ? 6 : 8, tall ? 9 : 7, Shade(Grass, 2));
        p.Set(8, tall ? 8 : 10, Shade(Grass, 3));
        p.Set(6, tall ? 9 : 11, Shade(Grass, 3));
        int cy = tall ? 5 : 6;
        p.Set(7, cy, C(220, 180, 40));
        p.Set(6, cy, petal);
        p.Set(8, cy, petal);
        p.Set(7, cy - 1, petal);
        p.Set(7, cy + 1, petal);
        p.Set(6, cy - 1, petal);
        p.Set(8, cy + 1, petal);
        p.OutlineDark();
        return p;
    }

    static Pix GrassTuft(bool tall, bool dry, int h)
    {
        var p = new Pix(16, h);
        p.Clear();
        int[] ramp = dry ? new[] { C(92, 78, 32), C(124, 108, 44), C(156, 136, 58), C(188, 164, 72) } : Grass;
        int[] xs = { 3, 5, 7, 8, 10, 12 };
        foreach (int x in xs)
        {
            int top = tall ? 2 + (x & 3) : (h - 8) + (x & 2);
            for (int y = top; y < h; y++)
                p.Set(x, y, Shade(ramp, 2 + ((h - y) / 4) + (y == top ? 1 : 0)));
            p.Set(x + ((x & 1) == 0 ? 1 : -1), top + 1, Shade(ramp, 3));
        }
        return p;
    }

    static Pix Fern(int h)
    {
        var p = new Pix(16, h);
        p.Clear();
        p.VLine(8, 4, h - 4, Shade(Grass, 1));
        for (int i = 0; i < 6; i++)
        {
            int y = 4 + i * (h - 8) / 6;
            int w = 5 - i / 2;
            for (int k = 1; k <= w; k++)
            {
                p.Set(8 - k, y + k / 2, Shade(Grass, 3));
                p.Set(8 + k, y + k / 2, Shade(Grass, 4));
            }
        }
        return p;
    }

    static Pix Bush(int w, int h)
    {
        var p = new Pix(w, h);
        p.Clear();
        p.VLine(w / 2 - 1, h - 6, 6, Shade(Oak, 2));
        p.VLine(w / 2, h - 5, 5, Shade(Oak, 1));
        for (int y = 1; y < h - 4; y++)
            for (int x = 1; x < w - 1; x++)
            {
                int dx = x - w / 2, dy = y - (h / 3);
                if (dx * dx + dy * dy * 2 < 28 + (Hash(x, y, 3) & 7))
                    p.Set(x, y, Shade(OakLeaf, 2 + ((Hash(x, y, 9) >> 4) & 1) + (y < 4 ? 1 : 0)));
            }
        return p;
    }

    static void EnhanceByRamp(Pix p, int[] ramp, int seed)
    {
        var copy = (int[])p.D.Clone();
        for (int y = 0; y < p.H; y++)
            for (int x = 0; x < p.W; x++)
            {
                int v = copy[y * p.W + x];
                int a = Alpha(v);
                if (a < 16) { p.Set(x, y, 0); continue; }
                int r = (v >> 16) & 255, g = (v >> 8) & 255, b = v & 255;
                int lum = (r * 3 + g * 6 + b) / 10;
                int idx = lum * (ramp.Length - 1) / 255;
                bool edge = x == 0 || y == 0 || x == p.W - 1 || y == p.H - 1
                    || Alpha(copy[y * p.W + Math.Max(0, x - 1)]) < 16
                    || Alpha(copy[y * p.W + Math.Min(p.W - 1, x + 1)]) < 16
                    || Alpha(copy[Math.Max(0, y - 1) * p.W + x]) < 16
                    || Alpha(copy[Math.Min(p.H - 1, y + 1) * p.W + x]) < 16;
                if (edge) idx = Math.Min(idx, 1);
                else
                {
                    idx += (y < p.H / 3 ? 1 : 0) - (y > p.H * 2 / 3 ? 1 : 0);
                    idx += (Hash(x, y, seed) & 1) - ((x + y) % 9 == 0 ? 1 : 0);
                }
                int c = Shade(ramp, idx);
                if (a < 255) c = (a << 24) | (c & 0x00ffffff);
                p.Set(x, y, c);
            }
    }

    static int Dist2(int r, int g, int b, int r2, int g2, int b2)
    {
        int dr = r - r2, dg = g - g2, db = b - b2;
        return dr * dr + dg * dg + db * db;
    }

    static int ClassifyPlayer(int v, int y, int h)
    {
        int r = (v >> 16) & 255, g = (v >> 8) & 255, b = v & 255;
        if (r + g + b < 90) return 0;
        int dOutline = Dist2(r, g, b, 36, 24, 18);
        int dSkin = Math.Min(Dist2(r, g, b, 224, 176, 138), Dist2(r, g, b, 196, 140, 108));
        int dHair = Math.Min(Dist2(r, g, b, 122, 72, 38), Dist2(r, g, b, 90, 50, 26));
        int dShirt = Math.Min(Dist2(r, g, b, 52, 108, 176), Dist2(r, g, b, 36, 78, 138));
        int dPants = Math.Min(Dist2(r, g, b, 118, 74, 44), Dist2(r, g, b, 86, 52, 32));
        int dShoe = Dist2(r, g, b, 62, 42, 32);
        int dEye = Dist2(r, g, b, 245, 242, 235);
        int best = dOutline; int kind = 0;
        if (dSkin < best) { best = dSkin; kind = 1; }
        if (dHair < best) { best = dHair; kind = 3; }
        if (dShirt < best) { best = dShirt; kind = 2; }
        if (dPants < best) { best = dPants; kind = 5; }
        if (dShoe < best) { best = dShoe; kind = 4; }
        if (dEye < best) { kind = 6; }
        if (kind == 3 && y > h / 2) kind = 5;
        if (kind == 5 && y < h / 3) kind = 3;
        if (kind == 5 && y > h * 3 / 4) kind = 4;
        return kind;
    }

    static void EnhancePlayer(Pix p, int seed)
    {
        var copy = (int[])p.D.Clone();
        for (int y = 0; y < p.H; y++)
            for (int x = 0; x < p.W; x++)
            {
                int v = copy[y * p.W + x];
                if (Alpha(v) < 16) { p.Set(x, y, 0); continue; }
                int kind = ClassifyPlayer(v, y, p.H);
                if (kind == 6) { p.Set(x, y, C(245, 242, 235)); continue; }
                int[] ramp = Outline;
                switch (kind)
                {
                    case 0: ramp = Outline; break;
                    case 1: ramp = Skin; break;
                    case 2: ramp = Shirt; break;
                    case 3: ramp = Hair; break;
                    case 4: ramp = Pants; break;
                    default: ramp = Pants; break;
                }
                int r = (v >> 16) & 255, g = (v >> 8) & 255, b = v & 255;
                int lum = (r + g + b) / 3;
                int idx = lum * (ramp.Length - 1) / 220;
                bool edge = x == 0 || y == 0 || x == p.W - 1 || y == p.H - 1
                    || Alpha(copy[y * p.W + Math.Max(0, x - 1)]) < 16
                    || Alpha(copy[y * p.W + Math.Min(p.W - 1, x + 1)]) < 16
                    || Alpha(copy[Math.Max(0, y - 1) * p.W + x]) < 16
                    || Alpha(copy[Math.Min(p.H - 1, y + 1) * p.W + x]) < 16;
                if (kind == 0 || edge) idx = 0;
                else
                {
                    idx += (x + y < 40 ? 1 : 0);
                    idx -= y > p.H - 8 ? 1 : 0;
                    if ((Hash(x, y, seed) & 15) == 0) idx++;
                }
                p.Set(x, y, Shade(ramp, idx));
            }
        for (int y = 0; y < p.H; y++)
            for (int x = 0; x < p.W; x++)
            {
                if (Alpha(copy[y * p.W + x]) < 16) continue;
                int r = (copy[y * p.W + x] >> 16) & 255, g = (copy[y * p.W + x] >> 8) & 255, b = copy[y * p.W + x] & 255;
                if (Dist2(r, g, b, 245, 242, 235) < 400)
                {
                    p.Set(x, y, C(245, 242, 235));
                    p.Set(x, y + 1, C(24, 28, 40));
                }
            }
    }

    static void EnhanceArmor(Pix p, int seed)
    {
        var copy = (int[])p.D.Clone();
        for (int y = 0; y < p.H; y++)
            for (int x = 0; x < p.W; x++)
            {
                int v = copy[y * p.W + x];
                int a = Alpha(v);
                if (a < 16) { p.Set(x, y, 0); continue; }
                int r = (v >> 16) & 255, g = (v >> 8) & 255, b = v & 255;
                int lum = (r + g + b) / 3;
                int idx = lum * (ArmorM.Length - 1) / 220;
                bool edge = Alpha(copy[y * p.W + Math.Max(0, x - 1)]) < 16
                    || Alpha(copy[y * p.W + Math.Min(p.W - 1, x + 1)]) < 16
                    || Alpha(copy[Math.Max(0, y - 1) * p.W + x]) < 16
                    || Alpha(copy[Math.Min(p.H - 1, y + 1) * p.W + x]) < 16;
                if (edge || lum < 50) idx = 0;
                else
                {
                    idx += y < 16 ? 1 : 0;
                    if (((x + y) & 7) == 0) idx++;
                    if ((Hash(x, y, seed) & 20) == 0) idx = Math.Max(0, idx - 1); // scratches
                }
                int c = Shade(ArmorM, idx);
                p.Set(x, y, (a << 24) | (c & 0x00ffffff));
            }
    }

    static int PickRampForBuildingPixel(int v)
    {
        int r = (v >> 16) & 255, g = (v >> 8) & 255, b = v & 255;
        if (r + g + b < 70) return -1;
        int grey = Math.Abs(r - g) + Math.Abs(g - b);
        if (r > 150 && g > 110 && b < 90) return 2;
        if (r > g + 8 && r > b + 16 && grey > 18) return 0;
        return 1;
    }

    static void EnhanceBuildingAtlas(Pix p)
    {
        var copy = (int[])p.D.Clone();
        for (int y = 0; y < p.H; y++)
            for (int x = 0; x < p.W; x++)
            {
                int v = copy[y * p.W + x];
                int a = Alpha(v);
                if (a < 16) { p.Set(x, y, 0); continue; }
                int kind = PickRampForBuildingPixel(v);
                int r = (v >> 16) & 255, g = (v >> 8) & 255, b = v & 255;
                int lum = (r + g + b) / 3;
                if (kind < 0)
                {
                    p.Set(x, y, Ink);
                    continue;
                }
                int[] ramp = kind == 0 ? WoodPlank : kind == 2 ? Straw : StoneBrick;
                int idx = lum * (ramp.Length - 1) / 220;
                int lx = x % 16, ly = y % 16;
                if (kind == 0 && lx % 4 == 0) idx = 0;
                if (kind == 1 && (lx % 5 == 0 || ly % 4 == 0)) idx = Math.Min(idx, 1);
                if (ly == 0) idx++;
                if (ly == 15) idx--;
                if ((Hash(x, y, 4) & 31) == 0) idx--;
                if ((Hash(x, y, 7) & 31) == 1) idx++;
                p.Set(x, y, Shade(ramp, idx));
            }
    }

    static Pix Anvil()
    {
        var p = new Pix(32, 16);
        p.Clear();
        p.Rect(4, 2, 24, 5, Shade(Steel, 2));
        p.HLine(4, 2, 24, Shade(Steel, 4));
        p.HLine(4, 6, 24, Shade(Steel, 0));
        p.Set(3, 3, Shade(Steel, 3)); // horn
        p.Set(2, 4, Shade(Steel, 2));
        p.Set(28, 3, Shade(Steel, 1));
        p.Rect(12, 7, 8, 3, Shade(Steel, 1));
        p.Rect(8, 10, 16, 5, Shade(Steel, 2));
        p.HLine(8, 10, 16, Shade(Steel, 3));
        p.HLine(8, 14, 16, Shade(Steel, 0));
        p.Set(10, 4, Shade(Steel, 4));
        p.Set(20, 3, C(80, 80, 90)); // scratch
        p.OutlineDark();
        return p;
    }

    static Pix Workbench()
    {
        var p = new Pix(32, 16);
        p.Clear();
        p.Rect(1, 5, 30, 4, Shade(Oak, 3));
        p.HLine(1, 5, 30, Shade(Oak, 4));
        p.HLine(1, 8, 30, Shade(Oak, 1));
        for (int x = 2; x < 30; x += 4) p.VLine(x, 6, 2, Shade(Oak, 0));
        p.Rect(3, 9, 4, 7, Shade(Oak, 2));
        p.Rect(25, 9, 4, 7, Shade(Oak, 2));
        p.VLine(4, 9, 7, Shade(Oak, 3));
        p.VLine(26, 9, 7, Shade(Oak, 3));
        p.Set(10, 6, Shade(Steel, 3));
        p.Set(18, 7, Shade(Oak, 0));
        p.OutlineDark();
        return p;
    }

    static Pix Furnace()
    {
        var p = new Pix(32, 32);
        p.Clear();
        p.Rect(4, 4, 24, 26, Shade(StoneBrick, 2));
        for (int y = 4; y < 30; y++)
            for (int x = 4; x < 28; x++)
                if (x % 5 == 4 || y % 4 == 0) p.Set(x, y, Shade(StoneBrick, 0));
        p.Rect(10, 12, 12, 10, C(40, 20, 16));
        p.Rect(11, 13, 10, 8, C(180, 60, 18));
        p.Rect(13, 15, 6, 5, C(255, 150, 32));
        p.Set(16, 16, C(255, 230, 140));
        p.HLine(4, 4, 24, Shade(StoneBrick, 4));
        p.Rect(8, 6, 4, 3, Shade(StoneBrick, 1));
        p.Rect(20, 6, 4, 3, Shade(StoneBrick, 1));
        p.OutlineDark();
        return p;
    }

    static Pix Door(bool reinforced)
    {
        var p = new Pix(16, 48);
        p.Clear();
        p.Rect(1, 1, 14, 46, Shade(Oak, 2));
        for (int y = 1; y < 47; y++)
            for (int x = 1; x < 15; x++)
                if (x == 5 || x == 10) p.Set(x, y, Shade(Oak, 0));
        for (int y = 8; y < 47; y += 10) p.HLine(1, y, 14, Shade(Oak, 1));
        p.Set(12, 24, Shade(Gold, 3));
        p.Set(11, 24, Shade(Gold, 2));
        p.Set(12, 25, Shade(Gold, 1));
        if (reinforced)
        {
            p.HLine(2, 6, 12, Shade(Steel, 2));
            p.HLine(2, 40, 12, Shade(Steel, 2));
            p.VLine(2, 6, 35, Shade(Steel, 1));
            p.VLine(13, 6, 35, Shade(Steel, 1));
        }
        p.OutlineDark();
        return p;
    }

    static Pix Gate()
    {
        var p = new Pix(32, 48);
        p.Clear();
        p.Rect(2, 2, 28, 44, Shade(Oak, 2));
        for (int x = 4; x < 30; x += 5) p.VLine(x, 2, 44, Shade(Oak, 0));
        for (int y = 8; y < 46; y += 8) p.HLine(2, y, 28, Shade(Oak, 1));
        p.Rect(14, 20, 4, 8, Shade(Steel, 2));
        p.Set(16, 24, Shade(Steel, 4));
        p.OutlineDark();
        return p;
    }

    static Pix WallTorch()
    {
        var p = new Pix(16, 16);
        p.Clear();
        p.Rect(6, 8, 4, 6, Shade(Oak, 2));
        p.Set(5, 9, Shade(Oak, 1));
        p.Set(10, 9, Shade(Oak, 1));
        p.Set(7, 6, C(220, 80, 20));
        p.Set(8, 5, C(255, 160, 40));
        p.Set(8, 4, C(255, 220, 100));
        p.Set(7, 5, C(255, 120, 30));
        p.OutlineDark();
        return p;
    }

    static Pix Chest()
    {
        var p = new Pix(16, 16);
        p.Clear();
        p.Rect(2, 5, 12, 9, Shade(Oak, 2));
        p.Rect(2, 5, 12, 4, Shade(Oak, 3));
        p.HLine(2, 8, 12, Shade(Gold, 2));
        p.Set(7, 8, Shade(Gold, 4));
        p.Set(8, 8, Shade(Gold, 3));
        p.HLine(2, 5, 12, Shade(Oak, 4));
        p.OutlineDark();
        return p;
    }

    static Pix Furniture(string kind)
    {
        var p = new Pix(16, 16);
        p.Clear();
        if (kind == "table")
        {
            p.Rect(1, 6, 14, 3, Shade(Oak, 3));
            p.Rect(2, 9, 3, 6, Shade(Oak, 2));
            p.Rect(11, 9, 3, 6, Shade(Oak, 2));
        }
        else if (kind == "chair")
        {
            p.Rect(4, 2, 8, 6, Shade(Oak, 2));
            p.Rect(4, 8, 8, 3, Shade(Oak, 3));
            p.Rect(4, 11, 3, 4, Shade(Oak, 1));
            p.Rect(9, 11, 3, 4, Shade(Oak, 1));
        }
        else if (kind == "shelf")
        {
            p.Rect(1, 3, 14, 2, Shade(Oak, 3));
            p.Rect(1, 8, 14, 2, Shade(Oak, 3));
            p.Rect(1, 13, 14, 2, Shade(Oak, 3));
            p.VLine(1, 3, 12, Shade(Oak, 1));
            p.VLine(14, 3, 12, Shade(Oak, 1));
        }
        else if (kind == "barrel")
        {
            p.Rect(4, 2, 8, 13, Shade(Oak, 2));
            p.HLine(4, 2, 8, Shade(Oak, 3));
            p.HLine(4, 6, 8, Shade(Steel, 2));
            p.HLine(4, 11, 8, Shade(Steel, 2));
            p.VLine(4, 2, 13, Shade(Oak, 0));
            p.VLine(11, 2, 13, Shade(Oak, 3));
        }
        else if (kind == "sign")
        {
            p.VLine(7, 8, 8, Shade(Oak, 2));
            p.Rect(2, 2, 12, 8, Shade(Oak, 3));
            p.HLine(4, 5, 8, Shade(Oak, 0));
            p.HLine(5, 7, 6, Shade(Oak, 0));
        }
        else if (kind == "rack")
        {
            p.Rect(2, 2, 12, 3, Shade(Oak, 2));
            p.VLine(3, 2, 13, Shade(Oak, 1));
            p.VLine(12, 2, 13, Shade(Oak, 1));
            DrawHandle(p, 5, 12, 8, 4, Steel);
            p.Set(9, 4, Shade(Steel, 3));
        }
        p.OutlineDark();
        return p;
    }

    static Pix BuildingIcon(string kind)
    {
        var p = new Pix(16, 16);
        p.Clear();
        int[] ramp = (kind.Contains("stone") || kind.Contains("glass") || kind.Contains("anvil") || kind.Contains("furnace"))
            ? StoneBrick : WoodPlank;
        if (kind.Contains("straw")) ramp = Straw;
        FillNoise(p, ramp, kind.GetHashCode(), kind.Contains("stone") ? 5 : 4, 4);
        if (kind.Contains("window"))
        {
            p.Rect(3, 3, 10, 10, C(40, 80, 120, 180));
            p.HLine(3, 7, 10, Shade(ramp, 1));
            p.VLine(7, 3, 10, Shade(ramp, 1));
        }
        if (kind.Contains("platform"))
        {
            p.Clear();
            p.Rect(0, 4, 16, 5, Shade(ramp, 2));
            p.HLine(0, 4, 16, Shade(ramp, 4));
            p.Set(2, 9, Shade(ramp, 1));
            p.Set(13, 9, Shade(ramp, 1));
        }
        if (kind.Contains("stairs"))
        {
            p.Clear();
            for (int i = 0; i < 4; i++)
                p.Rect(i * 4, 12 - i * 3, 12 - i * 2, 3, Shade(ramp, 2 + (i & 1)));
        }
        if (kind.Contains("ladder"))
        {
            p.Clear();
            p.VLine(4, 1, 14, Shade(Oak, 2));
            p.VLine(11, 1, 14, Shade(Oak, 2));
            for (int y = 3; y < 15; y += 3) p.HLine(4, y, 8, Shade(Oak, 3));
        }
        if (kind.Contains("roof") && !kind.Contains("straw"))
        {
            p.Clear();
            for (int y = 2; y < 12; y++)
                p.HLine(8 - y / 2, y, y, Shade(Oak, 2));
        }
        if (kind.Contains("beam"))
        {
            p.Clear();
            p.Rect(6, 0, 4, 16, Shade(Oak, 2));
            p.VLine(6, 0, 16, Shade(Oak, 0));
            p.VLine(9, 0, 16, Shade(Oak, 3));
        }
        if (kind.Contains("barricade"))
        {
            p.Clear();
            for (int i = 0; i < 5; i++)
                p.Rect(1 + i, 2 + i, 3, 12 - i, Shade(Oak, 2));
        }
        p.OutlineDark();
        return p;
    }

    static Pix Dummy()
    {
        var p = new Pix(16, 24);
        p.Clear();
        p.Rect(3, 2, 10, 16, C(164, 72, 56));
        for (int y = 2; y < 18; y++)
            for (int x = 3; x < 13; x++)
                if ((x + y) % 5 == 0) p.Set(x, y, C(140, 56, 44));
        p.Set(6, 6, C(240, 240, 230));
        p.Set(9, 6, C(240, 240, 230));
        p.Set(6, 7, C(24, 24, 28));
        p.Set(9, 7, C(24, 24, 28));
        p.Rect(6, 18, 4, 5, Shade(Oak, 2));
        p.OutlineDark();
        return p;
    }

    static void EnhanceBackground(string rel, int[] ramp, int seed)
    {
        var p = Pix.LoadOriginal(rel);
        EnhanceByRamp(p, ramp, seed);
        p.Save(rel);
    }

    static Pix UiIcon(string kind)
    {
        var p = kind.StartsWith("slot") || kind == "search" || kind == "trash" ? new Pix(8, 8) : new Pix(16, 16);
        p.Clear();
        if (kind == "bag")
        {
            p.Rect(3, 5, 10, 9, Shade(Oak, 2));
            p.HLine(5, 4, 6, Shade(Oak, 3));
            p.HLine(6, 3, 4, Shade(Oak, 1));
            p.HLine(4, 8, 8, Shade(Oak, 0));
            p.OutlineDark();
        }
        else if (kind == "trash")
        {
            p.HLine(1, 2, 6, Shade(Steel, 3));
            p.Rect(2, 3, 4, 4, Shade(Steel, 2));
            p.VLine(3, 3, 4, Ink);
            p.VLine(4, 3, 4, Ink);
        }
        else if (kind == "search")
        {
            p.Rect(1, 1, 4, 4, Shade(Steel, 3));
            p.Set(5, 5, Shade(Steel, 2));
            p.Set(6, 6, Shade(Steel, 1));
        }
        else if (kind == "marker")
        {
            p.Set(8, 4, C(220, 40, 40));
            p.Set(7, 5, C(220, 40, 40));
            p.Set(8, 5, C(255, 80, 60));
            p.Set(9, 5, C(220, 40, 40));
            p.Set(8, 6, C(180, 20, 20));
            p.OutlineDark();
        }
        else if (kind.StartsWith("slot"))
        {
            int c = kind.Contains("helm") ? Shade(ArmorM, 3)
                : kind.Contains("chest") ? Shade(ArmorM, 2)
                : kind.Contains("legs") ? Shade(ArmorM, 1)
                : kind.Contains("boots") ? Shade(Oak, 2)
                : Shade(Gold, 2);
            p.Rect(1, 1, 6, 6, c);
            p.OutlineDark();
        }
        return p;
    }

    static Pix Sun()
    {
        var p = new Pix(32, 32);
        p.Clear();
        for (int y = 0; y < 32; y++)
            for (int x = 0; x < 32; x++)
            {
                int dx = x - 16, dy = y - 16;
                int r2 = dx * dx + dy * dy;
                if (r2 < 64) p.Set(x, y, C(255, 220, 90));
                else if (r2 < 90) p.Set(x, y, C(255, 170, 40));
                else if (r2 < 110) p.Set(x, y, C(220, 110, 24));
            }
        p.Set(14, 12, C(255, 240, 180));
        return p;
    }

    static Pix Moon()
    {
        var p = new Pix(28, 28);
        p.Clear();
        for (int y = 0; y < 28; y++)
            for (int x = 0; x < 28; x++)
            {
                int dx = x - 14, dy = y - 14;
                int r2 = dx * dx + dy * dy;
                int hx = x - 18, hy = y - 12;
                if (r2 < 80 && hx * hx + hy * hy > 36)
                {
                    int s = r2 < 40 ? 3 : 2;
                    p.Set(x, y, Shade(new[] { C(60, 64, 88), C(140, 148, 176), C(188, 196, 220), C(228, 232, 244) }, s));
                }
            }
        p.Set(10, 10, C(120, 124, 150));
        p.Set(12, 16, C(100, 108, 140));
        return p;
    }

    static Pix Cloud(int w, int h, int seed)
    {
        var p = new Pix(w, h);
        p.Clear();
        int[] ramp = { C(160, 168, 184, 180), C(200, 208, 220, 210), C(232, 236, 244, 230) };
        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
            {
                int n = Hash(x / 3, y / 2, seed);
                int cy = h / 2;
                int wave = cy + (int)(Math.Sin(x * 0.2 + seed) * (h / 4.0));
                if (Math.Abs(y - wave) < 3 + (n & 3) && x > 1 && x < w - 2)
                    p.Set(x, y, Shade(ramp, 1 + (y < wave ? 1 : 0)));
            }
        return p;
    }

    static void StampAtlas(Pix atlas, int tx, int ty, Pix tile)
    {
        atlas.Blit(tile, tx * 16, ty * 16);
    }

    static void Main()
    {
        Console.WriteLine("Last Lantern HD Pixel-Art generation...");

        var grass0 = Tile16(DrawGrass, 11);
        var grass1 = Tile16(DrawGrass, 73);
        var dirt0 = Tile16(DrawDirt, 5);
        var dirt1 = Tile16(DrawDirt, 41);
        var stone0 = Tile16(DrawStone, 19);
        var stone1 = Tile16(DrawStone, 67);
        var sand0 = Tile16(DrawSand, 23);
        var sand1 = Tile16(DrawSand, 89);
        var gran0 = Tile16(DrawGranite, 13);
        var gran1 = Tile16(DrawGranite, 59);
        var slate0 = Tile16(DrawSlate, 17);
        var slate1 = Tile16(DrawSlate, 61);
        var wood0 = Tile16((p, s) => DrawWoodLog(p, Oak, s, false), 3);
        var wood1 = Tile16((p, s) => DrawWoodLog(p, Oak, s, false), 47);
        var leaf0 = Tile16((p, s) => DrawLeaves(p, OakLeaf, s), 8);
        var leaf1 = Tile16((p, s) => DrawLeaves(p, OakLeaf, s), 52);
        var oakW0 = Tile16((p, s) => DrawWoodLog(p, Oak, s, true), 4);
        var oakW1 = Tile16((p, s) => DrawWoodLog(p, Oak, s, true), 44);
        var birchW0 = Tile16((p, s) => DrawWoodLog(p, BirchBark, s, false), 6);
        var birchW1 = Tile16((p, s) => DrawWoodLog(p, BirchBark, s, false), 46);
        var pineW0 = Tile16((p, s) => DrawWoodLog(p, Pine, s, false), 9);
        var pineW1 = Tile16((p, s) => DrawWoodLog(p, Pine, s, false), 49);
        var oakL0 = Tile16((p, s) => DrawLeaves(p, OakLeaf, s), 12);
        var oakL1 = Tile16((p, s) => DrawLeaves(p, OakLeaf, s), 55);
        var birchL0 = Tile16((p, s) => DrawLeaves(p, BirchLeaf, s), 14);
        var birchL1 = Tile16((p, s) => DrawLeaves(p, BirchLeaf, s), 57);
        var pineL0 = Tile16((p, s) => DrawLeaves(p, PineNeedle, s), 16);
        var pineL1 = Tile16((p, s) => DrawLeaves(p, PineNeedle, s), 58);
        var oakS = Tile16((p, s) => DrawSapling(p, Oak, OakLeaf, s), 21);
        var birchS = Tile16((p, s) => DrawSapling(p, BirchBark, BirchLeaf, s), 22);
        var pineS = Tile16((p, s) => DrawSapling(p, Pine, PineNeedle, s), 24);
        var ores0 = new Pix[10];
        var ores1 = new Pix[10];
        for (int i = 0; i < 10; i++)
        {
            ores0[i] = Tile16((p, s) => DrawOre(p, i, s), 30 + i);
            ores1[i] = Tile16((p, s) => DrawOre(p, i, s), 130 + i);
        }
        var bed0 = Tile16(DrawBedrock, 2);
        var bed1 = Tile16(DrawBedrock, 33);
        var support = Tile16(DrawSupport, 1);
        var forge = Tile16(DrawForgeCore, 7);

        var atlas = new Pix(128, 128);
        // row 0
        StampAtlas(atlas, 0, 0, grass0);
        StampAtlas(atlas, 1, 0, dirt0);
        StampAtlas(atlas, 2, 0, stone0);
        StampAtlas(atlas, 3, 0, sand0);
        StampAtlas(atlas, 4, 0, gran0);
        StampAtlas(atlas, 5, 0, slate0);
        StampAtlas(atlas, 6, 0, wood0);
        StampAtlas(atlas, 7, 0, leaf0);
        // row 1 ores + bedrock
        StampAtlas(atlas, 0, 1, ores0[0]);
        StampAtlas(atlas, 1, 1, ores0[1]);
        StampAtlas(atlas, 2, 1, ores0[2]);
        StampAtlas(atlas, 3, 1, ores0[3]);
        StampAtlas(atlas, 4, 1, bed0);
        StampAtlas(atlas, 5, 1, ores0[4]);
        StampAtlas(atlas, 6, 1, ores0[5]);
        StampAtlas(atlas, 7, 1, ores0[6]);
        // row 2 woods/leaves/saplings
        StampAtlas(atlas, 0, 2, oakW0);
        StampAtlas(atlas, 1, 2, birchW0);
        StampAtlas(atlas, 2, 2, pineW0);
        StampAtlas(atlas, 3, 2, oakL0);
        StampAtlas(atlas, 4, 2, birchL0);
        StampAtlas(atlas, 5, 2, pineL0);
        StampAtlas(atlas, 6, 2, oakS);
        StampAtlas(atlas, 7, 2, birchS);
        // row 3
        StampAtlas(atlas, 0, 3, pineS);
        StampAtlas(atlas, 1, 3, ores0[7]);
        StampAtlas(atlas, 2, 3, ores0[8]);
        StampAtlas(atlas, 3, 3, ores0[9]);
        StampAtlas(atlas, 4, 3, support);
        StampAtlas(atlas, 5, 3, forge);
        StampAtlas(atlas, 6, 3, stone0);
        StampAtlas(atlas, 7, 3, dirt0);
        // variant row 4-7
        StampAtlas(atlas, 0, 4, grass1);
        StampAtlas(atlas, 1, 4, dirt1);
        StampAtlas(atlas, 2, 4, stone1);
        StampAtlas(atlas, 3, 4, sand1);
        StampAtlas(atlas, 4, 4, gran1);
        StampAtlas(atlas, 5, 4, slate1);
        StampAtlas(atlas, 6, 4, wood1);
        StampAtlas(atlas, 7, 4, leaf1);
        StampAtlas(atlas, 0, 5, ores1[0]);
        StampAtlas(atlas, 1, 5, ores1[1]);
        StampAtlas(atlas, 2, 5, ores1[2]);
        StampAtlas(atlas, 3, 5, ores1[3]);
        StampAtlas(atlas, 4, 5, bed1);
        StampAtlas(atlas, 5, 5, ores1[4]);
        StampAtlas(atlas, 6, 5, ores1[5]);
        StampAtlas(atlas, 7, 5, ores1[6]);
        StampAtlas(atlas, 0, 6, oakW1);
        StampAtlas(atlas, 1, 6, birchW1);
        StampAtlas(atlas, 2, 6, pineW1);
        StampAtlas(atlas, 3, 6, oakL1);
        StampAtlas(atlas, 4, 6, birchL1);
        StampAtlas(atlas, 5, 6, pineL1);
        StampAtlas(atlas, 6, 6, oakS);
        StampAtlas(atlas, 7, 6, birchS);
        StampAtlas(atlas, 0, 7, pineS);
        StampAtlas(atlas, 1, 7, ores1[7]);
        StampAtlas(atlas, 2, 7, ores1[8]);
        StampAtlas(atlas, 3, 7, ores1[9]);
        StampAtlas(atlas, 4, 7, support);
        StampAtlas(atlas, 5, 7, forge);
        StampAtlas(atlas, 6, 7, stone1);
        StampAtlas(atlas, 7, 7, dirt1);
        atlas.Save("world/tiles/terrain_atlas.png");

        grass0.Save("world/tiles/grass_placeholder.png");
        dirt0.Save("world/tiles/dirt_placeholder.png");
        stone0.Save("world/tiles/stone_placeholder.png");
        sand0.Save("world/tiles/sand_placeholder.png");
        gran0.Save("world/tiles/granite_placeholder.png");
        slate0.Save("world/tiles/slate_placeholder.png");
        wood0.Save("world/tiles/wood_placeholder.png");
        leaf0.Save("world/tiles/leaves_placeholder.png");
        oakW0.Save("world/tiles/oak_wood.png");
        birchW0.Save("world/tiles/birch_wood.png");
        pineW0.Save("world/tiles/pine_wood.png");
        oakL0.Save("world/tiles/oak_leaves.png");
        birchL0.Save("world/tiles/birch_leaves.png");
        pineL0.Save("world/tiles/pine_leaves.png");
        oakS.Save("world/tiles/oak_sapling.png");
        birchS.Save("world/tiles/birch_sapling.png");
        pineS.Save("world/tiles/pine_sapling.png");
        bed0.Save("world/tiles/bedrock_placeholder.png");
        support.Save("world/tiles/wood_support_beam.png");
        forge.Save("world/tiles/forge_core.png");
        ores0[0].Save("world/tiles/copper_ore_placeholder.png");
        ores0[2].Save("world/tiles/iron_ore_placeholder.png");
        ores0[3].Save("world/tiles/gold_ore_placeholder.png");
        ores0[1].Save("world/tiles/silver_ore_placeholder.png");

        string[] oreNames = { "copper", "tin", "ferrite", "aurel", "cobalt", "veyrite", "cryonite", "ignitium", "voidium", "astralith" };
        for (int i = 0; i < 10; i++)
        {
            ores0[i].Save("world/ores/" + oreNames[i] + "_ore.png");
            ItemOre(i, 90 + i).Save("items/ores/" + oreNames[i] + "_ore.png");
        }

        int[][] metalTiers =
        {
            Stone, // stone pick
            Ores[0], Ores[1], Ores[2], Ores[3], Ores[4], Ores[5], Ores[6], Ores[7], Ores[8], Ores[9]
        };
        string[] pickFiles =
        {
            "items/tools/mining/pickaxes/stone_pickaxe.png",
            "items/tools/mining/pickaxes/copper_pickaxe.png",
            "items/tools/mining/pickaxes/tin_pickaxe.png",
            "items/tools/mining/pickaxes/ferrite_pickaxe.png",
            "items/tools/mining/pickaxes/aurel_pickaxe.png",
            "items/tools/mining/pickaxes/cobalt_pickaxe.png",
            "items/tools/mining/pickaxes/veyrite_pickaxe.png",
            "items/tools/mining/pickaxes/cryonite_pickaxe.png",
            "items/tools/mining/pickaxes/ignitium_pickaxe.png",
            "items/tools/mining/pickaxes/voidium_pickaxe.png",
            "items/tools/mining/pickaxes/astralith_pickaxe.png",
        };
        for (int i = 0; i < pickFiles.Length; i++)
            ToolPickaxe(metalTiers[i], i).Save(pickFiles[i]);
        ToolPickaxe(Stone, 0).Save("items/tools/mining/stone_pickaxe.png");
        ToolPickaxe(Stone, 0).Save("items/tools/pickaxe_placeholder.png");
        ToolAxe(Stone).Save("items/tools/woodcutting/stone_axe.png");
        ToolHammer().Save("items/tools/building_repair/wood_hammer.png");
        ToolWrench().Save("items/tools/dismantling/simple_wrench.png");
        ToolHoe().Save("items/tools/farming/wood_hoe.png");
        ToolSickle().Save("items/tools/farming/sickle.png");
        ToolRod().Save("items/tools/gathering/wood_fishing_rod.png");
        ToolNet().Save("items/tools/gathering/net.png");
        ToolTorch().Save("items/tools/exploration/torch.png");
        ToolLantern().Save("items/tools/exploration/lantern.png");
        ToolScanner().Save("items/tools/exploration/scanner.png");

        ArmorIcon("helm").Save("items/equipment/test_helmet.png");
        ArmorIcon("helm").Save("items/equipment/helmet_placeholder.png");
        ArmorIcon("chest").Save("items/equipment/test_chestplate.png");
        ArmorIcon("chest").Save("items/equipment/chestplate_placeholder.png");
        ArmorIcon("legs").Save("items/equipment/test_leggings.png");

        SeedIcon(OakLeaf).Save("items/seeds/oak_seed.png");
        SeedIcon(BirchLeaf).Save("items/seeds/birch_seed.png");
        SeedIcon(PineNeedle).Save("items/seeds/pine_seed.png");

        FlowerIcon(C(240, 240, 230), false).Save("items/plants/white_wildflower.png");
        FlowerIcon(C(236, 196, 48), false).Save("items/plants/yellow_wildflower.png");
        FlowerIcon(C(196, 48, 40), false).Save("items/plants/red_wildflower.png");
        FlowerIcon(C(56, 96, 196), false).Save("items/plants/blue_wildflower.png");
        FlowerIcon(C(140, 64, 188), false).Save("items/plants/purple_wildflower.png");
        GrassTuft(false, false, 16).Save("items/plants/wild_grass.png");
        GrassTuft(true, false, 16).Save("items/plants/tall_grass.png");
        GrassTuft(false, true, 16).Save("items/plants/dry_grass.png");
        Fern(16).Save("items/plants/fern.png");
        Bush(16, 16).Save("items/plants/bush.png");

        FlowerIcon(C(240, 240, 230), false).Save("world/vegetation/white_wildflower.png");
        FlowerIcon(C(236, 196, 48), false).Save("world/vegetation/yellow_wildflower.png");
        FlowerIcon(C(196, 48, 40), false).Save("world/vegetation/red_wildflower.png");
        FlowerIcon(C(56, 96, 196), false).Save("world/vegetation/blue_wildflower.png");
        FlowerIcon(C(140, 64, 188), false).Save("world/vegetation/purple_wildflower.png");
        GrassTuft(false, false, 16).Save("world/vegetation/wild_grass.png");
        GrassTuft(true, false, 24).Save("world/vegetation/tall_grass.png");
        GrassTuft(false, true, 16).Save("world/vegetation/dry_grass.png");
        Fern(24).Save("world/vegetation/fern.png");
        Bush(16, 20).Save("world/vegetation/bush.png");

        var bAtlas = Pix.LoadOriginal("building/building_atlas.png");
        EnhanceBuildingAtlas(bAtlas);
        bAtlas.Save("building/building_atlas.png");

        Anvil().Save("building/stations/anvil.png");
        Workbench().Save("building/stations/workbench.png");
        Furnace().Save("building/stations/furnace.png");
        ArmorIcon("helm"); // noop keep
        Anvil().Crop(8, 0, 16, 16).Save("building/stations/anvil_icon.png");
        Workbench().Crop(8, 0, 16, 16).Save("building/stations/workbench_icon.png");
        Furnace().Crop(8, 8, 16, 16).Save("building/stations/furnace_icon.png");
        Door(false).Save("building/doors/wood_door.png");
        Door(true).Save("building/doors/reinforced_wood_door.png");
        Door(false).Crop(0, 16, 16, 16).Save("building/doors/wood_door_icon.png");
        Door(true).Crop(0, 16, 16, 16).Save("building/doors/reinforced_wood_door_icon.png");
        Gate().Save("building/defense/wood_gate.png");
        Gate().Crop(8, 16, 16, 16).Save("building/defense/wood_gate_icon.png");
        WallTorch().Save("building/lights/wall_torch.png");
        WallTorch().Save("building/lights/wall_torch_icon.png");
        Chest().Save("building/furniture/wood_chest.png");
        Chest().Save("building/furniture/wood_chest_icon.png");
        Furniture("table").Save("building/furniture/wood_table_icon.png");
        Furniture("chair").Save("building/furniture/wood_chair_icon.png");
        Furniture("shelf").Save("building/furniture/wood_shelf_icon.png");
        Furniture("barrel").Save("building/furniture/wood_barrel_icon.png");
        Furniture("sign").Save("building/furniture/wood_sign_icon.png");
        Furniture("rack").Save("building/furniture/weapon_rack_icon.png");

        string[] bIcons =
        {
            "building/backgrounds/stone_background_icon.png",
            "building/backgrounds/wood_background_icon.png",
            "building/defense/wood_barricade_icon.png",
            "building/floors/stone_floor_icon.png",
            "building/floors/wood_floor_icon.png",
            "building/foundations/stone_foundation_icon.png",
            "building/foundations/wood_foundation_icon.png",
            "building/platforms/stone_platform_icon.png",
            "building/platforms/wood_platform_icon.png",
            "building/roofs/straw_roof_icon.png",
            "building/roofs/wood_roof_icon.png",
            "building/stairs/stone_stairs_icon.png",
            "building/stairs/wood_ladder_icon.png",
            "building/stairs/wood_stairs_icon.png",
            "building/supports/wood_beam_icon.png",
            "building/walls/stone_wall_icon.png",
            "building/walls/wood_wall_icon.png",
            "building/windows/glass_window_icon.png",
            "building/windows/wood_window_icon.png",
        };
        foreach (string f in bIcons)
        {
            string n = Path.GetFileNameWithoutExtension(f);
            BuildingIcon(n).Save(f);
        }

        Door(false).Save("buildings/forge_door.png");
        var bp = new Pix(16, 16);
        FillNoise(bp, StoneBrick, 3, 5, 5);
        pOutlineHouse(bp);
        bp.Save("items/buildings/forge_blueprint.png");

        string[] playerFrames =
        {
            "player/player_idle.png","player/player_walk_a.png","player/player_walk_b.png",
            "player/player_run_a.png","player/player_run_b.png","player/player_jump.png",
            "player/player_fall.png","player/player_use_tool.png","player/player_crouch_idle.png",
            "player/player_crouch_walk_a.png","player/player_crouch_walk_b.png",
        };
        foreach (string f in playerFrames)
        {
            var pl = Pix.LoadOriginal(f);
            EnhancePlayer(pl, f.GetHashCode());
            pl.Save(f);
        }
        var ph = Pix.LoadOriginal("player/player_placeholder.png");
        EnhancePlayer(ph, 1);
        ph.Save("player/player_placeholder.png");

        string[] armorParts = { "chest", "helmet", "legs" };
        string[] armorAnims =
        {
            "idle","walk_a","walk_b","run_a","run_b","jump","fall","use_tool",
            "crouch_idle","crouch_walk_a","crouch_walk_b"
        };
        foreach (string part in armorParts)
            foreach (string anim in armorAnims)
            {
                string f = "player/armor/" + part + "_" + anim + ".png";
                var ar = Pix.LoadOriginal(f);
                EnhanceArmor(ar, f.GetHashCode());
                ar.Save(f);
            }

        Dummy().Save("test/combat_dummy.png");

        EnhanceBackground("world/background/hills_grass.png", new[] { C(32, 56, 36), C(48, 80, 44), C(64, 104, 52), C(88, 128, 64) }, 2);
        EnhanceBackground("world/background/hills_sand.png", Sand, 3);
        EnhanceBackground("world/background/far_trees.png", OakLeaf, 4);
        EnhanceBackground("world/background/far_trees_sand.png", new[] { C(80, 72, 40), C(110, 96, 48), C(140, 120, 58) }, 5);
        EnhanceBackground("world/background/mid_trees.png", OakLeaf, 6);
        EnhanceBackground("world/background/dark_dirt_background.png", Dirt, 7);
        EnhanceBackground("world/background/dark_stone_background.png", Stone, 8);
        EnhanceBackground("world/background/deep_stone_background.png", Bedrock, 9);
        EnhanceBackground("world/background/fog_haze.png", new[] { C(40, 16, 36, 80), C(72, 24, 52, 100), C(28, 10, 24, 60) }, 10);

        Cloud(36, 20, 1).Save("world/background/cloud_puff.png");
        Cloud(48, 18, 2).Save("world/background/cloud_wispy.png");
        Cloud(104, 34, 3).Save("world/background/large_cloud.png");
        Cloud(72, 26, 4).Save("world/background/medium_cloud.png");
        Cloud(40, 18, 5).Save("world/background/small_cloud.png");
        Sun().Save("world/celestial/sun.png");
        Moon().Save("world/celestial/moon.png");

        UiIcon("bag").Save("ui/bag_icon.png");
        UiIcon("trash").Save("ui/trash_icon.png");
        UiIcon("search").Save("ui/search_icon.png");
        UiIcon("marker").Save("ui/map_player_marker.png");
        UiIcon("slot_helm").Save("ui/slot_helm.png");
        UiIcon("slot_chest").Save("ui/slot_chest.png");
        UiIcon("slot_legs").Save("ui/slot_legs.png");
        UiIcon("slot_boots").Save("ui/slot_boots.png");
        UiIcon("slot_acc").Save("ui/slot_acc.png");

        Console.WriteLine("Done.");
    }

    static void pOutlineHouse(Pix p)
    {
        p.Clear();
        for (int y = 6; y < 14; y++)
            p.HLine(3, y, 10, Shade(StoneBrick, 2));
        for (int i = 0; i < 6; i++)
            p.HLine(8 - i, 1 + i, i * 2 + 1, Shade(Oak, 2));
        p.Rect(7, 9, 3, 5, Shade(Oak, 1));
        p.OutlineDark();
    }
}

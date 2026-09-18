from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "buildings" / "forge_door.png"

W, H = 32, 64
img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
px = img.load()

def p(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = c

DARK = (42, 24, 14, 255)
MID = (78, 46, 26, 255)
LIT = (112, 70, 38, 255)
EDGE = (28, 16, 10, 255)
IRON = (88, 90, 96, 255)
IRON_D = (52, 54, 58, 255)
IRON_L = (140, 144, 150, 255)
HANDLE = (186, 150, 62, 255)

for y in range(H):
    for x in range(W):
        if x in (0, W - 1) or y in (0, H - 1):
            p(x, y, EDGE)
        elif x in (1, W - 2) or y in (1, H - 2):
            p(x, y, DARK)
        else:
            board = MID if ((x // 5) + (y // 8)) % 2 == 0 else LIT
            p(x, y, board)

for y in (10, 22, 34, 46, 54):
    for x in range(3, W - 3):
        p(x, y, IRON_D)
        p(x, y + 1, IRON)
for x in (6, 25):
    for y in range(8, 58):
        p(x, y, IRON_D)
        p(x + 1, y, IRON)
for cx, cy in ((8, 12), (22, 12), (8, 50), (22, 50), (8, 31), (22, 31)):
    p(cx, cy, IRON_L)
    p(cx + 1, cy, IRON)
    p(cx, cy + 1, IRON)
    p(cx + 1, cy + 1, IRON_D)
for y in range(28, 36):
    p(24, y, HANDLE)
    p(25, y, HANDLE)
p(26, 31, HANDLE)
p(27, 31, (120, 90, 32, 255))

OUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUT)
print("wrote", OUT)

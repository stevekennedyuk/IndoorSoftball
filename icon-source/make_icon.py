import sys, math
from PIL import Image, ImageDraw, ImageFilter, ImageFont
S = 2048  # draw at 2x, downsample for anti-aliasing
NAVY = (22, 36, 71); NAVY2 = (14, 24, 50)
CHAR = (64, 70, 80)
POWDER_TOP = (178, 211, 238); POWDER_BOT = (120, 170, 214)
FACE = (246, 248, 251); GREY = (150, 158, 170)
RED = (206, 44, 44)

img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(POWDER_TOP, POWDER_BOT)))

# subtle pinstripe band like an umpire shirt placket
for x in (S//2 - 520, S//2 + 520):
    pass

cx, cy = S // 2, S // 2 + 90
R = 700  # case radius

# drop shadow
sh = Image.new("RGBA", (S, S), (0, 0, 0, 0)); sd = ImageDraw.Draw(sh)
sd.ellipse([cx - R, cy - R + 60, cx + R, cy + R + 60], fill=(10, 25, 55, 120))
sd.rounded_rectangle([cx - 120, cy - R - 250 + 60, cx + 120, cy - R + 60], 40, fill=(10, 25, 55, 120))
sh = sh.filter(ImageFilter.GaussianBlur(50))
img.paste(sh, (0, 0), sh)
d = ImageDraw.Draw(img)

# crown stem + button on top
d.rounded_rectangle([cx - 70, cy - R - 150, cx + 70, cy - R + 40], 24, fill=CHAR)
d.rounded_rectangle([cx - 170, cy - R - 260, cx + 170, cy - R - 130], 40, fill=NAVY)
# side pusher at 1-2 o'clock
a = math.radians(-50)
px, py = cx + (R + 40) * math.cos(a), cy + (R + 40) * math.sin(a)
pusher = Image.new("RGBA", (S, S), (0, 0, 0, 0)); pd = ImageDraw.Draw(pusher)
pd.rounded_rectangle([px - 60, py - 110, px + 60, py + 110], 30, fill=CHAR)
pusher = pusher.rotate(-(-50 + 90), center=(px, py))
img.paste(pusher, (0, 0), pusher)
d = ImageDraw.Draw(img)

# case: navy with charcoal rim
d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=CHAR)
d.ellipse([cx - R + 34, cy - R + 34, cx + R - 34, cy + R - 34], fill=NAVY)
# face
F = R - 120
d.ellipse([cx - F, cy - F, cx + F, cy + F], fill=FACE)

# remaining-time sector (powder blue) — clock 3/4 through? show ~ 1/3 remaining
remaining_frac = 0.30
start = -90
end = start + 360 * remaining_frac
SR = F - 70
d.pieslice([cx - SR, cy - SR, cx + SR, cy + SR], start, end, fill=POWDER_BOT)

# minute ticks
for i in range(60):
    ang = math.radians(i * 6 - 90)
    major = i % 5 == 0
    r1 = F - (95 if major else 55)
    r2 = F - 22
    w = 26 if major else 10
    col = NAVY if major else GREY
    d.line([(cx + r1 * math.cos(ang), cy + r1 * math.sin(ang)),
            (cx + r2 * math.cos(ang), cy + r2 * math.sin(ang))], fill=col, width=w)

# hand pointing to end of sector
ang = math.radians(end)
L = SR - 10
d.line([(cx - 90 * math.cos(ang), cy - 90 * math.sin(ang)),
        (cx + L * math.cos(ang), cy + L * math.sin(ang))], fill=RED, width=34)
d.ellipse([cx - 62, cy - 62, cx + 62, cy + 62], fill=RED)
d.ellipse([cx - 24, cy - 24, cx + 24, cy + 24], fill=NAVY)

# "1/2" inning chevrons? Simple: small navy label in lower face
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 150)
except Exception:
    font = ImageFont.load_default()
txt = "5:00"
bb = d.textbbox((0, 0), txt, font=font)
tw, th = bb[2] - bb[0], bb[3] - bb[1]
d.text((cx - tw / 2 - bb[0], cy + 250 - bb[1]), txt, font=font, fill=NAVY)

img = img.resize((1024, 1024), Image.LANCZOS)
img.save(sys.argv[1])

#!/usr/bin/env python3
"""
App Store "Header and Search Results" artwork for Indoor Softball Scorer
(iOS 27 / iPadOS 27 placements), reusing the screen drawings from
make_screenshots.py.

    Product page header      3840 x 1646  (21:9)
    Search results           3840 x 2560 and 1920 x 1280  (3:2)
    Universal (both)         5244 x 2950  (16:9 PNG) – content kept inside the
                             area that survives both the 21:9 and 3:2 crops

All opaque RGB PNGs, written to ./screenshots/.
"""

import os
from PIL import Image, ImageDraw, ImageFilter

import make_screenshots as ms

OUT = ms.OUT
ICON = ms.ICON_SRC


def background(W, H):
    img = Image.new("RGB", (W, H))
    ms.vgrad(img, ms.NAVY_T, ms.NAVY_B)
    # soft powder-blue glow behind the devices
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    r = int(H * 0.55)
    cx, cy = int(W * 0.70), int(H * 0.45)
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(*ms.POWDER, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(H * 0.18))
    img.paste(glow, (0, 0), glow)
    return img


def rounded_icon(size):
    ic = Image.open(ICON).convert("RGB").resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], int(size * 0.225), fill=255)
    return ic, mask


def watch_frame(img, cx, cy, w, draw):
    """Apple Watch Ultra-style body with the watch screen drawn inside."""
    h = w * 1.22
    x0, y0 = cx - w / 2, cy - h / 2
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([x0 + w * 0.03, y0 + w * 0.07, x0 + w * 1.03, y0 + h + w * 0.07],
                                         int(w * 0.24), fill=(0, 0, 0, 120))
    sh = sh.filter(ImageFilter.GaussianBlur(w * 0.06))
    img.paste(sh, (0, 0), sh)
    d = ImageDraw.Draw(img)
    # crown + side button
    d.rounded_rectangle([x0 + w * 0.97, y0 + h * 0.26, x0 + w * 1.06, y0 + h * 0.42], int(w * 0.03), fill=(150, 154, 162))
    d.rounded_rectangle([x0 + w * 0.97, y0 + h * 0.52, x0 + w * 1.03, y0 + h * 0.68], int(w * 0.02), fill=(120, 124, 132))
    d.rounded_rectangle([x0, y0, x0 + w, y0 + h], int(w * 0.24), fill=(38, 40, 46), outline=(96, 100, 112),
                        width=max(2, int(w * 0.012)))
    inset = w * 0.07
    sw, shh = w - 2 * inset, h - 2 * inset
    scr = Image.new("RGB", (int(sw), int(shh)), ms.BLACK)
    draw(ms.Screen(scr, 0, 0, sw / 211))
    m = Image.new("L", scr.size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, scr.size[0] - 1, scr.size[1] - 1], int(w * 0.17), fill=255)
    img.paste(scr, (int(x0 + inset), int(y0 + inset)), m)


def compose(W, H, safe, name):
    """safe = (x0, y0, x1, y1): the area that must stay visible."""
    ms.SS = 1
    img = background(W, H)
    d = ImageDraw.Draw(img)
    sx0, sy0, sx1, sy1 = safe
    sw, sh = sx1 - sx0, sy1 - sy0

    # ---- devices (right): phone bleeds off the bottom, watch in front
    ph_h = sh * 1.10
    ph_w = ph_h * ms.IPH_W / ms.IPH_H
    wa_w = ph_w * 0.58
    gap = ph_w * 0.10
    # phone + watch side by side, right-aligned in the safe area (no overlap)
    ph_cx = sx1 - wa_w * 1.06 - gap - ph_w / 2
    ph_top = sy0 + sh * 0.04
    ms.device_frame(img, [ph_cx - ph_w / 2, ph_top, ph_cx + ph_w / 2, ph_top + ph_h],
                    int(ph_w * 0.13), lambda s: ms.iphone_live(s, "running"), (ms.IPH_W, ms.IPH_H))
    watch_frame(img, ph_cx + ph_w / 2 + gap + wa_w / 2, sy0 + sh * 0.56, wa_w, ms.watch_scoring)

    # ---- text (left)
    d = ImageDraw.Draw(img)
    tx = sx0 + sw * 0.02
    tw = ph_cx - ph_w / 2 - tx - sw * 0.04
    icon_sz = int(sh * 0.17)
    ic, mask = rounded_icon(icon_sz)
    iy = int(sy0 + sh * 0.08)
    img.paste(ic, (int(tx), iy), mask)
    d.text((tx + icon_sz * 1.22, iy + icon_sz * 0.50), "Indoor Softball", font=ms.font("xb", icon_sz * 0.40),
           fill=ms.WHITE, anchor="lm")

    def fit(text, kind, px):
        while d.textlength(text, font=ms.font(kind, px)) > tw and px > 10:
            px -= 2
        return ms.font(kind, px)

    hl = int(sh * 0.135)
    f1 = fit("Big buttons.", "blk", hl)
    f2 = fit("Every point.", "blk", hl)
    hl_px = min(f1.size, f2.size)
    y = iy + icon_sz + sh * 0.10
    d.text((tx, y), "Big buttons.", font=ms.font("blk", hl_px), fill=ms.WHITE, anchor="la")
    y += hl_px * 1.12
    d.text((tx, y), "Every point.", font=ms.font("blk", hl_px), fill=ms.POWDER, anchor="la")
    y += hl_px * 1.45
    sub = fit("Indoor & outdoor scoring  ·  timed half innings", "m", int(sh * 0.048))
    d.text((tx, y), "Indoor & outdoor scoring  ·  timed half innings", font=sub, fill=(205, 222, 240), anchor="la")
    y += sub.size * 1.7
    small = fit("iPhone  ·  iPad  ·  Apple Watch", "sb", int(sh * 0.036))
    d.text((tx, y), "iPhone  ·  iPad  ·  Apple Watch", font=small, fill=(150, 170, 200), anchor="la")

    img.save(os.path.join(OUT, name), optimize=True)
    return name


if __name__ == "__main__":
    made = []
    # Product page header 21:9 – keep clear of the outer edges
    W, H = 3840, 1646
    made.append(compose(W, H, (W * 0.08, H * 0.10, W * 0.92, H * 0.90), "header_3840x1646.png"))
    # Search results 3:2
    for W, H in ((3840, 2560), (1920, 1280)):
        made.append(compose(W, H, (W * 0.07, H * 0.12, W * 0.93, H * 0.88), f"search_{W}x{H}.png"))
    # Universal 16:9 – visible in both crops: 21:9 crop keeps full width, height 5244/21*9;
    # 3:2 crop keeps full height, width 2950*1.5. Safe area = intersection, with margin.
    W, H = 5244, 2950
    hh = W * 9 / 21          # 2247
    ww = H * 1.5             # 4425
    x0, y0 = (W - ww) / 2, (H - hh) / 2
    made.append(compose(W, H, (x0 + ww * 0.05, y0 + hh * 0.08, x0 + ww * 0.95, y0 + hh * 0.92),
                        "universal_5244x2950.png"))
    for n in made:
        im = Image.open(os.path.join(OUT, n))
        print(f"{n:32s} {im.size[0]}x{im.size[1]} {im.mode}")

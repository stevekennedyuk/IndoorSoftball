#!/usr/bin/env python3
"""
App Store / TestFlight images for Indoor Softball Scorer.

Draws the app's real screens (same layout, colours and copy as the SwiftUI
views) under a marketing headline, at the sizes App Store Connect accepts:

    iPhone 6.9"   1320 x 2868   (required set – "iPhone 6.9-inch Display")
    iPhone 6.5"   1242 x 2688   (accepted alternative)
    iPhone 6.3"   1206 x 2622   (asked for by App Store Connect)
    iPhone 6.1"   1179 x 2556   (asked for by App Store Connect)
    iPhone         886 x 1920   (app-preview size slot)
    iPhone Duo    1398 x 2034   (outer / folded screen)
    iPhone Duo    2007 x 2853   (inner / unfolded screen)
    iPad 13"      2064 x 2752   ("iPad 13-inch Display")
    Apple Watch    422 x  514   (Ultra size – raw screens, no headline)
    App icon      1024 x 1024   (App Store / TestFlight icon, opaque RGB)

All outputs are opaque RGB PNGs written to ./screenshots/ next to this script.
Requires Pillow. Fonts: ./fonts (Inter + Nunito, both SIL OFL) are bundled.
"""

import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "screenshots")
FONTS = os.path.join(HERE, "fonts")
ICON_SRC = os.path.join(HERE, "..", "IndoorSoftball", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")
os.makedirs(OUT, exist_ok=True)

SS = 2  # supersampling factor for smooth edges

# ---------------------------------------------------------------- colours
# App theme (Shared/UI/Theme.swift)
AWAY = (66, 148, 255)
HOME = (255, 128, 51)
POS = (56, 209, 107)
NEG = (255, 82, 82)
WARN = (255, 194, 13)
IDLE = (140, 140, 140)
CARD = (33, 33, 33)
CARD2 = (48, 48, 48)
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
GREY = (152, 152, 160)
DIM = (100, 100, 108)
# Marketing background: umpire navy + powder blue (matches the icon)
NAVY_T = (24, 40, 78)
NAVY_B = (9, 17, 38)
POWDER = (178, 211, 238)


def mix(c, bg, a):
    return tuple(int(c[i] * a + bg[i] * (1 - a)) for i in range(3))


# ---------------------------------------------------------------- fonts
_cache = {}


def font(kind, px):
    files = {
        "r": "Inter-Regular.otf", "m": "Inter-Medium.otf", "sb": "Inter-SemiBold.otf",
        "b": "Inter-Bold.otf", "xb": "Inter-ExtraBold.otf", "blk": "Inter-Black.otf",
        "rnd": "Nunito-900.ttf", "rnd8": "Nunito-800.ttf",
    }
    key = (kind, int(px))
    if key not in _cache:
        _cache[key] = ImageFont.truetype(os.path.join(FONTS, files[kind]), max(1, int(px)))
    return _cache[key]


# ---------------------------------------------------------------- canvas in points
class Screen:
    """Draws in iOS points inside a box on the image; u = pixels per point."""

    def __init__(self, img, x0, y0, u):
        self.img, self.d, self.x0, self.y0, self.u = img, ImageDraw.Draw(img), x0, y0, u

    def P(self, x, y):
        return (self.x0 + x * self.u, self.y0 + y * self.u)

    def rect(self, x, y, w, h, r=0, fill=None, outline=None, width=1):
        a, b = self.P(x, y), self.P(x + w, y + h)
        self.d.rounded_rectangle([a, b], radius=r * self.u, fill=fill, outline=outline,
                                 width=max(1, int(width * self.u)) if outline else 0)

    def circle(self, cx, cy, r, fill):
        a, b = self.P(cx - r, cy - r), self.P(cx + r, cy + r)
        self.d.ellipse([a, b], fill=fill)

    def text(self, x, y, s, kind, size, fill, anchor="la", max_w=None):
        f = font(kind, size * self.u)
        if max_w is not None:
            px = size
            while px > 6 and self.d.textlength(s, font=f) > max_w * self.u:
                px -= 1
                f = font(kind, px * self.u)
        self.d.text(self.P(x, y), s, font=f, fill=fill, anchor=anchor)

    def width(self, s, kind, size):
        return self.d.textlength(s, font=font(kind, size * self.u)) / self.u


def vgrad(img, top, bot):
    d = ImageDraw.Draw(img)
    W, H = img.size
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))


# ---------------------------------------------------------------- game data
GAME = {
    "away": "Hawks", "home": "Owls",
    # inning 1
    "t1": (11, -2), "b1": (8, -2),
    # live top 2 (shot 1), finished top 2 (shot 2+), bottom 2 (final)
    "t2_live": (7, -2), "t2": (9, -2), "b2": (12, -1),
}


def net(p):
    return p[0] + p[1]


def sgn(n):
    return f"+{n}" if n > 0 else (f"−{-n}" if n < 0 else "0")


def score(n):
    return f"−{-n}" if n < 0 else str(n)


# ---------------------------------------------------------------- shared iOS chrome
def status_bar(s, w):
    s.text(28, 17, "9:41", "sb", 16, WHITE, "lm")
    # battery + signal glyphs (simple)
    s.rect(w - 52, 11, 25, 12, 3, outline=WHITE, width=1.2)
    s.rect(w - 50, 13, 18, 8, 2, fill=WHITE)
    for i, hgt in enumerate((5, 7, 9, 11)):
        s.rect(w - 82 + i * 5, 23 - hgt, 3, hgt, 1, fill=WHITE)


def nav_bar(s, w, y, title, left=None, right="⋯"):
    if left:
        s.text(16, y + 22, left, "m", 17, POS, "lm")
    s.text(w / 2, y + 22, title, "sb", 17, WHITE, "mm")
    if right:
        s.d.ellipse([s.P(w - 38, y + 10), s.P(w - 14, y + 34)], outline=POS, width=int(2 * s.u))
        for dx in (-6, 0, 6):
            s.circle(w - 26 + dx, y + 22, 1.8, POS)


def tab_bar(s, w, h, active=0):
    y = h - 83
    s.d.rectangle([s.P(0, y), s.P(w, h)], fill=(18, 18, 20))
    s.d.line([s.P(0, y), s.P(w, y)], fill=(45, 45, 50), width=max(1, int(0.5 * s.u)))
    labels = ["Game", "History", "Settings"]
    for i, lab in enumerate(labels):
        cx = w * (i + 0.5) / 3
        col = POS if i == active else GREY
        # icon placeholder glyphs
        if i == 0:
            s.rect(cx - 13, y + 10, 26, 18, 4, outline=col, width=2)
            s.d.line([s.P(cx, y + 10), s.P(cx, y + 28)], fill=col, width=int(2 * s.u))
        elif i == 1:
            for k in range(3):
                s.rect(cx - 11, y + 11 + k * 6, 22, 3, 1.5, fill=col)
        else:
            s.circle(cx, y + 19, 9, col)
            s.circle(cx, y + 19, 4, (18, 18, 20))
        s.text(cx, y + 40, lab, "m", 10, col, "mm")
    s.rect(w / 2 - 67, h - 13, 134, 5, 2.5, fill=WHITE)


# ---------------------------------------------------------------- iOS components
def score_header(s, x, y, w, inning, top, away_total, home_total, large=False, compact=False):
    cw = 44 if not large else 70
    tw = (w - cw - 16) / 2
    th = 92 if not large else 126
    if compact:
        th = 80
    for i, team in enumerate(("away", "home")):
        tx = x if i == 0 else x + tw + cw + 16
        batting = (team == "away") == top
        col = AWAY if team == "away" else HOME
        s.rect(tx, y, tw, th, 14, fill=mix(col, BLACK, 0.28 if batting else 0.10),
               outline=col if batting else mix(col, BLACK, 0.3), width=2 if batting else 1)
        name = GAME[team]
        nx = tx + tw / 2
        s.text(nx, y + 15 if not large else y + 20, ("⚾ " if False else "") + name, "sb", 15 if not large else 18, WHITE, "mm")
        total = away_total if team == "away" else home_total
        s.text(nx, y + (42 if compact else (48 if not large else 66)), score(total), "rnd", 34 if compact else (44 if not large else 72), WHITE, "mm")
        badge = "AT BAT" if batting else "FIELDING"
        bw = s.width(badge, "xb", 10) + 12
        if batting:
            s.rect(nx - bw / 2, y + th - 20, bw, 14, 7, fill=col)
        s.text(nx, y + th - 13, badge, "xb", 10, BLACK if batting else GREY, "mm")
    cx = x + tw + 8 + cw / 2
    s.text(cx, y + th / 2 - 24, "TOP" if top else "BOT", "xb", 11, WHITE, "mm")
    s.text(cx, y + th / 2 + 2, str(inning), "rnd", 26 if not large else 40, WHITE, "mm")
    s.text(cx, y + th / 2 + 26, "of 2", "r", 11, GREY, "mm")
    return y + th


def clock_card(s, x, y, w, label, clock, frac, state, next_label=None, large=False, fill_h=None, compact=False):
    col = {"running": POS, "timeup": NEG, "ready": IDLE}[state]
    big = 64 if not large else (170 if fill_h else 110)
    h = (170 if not large else 250) if state != "timeup" else (172 if not large else 252)
    if compact:
        big, h = 52, 150
    if fill_h:
        h = fill_h
    s.rect(x, y, w, h, 18, fill=mix(NEG, BLACK, 0.22) if state == "timeup" else CARD,
           outline=col if state != "ready" else mix(col, BLACK, 0.3), width=2)
    p = 10 if not large else 16
    status = {"running": "RUNNING", "timeup": f"TIME – {label} over", "ready": "READY"}[state]
    s.text(x + p, y + p + 8, status, "xb", 12 if not large else 14, col, "lm")
    s.text(x + w - p, y + p + 8, f"{label} · 5:00", "r", 12 if not large else 14, GREY, "rm")
    bh = 46 if not large else 56
    if compact:
        bh = 36
    if fill_h:
        by = y + h - p - bh - 16 - 8
        s.text(x + w / 2, (y + p + 20 + by) / 2, clock, "rnd", big, col, "mm")
    else:
        s.text(x + w / 2, y + p + 22 + big * 0.52, clock, "rnd", big, col, "mm")
        by = y + p + (24 if compact else 26) + big * 1.0
    s.rect(x + p, by, w - 2 * p, 8, 4, fill=(45, 45, 48))
    s.rect(x + p, by, max(8, (w - 2 * p) * frac), 8, 4, fill=col)
    ry = by + (12 if compact else 16)
    if state == "timeup":
        s.rect(x + p, ry, w - 2 * p, bh, 12, fill=NEG)
        s.text(x + w / 2, ry + bh / 2, f"▶  {next_label}", "b", 18 if not large else 22, WHITE, "mm")
    else:
        sw = 66 if not large else 84
        for i, t in enumerate(("−30s", "+30s")):
            bx = x + p if i == 0 else x + w - p - sw
            s.rect(bx, ry, sw, bh, 12, fill=(44, 44, 48))
            s.text(bx + sw / 2, ry + bh / 2, t, "sb", 16 if not large else 19, POS, "mm")
        mx = x + p + sw + 10
        mw = w - 2 * p - 2 * sw - 20
        running = state == "running"
        s.rect(mx, ry, mw, bh, 12, fill=WARN if running else POS)
        lab = "Pause" if running else "▶  Start clock"
        fs = 18 if not large else 22
        if running:
            tw = s.width(lab, "b", fs)
            gx = mx + mw / 2 - (tw + fs * 1.1) / 2
            for k in (0, 1):
                s.rect(gx + k * fs * 0.38, ry + bh / 2 - fs * 0.38, fs * 0.24, fs * 0.76, 1.5, fill=BLACK)
            s.text(gx + fs * 1.1, ry + bh / 2, lab, "b", fs, BLACK, "lm")
        else:
            s.text(mx + mw / 2, ry + bh / 2, lab, "b", fs, BLACK, "mm")
    return y + h


def tally_bar(s, x, y, w, label, plus, minus, batting_col, large=False, compact=False):
    s.text(x + w / 2, y + 8, label, "sb", 12 if not large else 15, batting_col, "mm")
    y += 18
    bw = (w - 16) / 3
    bh = 66 if not large else 92
    if compact:
        bh = 56
    tot = plus + minus
    items = [("PLUS", f"+{plus}", POS, False), ("MINUS", sgn(minus) if minus else "−0", NEG, False),
             ("TOTAL", score(tot), POS if tot > 0 else (NEG if tot < 0 else IDLE), True)]
    for i, (t, v, c, emph) in enumerate(items):
        bx = x + i * (bw + 8)
        s.rect(bx, y, bw, bh, 14, fill=CARD2 if emph else CARD, outline=mix(c, BLACK, 0.6 if emph else 0.25),
               width=2 if emph else 1)
        s.text(bx + bw / 2, y + 13 if not large else y + 16, t, "xb", 10 if not large else 12, GREY, "mm")
        s.text(bx + bw / 2, y + bh / 2 + 8, v, "rnd", 28 if compact else (32 if not large else 48), c, "mm")
    return y + bh


def pad_button(s, x, y, w, h, title, sub, col, big):
    s.rect(x, y, w, h, 14, fill=mix(col, BLACK, 0.16), outline=mix(col, BLACK, 0.55), width=1.5)
    s.text(x + w / 2, y + h / 2 - big * 0.12, title, "rnd", big, col, "mm")
    s.text(x + w / 2, y + h / 2 + big * 0.55, sub, "sb", max(12, big * 0.24), col, "mm")


def scoring_pad(s, x, y, w, h, hr=5, large=False, compact=False):
    gap = 8 if compact else 10
    row2 = 110 if large else (48 if compact else 80)   # matches ScoringPad.hrRowHeight
    row1 = h - row2 - gap
    bw = (w - gap) / 2
    pad_button(s, x, y, bw, row1, "+1", "Point", POS, 50 if not large else 64)
    pad_button(s, x + bw + gap, y, bw, row1, "−1", "Minus", NEG, 50 if not large else 64)
    uw = 76 if not large else 110
    pad_button(s, x, y + row1 + gap, w - uw - gap, row2, f"HR +{hr}", "" if compact else "★ Home Run", WARN,
               26 if compact else (36 if not large else 46))
    ux = x + w - uw
    uy = y + row1 + gap
    s.rect(ux, uy, uw, row2, 14, fill=mix((140, 140, 140), BLACK, 0.16), outline=mix((140, 140, 140), BLACK, 0.55), width=1.5)
    if compact:
        s.text(ux + uw / 2, uy + row2 / 2, "↩", "b", 22, WHITE, "mm")
    else:
        s.text(ux + uw / 2, uy + row2 / 2 - 8, "↩", "b", 26, WHITE, "mm")
        s.text(ux + uw / 2, uy + row2 / 2 + 20, "Undo", "sb", 12, WHITE, "mm")


def line_score(s, x, y, w, rows, large=False):
    """rows: list of (team, colour, [cells or None], total, winner?)"""
    h = 120 if not large else 150
    s.rect(x, y, w, h, 16, fill=CARD)
    cols = ["1", "2", "Total"]
    nx = x + 14
    cx0 = x + w * 0.42
    cwid = (w - (cx0 - x) - 14) / 3
    s.text(nx, y + 22, "", "r", 12, GREY)
    for i, c in enumerate(cols):
        s.text(cx0 + cwid * (i + 0.5), y + 22, c, "m", 12 if not large else 14, GREY, "mm")
    s.d.line([s.P(x + 12, y + 36), s.P(x + w - 12, y + 36)], fill=(60, 60, 64), width=max(1, int(s.u)))
    for r, (team, col, cells, total, win) in enumerate(rows):
        ry = y + 62 + r * 36
        s.circle(nx + 4, ry, 3.5, col)
        s.text(nx + 14, ry, team, "sb", 15 if not large else 17, WHITE, "lm")
        for i, c in enumerate(cells):
            cx = cx0 + cwid * (i + 0.5)
            if c is None:
                s.text(cx, ry, "–", "r", 15, DIM, "mm")
            else:
                n, p, m = c
                s.text(cx, ry - 5, score(n), "rnd8", 17 if not large else 20, POS if n > 0 else NEG if n < 0 else IDLE, "mm")
                s.text(cx, ry + 11, f"+{p} {sgn(m) if m else '−0'}", "r", 9 if not large else 10, GREY, "mm")
        s.text(cx0 + cwid * 2.5, ry, score(total), "rnd", 20 if not large else 24, col if win else WHITE, "mm")
    return y + h


# ---------------------------------------------------------------- full iPhone screens
IPH_W, IPH_H = 402, 874   # iPhone 17 Pro / 16 Pro logical size


def iphone_live(s, state, w=IPH_W, h=IPH_H, mode="regular"):
    large, compact = mode == "large", mode == "compact"
    gap = 14 if large else (8 if compact else 10)
    s.rect(0, 0, w, h, 0, fill=BLACK)
    status_bar(s, w)
    nav_bar(s, w, 50, "Top 2", left="Scores")
    t1, b1 = GAME["t1"], GAME["b1"]
    half = GAME["t2_live"] if state == "running" else GAME["t2"]
    away_total = net(t1) + net(half)
    home_total = net(b1)
    x = 24 if large else 14
    cw = w - 2 * x
    y = 104
    kw = dict(large=large, compact=compact)
    y = score_header(s, x, y, cw, 2, True, away_total, home_total, **kw) + gap
    if state == "running":
        y = clock_card(s, x, y, cw, "Top 2", "2:47", 0.443, "running", **kw) + gap
    else:
        y = clock_card(s, x, y, cw, "Top 2", "0:00", 1.0, "timeup", next_label="Start Bottom 2", **kw) + gap
    y = tally_bar(s, x, y, cw, "Top 2 – Hawks batting", half[0], half[1], AWAY, **kw) + gap
    scoring_pad(s, x, y, cw, (h - 83 - 6) - y, large=large, compact=compact)
    tab_bar(s, w, h, 0)


def iphone_final(s, w=IPH_W, h=IPH_H):
    s.rect(0, 0, w, h, 0, fill=BLACK)
    status_bar(s, w)
    nav_bar(s, w, 50, "Final", left="Close", right=None)
    t1, b1, t2, b2 = GAME["t1"], GAME["b1"], GAME["t2"], GAME["b2"]
    A = net(t1) + net(t2)
    H = net(b1) + net(b2)
    x, cw = 16, w - 32
    y = 108
    # simple trophy glyph
    s.rect(x, y + 2, 22, 16, 4, fill=HOME)
    s.rect(x + 8, y + 18, 6, 6, 1, fill=HOME)
    s.rect(x + 4, y + 24, 14, 4, 2, fill=HOME)
    s.text(x + 32, y + 14, f"Owls win {H} – {A}", "xb", 24, WHITE, "lm")
    y += 44
    tw = (cw - 12) / 2
    for i, (team, col, tot, p, m, win) in enumerate((("Hawks", AWAY, A, t1[0] + t2[0], t1[1] + t2[1], False),
                                                     ("Owls", HOME, H, b1[0] + b2[0], b1[1] + b2[1], True))):
        tx = x + i * (tw + 12)
        s.rect(tx, y, tw, 132, 14, fill=mix(col, BLACK, 0.35 if win else 0.15), outline=col if win else None, width=2)
        s.text(tx + tw / 2, y + 20, team, "sb", 15, WHITE, "mm")
        s.text(tx + tw / 2, y + 66, score(tot), "rnd", 52, WHITE, "mm")
        s.text(tx + tw / 2, y + 112, f"+{p}  {sgn(m)}", "m", 13, GREY, "mm")
    y += 132 + 16
    y = line_score(s, x, y, cw, [
        ("Hawks", AWAY, [(net(t1),) + t1, (net(t2),) + t2], A, False),
        ("Owls", HOME, [(net(b1),) + b1, (net(b2),) + b2], H, True),
    ]) + 16
    for inn, (top, bot) in enumerate(((t1, b1), (t2, b2)), start=1):
        ch = 128
        s.rect(x, y, cw, ch, 14, fill=CARD)
        s.text(x + 14, y + 20, f"Inning {inn}", "b", 16, GREY, "lm")
        for r, (lab, col, p) in enumerate((("Top – Hawks", AWAY, top), ("Bottom – Owls", HOME, bot))):
            ry = y + 48 + r * 26
            s.circle(x + 18, ry, 3.5, col)
            s.text(x + 28, ry, lab, "r", 14, WHITE, "lm")
            s.text(x + cw - 120, ry, f"+{p[0]}", "m", 14, POS, "rm")
            s.text(x + cw - 76, ry, sgn(p[1]), "m", 14, NEG, "rm")
            s.text(x + cw - 14, ry, f"= {score(net(p))}", "b", 14, WHITE, "rm")
        s.d.line([s.P(x + 14, y + 98), s.P(x + cw - 14, y + 98)], fill=(60, 60, 64), width=max(1, int(s.u)))
        a = net(t1) + (net(t2) if inn == 2 else 0)
        hh = net(b1) + (net(b2) if inn == 2 else 0)
        s.text(x + 14, y + 113, f"End of inning {inn}", "r", 13, GREY, "lm")
        s.text(x + cw - 14, y + 113, f"Hawks {a} – Owls {hh}", "b", 14, WHITE, "rm")
        y += ch + 12
    tab_bar(s, w, h, 0)


# ---------------------------------------------------------------- iPad screen
IPAD_W, IPAD_H = 1032, 1376   # iPad Pro 13" logical portrait
DUO_OUT_W, DUO_OUT_H = 466, 678    # iPhone Duo outer screen (1398x2034 @3x)
DUO_IN_W, DUO_IN_H = 669, 951      # iPhone Duo inner screen (2007x2853 @3x)


def ipad_live(s):
    w, h = IPAD_W, IPAD_H
    s.rect(0, 0, w, h, 0, fill=BLACK)
    s.text(30, 16, "9:41  Sat 7 Nov", "sb", 15, WHITE, "lm")
    nav_bar(s, w, 30, "Top 2")
    t1, b1, half = GAME["t1"], GAME["b1"], GAME["t2_live"]
    A, H = net(t1) + net(half), net(b1)
    p = 20
    lw = w - 2 * p - 20 - 520
    x0, y0 = p, 90
    y = score_header(s, x0, y0, lw, 2, True, A, H, large=True) + 16
    bottom = h - 90 - 20 - 10 + 0          # same bottom edge as the scoring pad
    ls_h = 150
    y = clock_card(s, x0, y, lw, "Top 2", "2:47", 0.443, "running", large=True,
                   fill_h=bottom - ls_h - 16 - y) + 16
    line_score(s, x0, y, lw, [
        ("Hawks", AWAY, [(net(t1),) + t1, (net(half),) + half], A, False),
        ("Owls", HOME, [(net(b1),) + b1, None], H, False),
    ], large=True)
    rx = x0 + lw + 20
    rw = 520
    y = tally_bar(s, rx, y0, rw, "Top 2 – Hawks batting", half[0], half[1], AWAY, large=True) + 16
    scoring_pad(s, rx, y, rw, h - 90 - 20 - y - 10, large=True)
    # tab bar (iPadOS floating style)
    tb_w = 330
    s.rect(w / 2 - tb_w / 2, h - 70, tb_w, 46, 23, fill=(30, 30, 34))
    for i, lab in enumerate(("Game", "History", "Settings")):
        cx = w / 2 - tb_w / 2 + tb_w * (i + 0.5) / 3
        if i == 0:
            s.rect(cx - 50, h - 66, 100, 38, 19, fill=(55, 55, 60))
        s.text(cx, h - 47, lab, "sb", 15, POS if i == 0 else GREY, "mm")
    s.rect(w / 2 - 160, h - 12, 320, 5, 2.5, fill=WHITE)


# ---------------------------------------------------------------- marketing frames
def device_frame(img, box, radius_px, screen_draw, logical):
    """Draws a rounded screen with a thin bezel; screen_draw(Screen) fills it."""
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(img)
    bez = int((x1 - x0) * 0.022)
    # shadow
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([x0 + 10, y0 + 30, x1 + 10, y1 + 30], radius_px, fill=(0, 0, 0, 110))
    from PIL import ImageFilter
    sh = sh.filter(ImageFilter.GaussianBlur(40 * SS))
    img.paste(sh, (0, 0), sh)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x0, y0, x1, y1], radius_px, fill=(28, 30, 36), outline=(70, 76, 90), width=3 * SS)
    sx0, sy0, sx1, sy1 = x0 + bez, y0 + bez, x1 - bez, y1 - bez
    u = (sx1 - sx0) / logical[0]
    scr = Image.new("RGB", (int(sx1 - sx0), int(sy1 - sy0)), BLACK)
    screen_draw(Screen(scr, 0, 0, u))
    mask = Image.new("L", scr.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, scr.size[0] - 1, scr.size[1] - 1], radius_px - bez, fill=255)
    img.paste(scr, (int(sx0), int(sy0)), mask)


def marketing(W, H, headline, sub, draw, logical, name, kind="phone"):
    img = Image.new("RGB", (W * SS, H * SS))
    vgrad(img, NAVY_T, NAVY_B)
    d = ImageDraw.Draw(img)
    k = W / 1320  # layout scale relative to the 6.9" design
    if kind == "pad":
        k = W / 2064 * 1.15
    if kind == "duo_inner":
        k = W / 2007 * 1.25
    if kind == "duo_outer":
        k = W / 1398 * 0.95
    def fit(kind, px):  # shrink to keep a margin either side
        while d.textlength(text_, font=font(kind, px * SS)) > W * SS * 0.88 and px > 10:
            px -= 1
        return font(kind, px * SS)
    text_ = headline
    d.text((W * SS / 2, 150 * k * SS), headline, font=fit("blk", 92 * k), fill=WHITE, anchor="mm")
    text_ = sub
    d.text((W * SS / 2, 262 * k * SS), sub, font=fit("m", 44 * k), fill=POWDER, anchor="mm")
    top = 350 * k
    avail_h = H - top - 40 * k
    ratio = logical[1] / logical[0]
    fw = min(W * (0.86 if kind == "pad" else 0.80), (avail_h) / ratio * 1.0)
    fh = fw * ratio
    fx0 = (W - fw) / 2
    fy0 = top + (avail_h - fh) / 2 + 10 * k
    rad = fw * {"phone": 0.13, "pad": 0.045, "duo_outer": 0.11, "duo_inner": 0.06}[kind]
    device_frame(img, [fx0 * SS, fy0 * SS, (fx0 + fw) * SS, (fy0 + fh) * SS], int(rad * SS), draw, logical)
    img = img.resize((W, H), Image.LANCZOS)
    img.save(os.path.join(OUT, name), optimize=True)
    return name


# ---------------------------------------------------------------- Apple Watch (raw screens)
def watch_scoring(s):
    w, h = 211, 257   # 422x514 at 2x – Ultra logical size
    s.rect(0, 0, w, h, 0, fill=BLACK)
    s.text(w - 12, 14, "9:41", "sb", 15, WHITE, "rm")
    half = GAME["t2_live"]
    y = 34
    vals = [(f"+{half[0]}", POS, False), (sgn(half[1]), NEG, False), (score(net(half)), POS, True)]
    tw = (w - 16 - 8) / 3
    for i, (v, c, boxed) in enumerate(vals):
        tx = 8 + i * (tw + 4)
        if boxed:
            s.rect(tx, y, tw, 26, 6, fill=(38, 38, 40))
        s.text(tx + tw / 2, y + 13, v, "rnd", 20, c, "mm")
    y += 32
    gap = 5
    rh1 = 112
    bw = (w - 16 - gap) / 2
    for i, (t, c) in enumerate((("+1", POS), ("−1", NEG))):
        bx = 8 + i * (bw + gap)
        s.rect(bx, y, bw, rh1, 14, fill=mix(c, BLACK, 0.16), outline=mix(c, BLACK, 0.55), width=1.2)
        s.text(bx + bw / 2, y + rh1 / 2, t, "rnd", 44, c, "mm")
    y += rh1 + gap
    rh2 = h - y - 10
    uw = 46
    s.rect(8, y, w - 16 - uw - gap, rh2, 14, fill=mix(WARN, BLACK, 0.16), outline=mix(WARN, BLACK, 0.55), width=1.2)
    s.text(8 + (w - 16 - uw - gap) / 2, y + rh2 / 2, "HR +5", "rnd", 26, WARN, "mm")
    ux = w - 8 - uw
    s.rect(ux, y, uw, rh2, 14, fill=(30, 30, 32), outline=(80, 80, 84), width=1.2)
    s.text(ux + uw / 2, y + rh2 / 2, "↩", "b", 20, WHITE, "mm")


def watch_clock(s):
    w, h = 211, 257
    # tinted page background like the app's containerBackground
    for yy in range(int(h * s.u)):
        t = yy / (h * s.u)
        c = mix(POS, BLACK, 0.30 * (1 - t) + 0.05)
        s.d.line([(0, yy), (w * s.u, yy)], fill=c)
    s.text(w - 12, 14, "9:41", "sb", 15, WHITE, "rm")
    t1, b1, half = GAME["t1"], GAME["b1"], GAME["t2_live"]
    A, H = net(t1) + net(half), net(b1)
    y = 34
    tw = (w - 16 - 4) / 2
    for i, (team, col, tot, bat) in enumerate((("Hawks", AWAY, A, True), ("Owls", HOME, H, False))):
        tx = 8 + i * (tw + 4)
        s.rect(tx, y, tw, 44, 8, fill=mix(col, BLACK, 0.45 if bat else 0.12), outline=col if bat else None, width=1.5)
        s.text(tx + tw / 2, y + 11, team, "sb", 11, WHITE, "mm")
        s.text(tx + tw / 2, y + 30, score(tot), "rnd", 22, WHITE, "mm")
    y += 52
    s.text(w / 2, y + 6, "Top 2", "b", 12, GREY, "mm")
    s.text(w / 2, y + 48, "2:47", "rnd", 58, POS, "mm")
    y += 86
    s.rect(14, y, w - 28, 6, 3, fill=(40, 60, 45))
    s.rect(14, y, (w - 28) * 0.443, 6, 3, fill=POS)
    y += 16
    s.rect(24, y, w - 48, 40, 20, fill=WARN)
    tw = s.width("Pause", "b", 17)
    gx = w / 2 - (tw + 19) / 2
    for k in (0, 1):
        s.rect(gx + k * 6.5, y + 13.5, 4, 13, 1.2, fill=BLACK)
    s.text(gx + 19, y + 20, "Pause", "b", 17, BLACK, "lm")


def make_watch(draw, name):
    img = Image.new("RGB", (422 * SS, 514 * SS), BLACK)
    draw(Screen(img, 0, 0, 2 * SS))
    img = img.resize((422, 514), Image.LANCZOS)
    img.save(os.path.join(OUT, name), optimize=True)
    return name


# ---------------------------------------------------------------- icon
def make_icon():
    im = Image.open(ICON_SRC).convert("RGB").resize((1024, 1024), Image.LANCZOS)
    im.save(os.path.join(OUT, "appstore_icon_1024x1024.png"), optimize=True)
    return "appstore_icon_1024x1024.png"


# ---------------------------------------------------------------- main
SHOTS = [
    ("1_scoring", "Three buttons. Every point.", "+1  ·  −1  ·  Home Run  –  live Plus / Minus / Total",
     lambda s: iphone_live(s, "running")),
    ("2_timeup", "Timed half innings.", "Clock stops at 0:00 – finish scoring, then start the next half",
     lambda s: iphone_live(s, "timeup")),
    ("3_result", "Every inning, tallied.", "Plus and minus per half · end-of-inning scores · winner",
     iphone_final),
]

if __name__ == "__main__":
    made = []
    for W, H, tag in ((1320, 2868, "iphone69"), (1242, 2688, "iphone65"),
                      (1206, 2622, "iphone63"), (1179, 2556, "iphone61"), (886, 1920, "iphone_preview")):
        for key, hl, sub, fn in SHOTS:
            made.append(marketing(W, H, hl, sub, fn, (IPH_W, IPH_H), f"{tag}_{key}_{W}x{H}.png"))
    # iPhone Duo – outer (folded) and inner (unfolded) screens, with the layouts the app uses there
    duo_sets = [
        ("duo_outer", 1398, 2034, DUO_OUT_W, DUO_OUT_H, "compact", "duo_outer"),
        ("duo_inner", 2007, 2853, DUO_IN_W, DUO_IN_H, "regular", "duo_inner"),
    ]
    for tag, W, H, lw, lh, mode, kind in duo_sets:
        shots = [
            ("1_scoring", SHOTS[0][1], SHOTS[0][2], lambda s, lw=lw, lh=lh, mode=mode: iphone_live(s, "running", lw, lh, mode)),
            ("2_timeup", SHOTS[1][1], SHOTS[1][2], lambda s, lw=lw, lh=lh, mode=mode: iphone_live(s, "timeup", lw, lh, mode)),
            ("3_result", SHOTS[2][1], SHOTS[2][2], lambda s, lw=lw, lh=lh: iphone_final(s, lw, lh)),
        ]
        for key, hl, sub_, fn in shots:
            made.append(marketing(W, H, hl, sub_, fn, (lw, lh), f"{tag}_{key}_{W}x{H}.png", kind=kind))
    made.append(marketing(2064, 2752, "Built for the scorer's table.", "Big clock · big buttons · live line score",
                          ipad_live, (IPAD_W, IPAD_H), "ipad13_1_scoring_2064x2752.png", kind="pad"))
    made.append(make_watch(watch_scoring, "watch_1_scoring_422x514.png"))
    made.append(make_watch(watch_clock, "watch_2_clock_422x514.png"))
    made.append(make_icon())
    for n in made:
        im = Image.open(os.path.join(OUT, n))
        print(f"{n:45s} {im.size[0]}x{im.size[1]} {im.mode}")

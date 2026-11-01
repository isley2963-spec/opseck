"""Generates the Zombie OS radioactive symbol + wordmark (PNG for Plymouth, SVG for web).

Run from the repo root:  python3 branding/make_logo.py
Needs Pillow and the Poppins Bold font (path below).
"""
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

GREEN = (155, 255, 58, 255)   # acid green accent
SS = 4                        # supersampling factor for smooth edges
FONT = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
OUT_PLYMOUTH = "profile-overlay/airootfs/usr/share/plymouth/themes/zombie-os/logo.png"


def sector(cx, cy, r_in, r_out, a0, a1, steps=60):
    pts = []
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        pts.append((cx + r_out * math.cos(a), cy - r_out * math.sin(a)))
    for i in range(steps, -1, -1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        pts.append((cx + r_in * math.cos(a), cy - r_in * math.sin(a)))
    return pts


def symbol(size):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = S / 2
    unit = S / 11.0  # ISO 361 proportions: centre disc r=1, blades 1.6..5
    d.ellipse([cx - unit, cy - unit, cx + unit, cy + unit], fill=GREEN)
    for centre in (90, 210, 330):
        d.polygon(sector(cx, cy, 1.6 * unit, 5 * unit, centre - 30, centre + 30), fill=GREEN)
    return img.resize((size, size), Image.LANCZOS)


# ---- Plymouth logo: glow + symbol + wordmark (text is baked into the PNG so
# the boot splash needs no fonts inside the initramfs) ----
W, H = 640, 640
canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
sym = symbol(360)
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
glow.paste(sym, ((W - 360) // 2, 40), sym)
glow = glow.filter(ImageFilter.GaussianBlur(22))
canvas = Image.alpha_composite(canvas, glow)
canvas.paste(sym, ((W - 360) // 2, 40), sym)

font = ImageFont.truetype(FONT, 72)
text = "ZOMBIE OS"
d = ImageDraw.Draw(canvas)
spacing = 10
total = sum(d.textlength(c, font=font) for c in text) + spacing * (len(text) - 1)
x = (W - total) / 2
for c in text:
    d.text((x, 470), c, font=font, fill=(232, 245, 224, 255))
    x += d.textlength(c, font=font) + spacing
canvas.save(OUT_PLYMOUTH)
symbol(512).save("branding/symbol.png")


# ---- SVG symbol ----
def arc_path(cx, cy, r_in, r_out, a0, a1):
    def p(r, a):
        a = math.radians(a)
        return cx + r * math.cos(a), cy - r * math.sin(a)
    x0, y0 = p(r_out, a0)
    x1, y1 = p(r_out, a1)
    x2, y2 = p(r_in, a1)
    x3, y3 = p(r_in, a0)
    return (f"M{x0:.2f},{y0:.2f} A{r_out},{r_out} 0 0 0 {x1:.2f},{y1:.2f} "
            f"L{x2:.2f},{y2:.2f} A{r_in},{r_in} 0 0 1 {x3:.2f},{y3:.2f} Z")


paths = "".join(f'<path d="{arc_path(110, 110, 17.6, 55, c - 30, c + 30)}"/>' for c in (90, 210, 330))
with open("branding/symbol.svg", "w") as f:
    f.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 220 220" fill="#9BFF3A">'
            '<circle cx="110" cy="110" r="11"/>' + paths + '</svg>\n')
print("logo assets written")


# ---- BIOS (syslinux) boot menu background, 800x600 ----
splash = Image.new("RGBA", (800, 600), (8, 12, 9, 255))
small = symbol(110)
splash.alpha_composite(small, (345, 24))
sd = ImageDraw.Draw(splash)
f2 = ImageFont.truetype(FONT, 30)
label = "ZOMBIE OS"
sp = 6
tot = sum(sd.textlength(c, font=f2) for c in label) + sp * (len(label) - 1)
sx = (800 - tot) / 2
for c in label:
    sd.text((sx, 142), c, font=f2, fill=(232, 245, 224, 255))
    sx += sd.textlength(c, font=f2) + sp
splash.convert("RGB").save("branding/syslinux-splash.png")
print("splash written")

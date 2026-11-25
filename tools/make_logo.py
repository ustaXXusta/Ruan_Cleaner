"""Ruan logo generator: same blocky 'blade' style, rebuilt as clean geometry."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 4  # supersampling for smooth edges

# ---- glyphs in units: cap height 100, blade legs drop to 111, width 77 ----
W, GAP = 77, 7.5
GLYPHS = {
    "R": dict(outer=[(0,0),(77,0),(77,42),(46,48.5),(46,51),(77,51),(77,100),(46,111),(46,62),(31,62),(31,100),(0,100)],
              holes=[[(31,23),(46,23),(46,39),(31,39)]]),
    "U": dict(outer=[(0,0),(31,0),(31,77),(46,77),(46,0),(77,0),(77,100),(0,100)], holes=[]),
    "A": dict(outer=[(0,0),(77,0),(77,100),(46,111),(46,62),(31,62),(31,100),(0,100)],
              holes=[[(31,23),(46,23),(46,39),(31,39)]]),
    "N": dict(outer=[(0,0),(77,0),(77,100),(46,111),(46,23),(31,23),(31,100),(0,100)], holes=[]),
}

def glyph_mask(text, scale, pad, shadow):
    """Return (face_mask, shadow_mask) as L images at supersampled size."""
    width_u = len(text) * W + (len(text) - 1) * GAP
    w = int(round((width_u + 2 * pad) * scale * SS))
    h = int(round((111 + shadow + 2 * pad) * scale * SS))
    face = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(face)
    for i, ch in enumerate(text):
        g = GLYPHS[ch]
        ox = pad + i * (W + GAP)
        tr = lambda pts: [((ox + x) * scale * SS, (pad + y) * scale * SS) for x, y in pts]
        d.polygon(tr(g["outer"]), fill=255)
        for hole in g["holes"]:
            d.polygon(tr(hole), fill=0)
    sh = Image.new("L", (w, h), 0)
    sh.paste(face, (0, int(round(shadow * scale * SS))))
    return face, sh

def colorize(mask, rgb):
    layer = Image.new("RGBA", mask.size, rgb + (0,))
    layer.putalpha(mask)
    return layer

def wordmark(path, face_rgb, shadow_rgb, height_px, shadow=3.5, glow=None):
    pad = 2 if glow is None else 10
    scale = height_px / (111 + shadow + 2 * pad)
    face, sh = glyph_mask("RUAN", scale, pad, shadow)
    out = Image.new("RGBA", face.size, (0, 0, 0, 0))
    if glow:
        g = colorize(face, glow[0]).filter(ImageFilter.GaussianBlur(glow[1] * scale * SS))
        a = np.array(g); a[..., 3] = (a[..., 3] * glow[2]).astype(np.uint8); out.alpha_composite(Image.fromarray(a))
    out.alpha_composite(colorize(sh, shadow_rgb))
    out.alpha_composite(colorize(face, face_rgb))
    out = out.resize((face.width // SS, face.height // SS), Image.LANCZOS)
    out.save(path)
    return out

RED = (242, 66, 89)        # FuturisticTheme.softRed #F24259
DEEP = (122, 20, 38)       # extrusion on dark backgrounds
INK = (20, 20, 22)         # extrusion on light backgrounds

def app_icon(path, size=1024):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # macOS icon grid: 824/1024 body, centred, continuous-ish corners
    inset, body = 100 * S // 1024, 824 * S // 1024
    radius = int(185 * S / 1024)
    body_mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(body_mask).rounded_rectangle([inset, inset, inset + body, inset + body], radius, fill=255)
    # soft drop shadow under the body
    shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sm = Image.new("L", (S, S), 0); sm.paste(body_mask, (0, int(12 * S / 1024)))
    shadow.putalpha(sm.filter(ImageFilter.GaussianBlur(14 * S / 1024)).point(lambda v: int(v * 0.45)))
    img.alpha_composite(shadow)
    # body: vertical dark gradient + faint red glow behind the letter
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32) / S
    top, bot = np.array([44, 44, 52]), np.array([16, 16, 20])
    rgb = top[None, None, :] * (1 - yy[..., None]) + bot[None, None, :] * yy[..., None]
    r = np.sqrt((xx - 0.5) ** 2 + (yy - 0.52) ** 2)
    glow = np.clip(1 - r / 0.42, 0, 1) ** 2 * 0.28
    rgb = rgb * (1 - glow[..., None]) + np.array(RED)[None, None, :] * glow[..., None]
    # subtle scanlines, a nod to the app's matrix look
    lines = ((np.arange(S)[:, None] // int(6 * S / 1024)) % 2 == 0).astype(np.float32) * 0.035
    rgb = rgb * (1 - lines[..., None])
    body_img = Image.fromarray(np.dstack([rgb.astype(np.uint8), np.array(body_mask)]), "RGBA")
    img.alpha_composite(body_img)
    # hairline rim
    rim = Image.new("L", (S, S), 0)
    ImageDraw.Draw(rim).rounded_rectangle([inset, inset, inset + body, inset + body], radius, outline=255, width=max(1, int(3 * S / 1024)))
    rim_layer = Image.new("RGBA", (S, S), (255, 255, 255, 0)); rim_layer.putalpha(rim.point(lambda v: int(v * 0.10)))
    img.alpha_composite(rim_layer)
    # the R
    shadow_u = 4.0
    scale = (560 * S / 1024) / (111 + shadow_u)
    face, sh = glyph_mask("R", scale / SS, 0, shadow_u)  # glyph_mask multiplies by SS itself
    gx = (S - face.width) // 2
    gy = (S - face.height) // 2 + int(6 * S / 1024)
    glow_l = colorize(face, RED).filter(ImageFilter.GaussianBlur(36 * S / 1024))
    a = np.array(glow_l); a[..., 3] = (a[..., 3] * 0.28).astype(np.uint8)
    for layer in (Image.fromarray(a), colorize(sh, DEEP), colorize(face, RED)):
        canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0)); canvas.alpha_composite(layer, (gx, gy)); img.alpha_composite(canvas)
    # top highlight on the face
    out = img.resize((size, size), Image.LANCZOS)
    out.save(path)
    return out

if __name__ == "__main__":
    import sys
    od = sys.argv[1]
    wordmark(f"{od}/ruan_wordmark.png", RED, DEEP, 360, glow=None)            # in-app (dark UI)
    wordmark(f"{od}/ruan_logo.png", RED, INK, 360)                            # README / light backgrounds
    icon = app_icon(f"{od}/AppIcon_1024.png")
    icon.resize((500, 500), Image.LANCZOS).save(f"{od}/R.png")
    icon.save(f"{od}/AppIcon.icns", sizes=[(16,16),(32,32),(64,64),(128,128),(256,256),(512,512),(1024,1024)])
    # previews
    wm = Image.open(f"{od}/ruan_wordmark.png"); lg = Image.open(f"{od}/ruan_logo.png")
    prev = Image.new("RGBA", (wm.width + 560, 980), (20, 20, 22, 255))
    prev.alpha_composite(wm, (40, 40))
    light = Image.new("RGBA", (lg.width + 40, lg.height + 40), (255, 255, 255, 255)); light.alpha_composite(lg, (20, 20)); prev.alpha_composite(light, (20, 460))
    prev.alpha_composite(icon.resize((480, 480), Image.LANCZOS), (wm.width + 60, 20))
    x = wm.width + 80
    for s_ in (128, 64, 32, 16):
        prev.alpha_composite(icon.resize((s_, s_), Image.LANCZOS), (x, 560)); x += s_ + 24
    prev.save(f"{od}/preview.png")
    print(wm.size)

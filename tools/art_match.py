#!/usr/bin/env python3
"""art_match.py: match new art to the Home stations' look (contrast + sepia).

The reference is the 6 `home_loc_*` station sprites, measured fresh on every
run, so if the stations change, the target changes with them. Every image is
judged the way the app shows it: composited over Color.AppTheme.cream.

For each image:
  1. Contrast: a tone curve moves its darkest lines (p2) and ink mid-tones
     (p25/p50/p75) onto the stations' values. Paper (L >= 88) is left alone.
  2. Sepia: desaturate, then tint each pixel with the stations' sepia (hue +
     chroma) at that same lightness. Lightness is kept, so no saturation boost.
  3. Alpha: cut-out art (lines with soft transparent edges, like the Home
     map) gets its alpha re-derived against cream so the on-screen colour is
     exact. Sprites and opaque art keep their alpha.

Usage:
  art_match.py FILE [FILE ...]       match files; outputs go to OUT_DIR
  art_match.py --inbox               process every image in INBOX (the watcher)
  art_match.py --report FILE         print contrast/sepia numbers only
  art_match.py --ref A.png,B.png FILE...   match to these images instead of the
                                     stations (e.g. a new character -> the kid cards)

Every matched file is then evaluated against the stations (see TOLERANCES).
PASS -> matched/, ready for /add-asset.  FAIL -> matched/failed/, with the
failing checks on its compare sheet and in match_log.txt.
"""
import sys, glob, shutil, subprocess, datetime, time
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
STATIONS = REPO / "ChefAcademy/Assets.xcassets/Backgrounds"
INBOX = Path.home() / "Dropbox/Mac/Desktop/Art Inbox"
OUT_DIR = INBOX / "matched"
ORIGINALS = INBOX / "originals"
LOG = INBOX / "match_log.txt"
CREAM = np.array([245, 240, 225.0])          # Color.AppTheme.cream #F5F0E1
PAPER_L = 88                                  # at/above this lightness = paper, not ink
CUTOUT_PARTIAL = 0.25                         # >25% soft-alpha pixels => cut-out art
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".webp"}
FAILED_DIR = OUT_DIR / "failed"
TOLERANCES = {
    "darkest": 2.0,          # |L| gap of the darkest lines (ink p2)
    "mid": 2.0,              # |L| gap of the ink mid-tones (p50)
    "sepia_band": 0.05,      # sepia (Lab chroma) per 10-L band, relative to the stations
    "hue": 3.0,              # degrees, median ink hue
    "reddish": 0.01,         # extra share of ink pixels with hue < 65 deg, beyond the stations' own
    "visible": 0.10,         # cut-out art: max DROP in visible pixels (darker contrast legitimately adds some)
}
MIN_BANDS = 3                # need sepia measured in at least this many bands

# ---------- colour maths (sRGB <-> CIE Lab, D65) ----------
_M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]])
_MI = np.array([[3.2406, -1.5372, -0.4986], [-0.9689, 1.8758, 0.0415], [0.0557, -0.2040, 1.0570]])
_W = np.array([0.95047, 1.0, 1.08883])

def lab(rgb):
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    f = (c @ _M.T) / _W
    f = np.where(f > 0.008856, np.cbrt(f), 7.787 * f + 16 / 116)
    return 116 * f[:, 1] - 16, 500 * (f[:, 0] - f[:, 1]), 200 * (f[:, 1] - f[:, 2])

def rgb(L, a, b):
    fy = (L + 16) / 116; fx = fy + a / 500; fz = fy - b / 200
    inv = lambda f: np.where(f ** 3 > 0.008856, f ** 3, (f - 16 / 116) / 7.787)
    c = np.clip(np.stack([inv(fx), inv(fy), inv(fz)], 1) * _W @ _MI.T, 0, 1)
    return np.where(c > 0.0031308, 1.055 * c ** (1 / 2.4) - 0.055, 12.92 * c) * 255

# ---------- measuring ----------
def load(path):
    im = Image.open(path).convert("RGBA")
    return im.size, np.asarray(im).reshape(-1, 4).astype(float)

def on_cream(x):
    """What the app shows: visible pixels composited over cream."""
    v = x[x[:, 3] > 20]; al = v[:, 3:4] / 255
    return v[:, :3] * al + CREAM * (1 - al)

def contrast_points(L):
    ink = L[L < PAPER_L]
    return np.percentile(ink, [2, 25, 50, 75]) if ink.size > 500 else None

def reference(files=None):
    """The look to match: the 6 Home stations, or the given reference images
    (--ref), e.g. the kid avatar cards when matching a new character."""
    if files is None:
        files = sorted(glob.glob(str(STATIONS / "home_loc_*.imageset/*.png")))
        if len(files) < 6:
            sys.exit(f"art_match: expected 6 station PNGs in {STATIONS}, found {len(files)}")
    L, a, b = lab(np.concatenate([on_cream(load(f)[1]) for f in files]))
    C, H = np.hypot(a, b), np.arctan2(b, a)
    grid = np.arange(0, 101, 2.5); cC, cH = [], []
    for g in grid:                            # station sepia per lightness band
        m = (L >= g - 2.5) & (L < g + 2.5)
        ok = m.sum() > 100
        cC.append(np.median(C[m]) if ok else np.nan)
        cH.append(np.arctan2(np.median(np.sin(H[m])), np.median(np.cos(H[m]))) if ok else np.nan)
    cC, cH = np.array(cC), np.array(cH); ok = ~np.isnan(cC)
    seen = np.concatenate([on_cream(load(f)[1]) for f in files])
    return {"grid": grid, "C": np.interp(grid, grid[ok], cC[ok]), "H": np.interp(grid, grid[ok], cH[ok]),
            "contrast": contrast_points(L), "bands": bands(seen), "hue": summary(seen)["hue"],
            "chroma": summary(seen)["chroma"], "reddish": reddish_share(seen)}

def summary(seen_rgb):
    L, a, b = lab(seen_rgb); C = np.hypot(a, b); h = np.degrees(np.arctan2(b, a))
    ink = (L < PAPER_L) & (C > 4)
    return {"contrast": contrast_points(L),
            "chroma": float(np.median(C[L < PAPER_L])) if (L < PAPER_L).any() else 0.0,
            "hue": float(np.median(h[ink])) if ink.any() else 0.0}

# ---------- matching ----------
def tone_curve(L, src, dst):
    """Piecewise-linear curve: src contrast points -> dst, paper and black pinned."""
    xs = np.concatenate([[0], src, [PAPER_L, 100]]); ys = np.concatenate([[0], dst, [PAPER_L, 100]])
    if np.any(np.diff(xs) <= 0) or np.any(np.diff(ys) <= 0):
        return L                              # degenerate art (almost no ink): leave contrast alone
    return np.interp(L, xs, ys)

def match(path, ref, src=None):
    """src: contrast points measured elsewhere (match_sequence.py pools them over
    every frame of an animation, so all frames get the same curve)."""
    size, x = load(path)
    vis = x[:, 3] > 0
    al = x[vis, 3:4] / 255
    soft = ((x[vis, 3] > 20) & (x[vis, 3] < 235)).mean() if vis.any() else 0
    cutout = soft > CUTOUT_PARTIAL
    # Work on the on-screen colour for cut-out art, the pixel's own colour otherwise.
    work = x[vis, :3] * al + CREAM * (1 - al) if cutout else x[vis, :3]
    L, _, _ = lab(work)
    # Measure what's actually seen: composited over cream, alpha > 20 (on_cream's
    # rule, which evaluate() also uses). rembg cut-outs keep a near-invisible,
    # near-black fringe that would otherwise pass for the darkest ink, and their
    # soft hair edges look lighter on cream than their raw colour says.
    if src is None:
        seen_L, _, _ = lab(x[vis, :3] * al + CREAM * (1 - al))
        src = contrast_points(seen_L[x[vis, 3] > 20])
    if src is not None:
        L = tone_curve(L, src, ref["contrast"])
    C = np.interp(L, ref["grid"], ref["C"]); H = np.interp(L, ref["grid"], ref["H"])
    target = rgb(L, C * np.cos(H), C * np.sin(H))
    if cutout:                                # colour-to-alpha against cream: exact on screen
        d = target - CREAM
        a = np.maximum(np.where(d < 0, -d / CREAM, d / (255 - CREAM)).max(1), 1e-6)[:, None]
        x[vis, :3] = np.clip(CREAM + d / a, 0, 255); x[vis, 3] = a[:, 0] * 255
    else:
        x[vis, :3] = target
    out = Image.fromarray(x.round().astype(np.uint8).reshape(size[1], size[0], 4))
    return out, cutout

# ---------- evaluation ----------
def bands(seen_rgb):
    """Median sepia (chroma) per 10-wide lightness band, bands with enough pixels only."""
    L, a, b = lab(seen_rgb); C = np.hypot(a, b); out = {}
    for lo in range(20, 90, 10):
        m = (L >= lo) & (L < lo + 10)
        if m.sum() > 500:
            out[lo] = float(np.median(C[m]))
    return out

def reddish_share(seen_rgb):
    L, a, b = lab(seen_rgb); C = np.hypot(a, b); h = np.degrees(np.arctan2(b, a))
    ink = (L < PAPER_L) & (C > 4)
    return float((h[ink] < 65).mean()) if ink.any() else 0.0

def evaluate(orig_x, out_img, ref, cutout):
    """Return [(check, passed, detail)] for a matched image vs the stations."""
    out_x = np.asarray(out_img).reshape(-1, 4).astype(float)
    seen = on_cream(out_x); s = summary(seen); T = TOLERANCES; res = []
    if s["contrast"] is None or ref["contrast"] is None:
        return [("contrast", False, "no ink found to measure")]
    gd = s["contrast"][0] - ref["contrast"][0]; gm = s["contrast"][2] - ref["contrast"][2]
    res.append(("darkest lines", abs(gd) <= T["darkest"], f"gap {gd:+.1f} (allowed +/-{T['darkest']:.0f})"))
    res.append(("mid-tones", abs(gm) <= T["mid"], f"gap {gm:+.1f} (allowed +/-{T['mid']:.0f})"))
    mine, theirs = bands(seen), ref["bands"]
    common = [k for k in mine if k in theirs]
    if len(common) < MIN_BANDS:
        res.append(("sepia per shade", False, f"only {len(common)} lightness bands to compare (need {MIN_BANDS})"))
    else:
        worst = max(common, key=lambda k: abs(mine[k] / theirs[k] - 1))
        dev = mine[worst] / theirs[worst] - 1
        res.append(("sepia per shade", abs(dev) <= T["sepia_band"],
                    f"worst band L{worst}-{worst+10}: {dev*100:+.1f}% (allowed +/-{T['sepia_band']*100:.0f}%)"))
    ref_hue = ref["hue"]; dh = (s["hue"] - ref_hue + 180) % 360 - 180
    res.append(("sepia hue", abs(dh) <= T["hue"], f"{s['hue']:.0f} vs {ref_hue:.0f} deg (allowed +/-{T['hue']:.0f})"))
    red, ref_red = reddish_share(seen), ref["reddish"]
    res.append(("no reddish cast", red <= ref_red + T["reddish"],
                f"{red*100:.1f}% reddish pixels vs stations {ref_red*100:.1f}%"))
    if cutout:
        before_vis = (orig_x[:, 3] > 20).sum(); after_vis = (out_x[:, 3] > 20).sum()
        dv = after_vis / max(before_vis, 1) - 1
        res.append(("transparency", dv >= -T["visible"], f"visible pixels {dv*100:+.1f}% (max drop {T['visible']*100:.0f}%)"))
    else:
        same = np.array_equal(orig_x[:, 3], out_x[:, 3])
        res.append(("transparency", same, "alpha unchanged" if same else "alpha changed"))
    return res

# ---------- report + preview ----------
def fmt(s, ref=None):
    c = s["contrast"]
    if c is None:
        return "no ink found"
    t = f"darkest L{c[0]:.0f}  mid-tones L{c[2]:.0f}  sepia {s['chroma']:.1f}  hue {s['hue']:.0f}"
    if ref is not None and ref["contrast"] is not None:
        t += f"   (gap vs stations: darkest {c[0]-ref['contrast'][0]:+.0f}, mid {c[2]-ref['contrast'][2]:+.0f})"
    return t

def sheet(before_path, after_img, lines, dest):
    def view(im):
        c = Image.new("RGBA", im.size, (*CREAM.astype(int), 255)); c.alpha_composite(im.convert("RGBA"))
        c = c.convert("RGB"); c.thumbnail((700, 900)); return c
    a, b = view(Image.open(before_path)), view(after_img)
    W = a.width + b.width + 30; H = max(a.height, b.height) + 40 + 18 * len(lines)
    s = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(s)
    color = lambda ln: (0, 120, 0) if ln.startswith("PASS") else (190, 0, 0) if ln.startswith("FAIL") else (0, 0, 0)
    d.text((10, 8), "BEFORE", fill="black"); d.text((a.width + 30, 8), "AFTER (station sepia + contrast)", fill="black")
    s.paste(a, (10, 30)); s.paste(b, (a.width + 20, 30))
    y = max(a.height, b.height) + 36
    for ln in lines:
        d.text((10, y), ln, fill=color(ln)); y += 18
    s.save(dest)

def process(path, ref, move_original=False):
    """Match one file, evaluate it, file it under matched/ (PASS) or matched/failed/ (FAIL)."""
    path = Path(path)
    out_img, cutout = match(path, ref)
    orig_x = load(path)[1]
    checks = evaluate(orig_x, out_img, ref, cutout)
    passed = all(ok for _, ok, _ in checks)
    dest = OUT_DIR if passed else FAILED_DIR
    dest.mkdir(parents=True, exist_ok=True)
    stem = path.stem
    out_png = dest / f"{stem}.png"
    out_img.save(out_png)
    before = summary(on_cream(orig_x))
    after = summary(on_cream(np.asarray(out_img).reshape(-1, 4).astype(float)))
    lines = [f"stations: {fmt({'contrast': ref['contrast'], 'chroma': ref['chroma'], 'hue': ref['hue']})}",
             f"before:   {fmt(before, ref)}",
             f"after:    {fmt(after, ref)}",
             f"mode: {'cut-out (alpha re-derived over cream)' if cutout else 'sprite / opaque (alpha kept)'}",
             f"{'PASS' if passed else 'FAIL'}: {sum(ok for _, ok, _ in checks)}/{len(checks)} checks"]
    lines += [f"{'PASS' if ok else 'FAIL'}  {name}: {detail}" for name, ok, detail in checks]
    sheet(path, out_img, lines, dest / f"{stem}_compare.png")
    if move_original:
        ORIGINALS.mkdir(parents=True, exist_ok=True)
        shutil.move(str(path), ORIGINALS / path.name)
    with open(LOG, "a") as f:
        f.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}  {path.name}\n" + "".join(f"    {l}\n" for l in lines))
    print(f"{path.name} -> {out_png}\n  " + "\n  ".join(lines))
    return passed

def notify(msg):
    subprocess.run(["osascript", "-e", f'display notification "{msg}" with title "Art Match"'], check=False)

def main(argv):
    if not argv:
        sys.exit(__doc__)
    ref_files = None
    if argv[0] == "--ref":                        # --ref a.png,b.png  match to these instead of the stations
        ref_files = argv[1].split(","); argv = argv[2:]
    ref = reference(ref_files)
    if argv[0] == "--report":
        for p in argv[1:]:
            print(f"{Path(p).name}: {fmt(summary(on_cream(load(p)[1])), ref)}")
        return
    if argv[0] == "--inbox":
        INBOX.mkdir(parents=True, exist_ok=True)
        files = sorted(p for p in INBOX.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXT)
        passed, failed = [], []
        for p in files:
            size = -1                              # wait until a download/copy has finished
            while p.exists() and p.stat().st_size != size:
                size = p.stat().st_size; time.sleep(1.5)
            if not p.exists():
                continue
            try:
                (passed if process(p, ref, move_original=True) else failed).append(p.name)
            except Exception as e:                 # one bad file must not stop the rest
                with open(LOG, "a") as f:
                    f.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}  ERROR {p.name}: {e}\n")
                failed.append(p.name)
        if passed or failed:
            msg = f"{len(passed)} passed" + (f", {len(failed)} FAILED (see matched/failed)" if failed else "")
            notify(msg + ". Run /add-asset in Claude to install.")
        return
    for p in argv:
        process(p, ref)

if __name__ == "__main__":
    main(sys.argv[1:])

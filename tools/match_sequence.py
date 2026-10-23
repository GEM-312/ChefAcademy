#!/usr/bin/env python3
"""match_sequence.py: match a character's animation frames to a reference look, as one.

art_match.py matches one picture at a time. For an animation that flickers:
each frame has different content (an apron appearing adds light area), so a
per-frame tone curve makes the hair pulse lighter and darker. This tool takes
one or more sequences of the SAME character (e.g. "puts on apron" + "puts on
hat", which play one after the other in the same spot in the app) and:
  1. pools the contrast measurement over ALL their frames -> one tone curve,
  2. applies that same curve + sepia to every frame (art_match.match),
  3. crops every frame to ONE shared box (the union of all frames), so the
     character doesn't jump or rescale between frames or between sequences,
  4. optionally scales everything so the first frame's figure is exactly as
     tall as the character's static card (--card), so card -> animation
     doesn't jump either,
  5. evaluates the pooled result against the reference (art_match.evaluate).

Usage:
  match_sequence.py --ref A.png,B.png --out DIR [--card CARD.png] \
      --seq mom_apron_frame DIR1 [--seq mom_wear_hat_frame DIR2 ...]
Each DIR's *.png (sorted) is one sequence; writes DIR/<name>_01.png ... per
sequence, plus DIR/_sequence_report.txt.
"""
import sys, argparse
from pathlib import Path
import numpy as np
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parent))
import art_match as am

ALPHA_THRESHOLD = 16    # same as extract-and-trim.sh: ignore rembg's faint fringe when finding edges

def bbox(img):
    return img.split()[3].point(lambda v: 255 if v >= ALPHA_THRESHOLD else 0).getbbox()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", required=True, help="comma-separated reference images")
    ap.add_argument("--out", required=True)
    ap.add_argument("--card", help="static card of this character: frame 1's figure is scaled to its height")
    ap.add_argument("--seq", nargs=2, action="append", required=True, metavar=("NAME", "DIR"))
    a = ap.parse_args()
    ref = am.reference(a.ref.split(","))
    out_dir = Path(a.out); out_dir.mkdir(parents=True, exist_ok=True)
    seqs = [(name, sorted(Path(d).glob("*.png"))) for name, d in a.seq]
    every = [p for _, files in seqs for p in files]

    # 1. one contrast measurement for every frame, on what's seen over cream
    seen = []
    for p in every:
        _, x = am.load(p); vis = x[:, 3] > 0; al = x[vis, 3:4] / 255
        L, _, _ = am.lab(x[vis, :3] * al + am.CREAM * (1 - al))
        seen.append(L[x[vis, 3] > 20])
    src = am.contrast_points(np.concatenate(seen))

    # 2. same curve on every frame
    matched = {p: am.match(p, ref, src=src)[0] for p in every}

    # 3. one shared crop box across all sequences
    boxes = [bbox(m) for m in matched.values()]
    box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))

    # 4. one shared scale: frame 1's figure = the card's height
    scale = 1.0
    if a.card:
        f1 = bbox(matched[seqs[0][1][0]])
        scale = Image.open(a.card).height / (f1[3] - f1[1])
    size = (round((box[2] - box[0]) * scale), round((box[3] - box[1]) * scale))
    for name, files in seqs:
        for i, p in enumerate(files, 1):
            matched[p].crop(box).resize(size, Image.LANCZOS).save(out_dir / f"{name}_{i:02d}.png", optimize=True)

    # 5. evaluate all frames pooled (match never changes alpha)
    pooled = np.concatenate([np.asarray(m).reshape(-1, 4).astype(float) for m in matched.values()])
    w = next(iter(matched.values())).width
    pooled_img = Image.fromarray(pooled.astype(np.uint8).reshape(-1, w, 4))
    checks = am.evaluate(pooled, pooled_img, ref, cutout=False)
    lines = [", ".join(f"{name}: {len(files)} frames" for name, files in seqs),
             f"shared box {size[0]}x{size[1]} (scale {scale:.3f})",
             f"reference: {am.fmt({'contrast': ref['contrast'], 'chroma': ref['chroma'], 'hue': ref['hue']})}",
             f"result:    {am.fmt(am.summary(am.on_cream(pooled)), ref)}"]
    lines += [f"{'PASS' if ok else 'FAIL'}  {n}: {d}" for n, ok, d in checks]
    (out_dir / "_sequence_report.txt").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    sys.exit(0 if all(ok for _, ok, _ in checks) else 1)

if __name__ == "__main__":
    main()

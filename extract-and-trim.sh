#!/bin/bash
#
# extract-and-trim.sh — Full headless pipeline: video → trimmed PNG frames
#
# Pipeline per video:
#   1. ffmpeg                              → originals/
#   2. rembg (u2net_human_seg)             → cleaned/   (alpha cutout)
#   3. PIL .getbbox() → crop + save        → trimmed/   (transparent pixels removed)
#
# Replaces the manual Photoshop trip for character-frame batches. Quality
# is near-Photoshop for clean character art (kid sprites, chef poses);
# tricky edges (hair wisps, transparent fabric) may need a Photoshop touch-up
# pass — in which case `cleaned/` is the right starting point.
#
# Usage:  ./extract-and-trim.sh <video> [num_frames]
#   ./extract-and-trim.sh ~/Downloads/MomAvatar.mp4
#   ./extract-and-trim.sh ~/Downloads/MomAvatar.mp4 15
#
# Multi-video:  ./extract-and-trim.sh vid1.mp4 vid2.mp4 ...   (default 15 frames each)
#
# Output:  ~/Desktop/AssetTrim/<videoName>/{originals,cleaned,trimmed}/
#

set -e

# rembg model — u2net_human_seg is tuned for people/characters and gives
# noticeably cleaner edges on kid sprites than the default u2net.
REMBG_MODEL="${REMBG_MODEL:-u2net_human_seg}"

process_one() {
    local VIDEO="$1"
    local NUM_FRAMES="${2:-15}"

    if [ ! -f "$VIDEO" ]; then
        echo "✗ Skipping (not found): $VIDEO"
        return 1
    fi

    local BASENAME
    BASENAME=$(basename "$VIDEO" | sed 's/\.[^.]*$//' | sed 's/[^a-zA-Z0-9_]/_/g' | cut -c1-40)
    local OUTPUT=~/Desktop/AssetTrim/$BASENAME

    mkdir -p "$OUTPUT/originals" "$OUTPUT/cleaned" "$OUTPUT/trimmed"

    local DURATION
    DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO" 2>/dev/null)
    if [ -z "$DURATION" ]; then
        echo "✗ Could not read video: $VIDEO"
        return 1
    fi

    local FPS
    FPS=$(echo "scale=4; $NUM_FRAMES / $DURATION" | bc)

    echo ""
    echo "═════════════════════════════════════════════════════════════"
    echo "▶ $(basename "$VIDEO")   (${DURATION}s, $NUM_FRAMES frames)"
    echo "═════════════════════════════════════════════════════════════"

    # Step 1 — extract frames
    echo "  [1/3] Extracting frames..."
    ffmpeg -i "$VIDEO" -vf "fps=$FPS" -frames:v "$NUM_FRAMES" \
        "$OUTPUT/originals/${BASENAME}_%02d.png" -y -loglevel error
    local COUNT
    COUNT=$(ls "$OUTPUT/originals/"*.png 2>/dev/null | wc -l | tr -d ' ')
    echo "        ✓ $COUNT frames → originals/"

    # Step 2 — remove backgrounds with rembg
    echo "  [2/3] Removing backgrounds (model: $REMBG_MODEL)..."
    local i=1
    for src in "$OUTPUT/originals/"*.png; do
        local name
        name=$(basename "$src")
        rembg i -m "$REMBG_MODEL" "$src" "$OUTPUT/cleaned/$name" 2>/dev/null
        printf "        %d/%d  %s\r" "$i" "$COUNT" "$name"
        i=$((i + 1))
    done
    echo "        ✓ $COUNT frames → cleaned/                "

    # Step 3 — trim transparent pixels (PIL with alpha threshold)
    echo "  [3/3] Trimming transparent pixels..."
    python3 - "$OUTPUT/cleaned" "$OUTPUT/trimmed" <<'PY'
import sys
from pathlib import Path
from PIL import Image

src_dir = Path(sys.argv[1])
dst_dir = Path(sys.argv[2])

# rembg leaves subtle alpha-fringe pixels (alpha 1–15) in areas that visually
# look transparent. PIL's default getbbox() counts ANY non-zero alpha as
# in-bounds, so the resulting crop covers the full source canvas. Threshold
# the alpha channel before computing the bbox, then crop the ORIGINAL image
# (so we preserve genuine edge anti-aliasing in the saved output).
ALPHA_THRESHOLD = 16

count = 0
for src in sorted(src_dir.glob("*.png")):
    img = Image.open(src).convert("RGBA")
    alpha = img.split()[3]
    # Map any alpha >= threshold to 255, below to 0 — pure binary mask
    mask = alpha.point(lambda a: 255 if a >= ALPHA_THRESHOLD else 0)
    bbox = mask.getbbox()
    if bbox:
        img.crop(bbox).save(dst_dir / src.name)
    else:
        # Fully transparent — copy as-is so frame count stays stable
        img.save(dst_dir / src.name)
    count += 1

print(f"        ✓ {count} frames → trimmed/")
PY

    echo ""
    echo "  Ready at:  ~/Desktop/AssetTrim/$BASENAME/"
    echo "             originals/  cleaned/  trimmed/"
}

# Entry point — accept one or more videos
if [ $# -lt 1 ]; then
    echo "Usage: ./extract-and-trim.sh <video> [num_frames]"
    echo "       ./extract-and-trim.sh vid1.mp4 vid2.mp4 ...    (default 15 each)"
    echo ""
    echo "Env vars:"
    echo "  REMBG_MODEL=...   override default 'u2net_human_seg'"
    echo "                    options: u2net, u2net_human_seg, isnet-general-use,"
    echo "                             birefnet-portrait (highest quality, slowest)"
    exit 1
fi

# Detect: single video + numeric arg = (video, num_frames) pair
#         multiple paths = batch mode with default 15 frames each
if [ $# -eq 2 ] && [[ "$2" =~ ^[0-9]+$ ]]; then
    process_one "$1" "$2"
else
    for v in "$@"; do
        process_one "$v" 15
    done
fi

echo ""
echo "✓ Pipeline complete."

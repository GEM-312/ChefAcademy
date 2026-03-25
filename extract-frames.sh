#!/bin/bash
#
# extract-frames.sh — Extract frames from a video for sprite animations
#
# Usage: ./extract-frames.sh <video_file> [num_frames]
#
# Creates 3 folders on Desktop:
#   AssetTrim/<name>/originals/  ← raw extracted frames
#   AssetTrim/<name>/cleaned/    ← remove background here
#   AssetTrim/<name>/trimmed/    ← trim transparent pixels here
#
# Examples:
#   ./extract-frames.sh stove_burning.mp4
#   ./extract-frames.sh stove_burning.mp4 15
#   ./extract-frames.sh ~/Downloads/pip_watering.mp4 10
#

VIDEO="$1"
NUM_FRAMES="${2:-15}"

if [ -z "$VIDEO" ] || [ ! -f "$VIDEO" ]; then
    echo "Usage: ./extract-frames.sh <video_file> [num_frames]"
    echo "  Default: 15 frames"
    exit 1
fi

# Get clean name from video filename
BASENAME=$(basename "$VIDEO" | sed 's/\.[^.]*$//' | sed 's/[^a-zA-Z0-9_]/_/g' | cut -c1-40)
OUTPUT=~/Desktop/AssetTrim/$BASENAME

# Create 3 folders
mkdir -p "$OUTPUT/originals" "$OUTPUT/cleaned" "$OUTPUT/trimmed"

# Get video duration
DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO" 2>/dev/null)
if [ -z "$DURATION" ]; then
    echo "Error: Could not read video. Is ffmpeg installed?"
    exit 1
fi

# Calculate FPS for even spacing
FPS=$(echo "scale=4; $NUM_FRAMES / $DURATION" | bc)

echo "Video:    $(basename "$VIDEO")"
echo "Duration: ${DURATION}s"
echo "Frames:   $NUM_FRAMES"
echo ""

# Extract frames
ffmpeg -i "$VIDEO" -vf "fps=$FPS" -frames:v "$NUM_FRAMES" "$OUTPUT/originals/${BASENAME}_%02d.png" -y -loglevel error

COUNT=$(ls "$OUTPUT/originals/"*.png 2>/dev/null | wc -l | tr -d ' ')
echo "✓ Extracted $COUNT frames"
echo ""
echo "Folders ready at: ~/Desktop/AssetTrim/$BASENAME/"
echo "  originals/  ← $COUNT raw frames"
echo "  cleaned/    ← remove background here (Photoshop)"
echo "  trimmed/    ← trim transparent pixels here (Photoshop)"
echo ""
ls "$OUTPUT/originals/"

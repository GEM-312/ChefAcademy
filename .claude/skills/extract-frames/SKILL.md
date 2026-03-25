---
name: extract-frames
description: Extract frames from a video file for sprite animations. Creates originals/cleaned/trimmed folders on Desktop.
user-invocable: true
---

# Extract Frames from Video

The user wants to extract frames from a video for use as sprite animation assets.

## Instructions

1. Parse the user's message for: `<video_path>` and optional `[num_frames]` (default 15)
2. Run the extract script: `bash /Users/pollakmarina/Dropbox/Mac/Desktop/ChefAcademy/extract-frames.sh "<video_path>" <num_frames>`
3. Report what was extracted and remind the user of the workflow:
   - `originals/` — raw extracted frames
   - `cleaned/` — remove background here (Photoshop)
   - `trimmed/` — trim transparent pixels here (Photoshop)
4. When user says "trimmed is ready" or "cleaned is ready", copy the files into the Xcode asset catalog

If the video path doesn't exist, check common locations: project root, ~/Desktop, ~/Downloads.

#!/usr/bin/env python3
"""Generate authentic six Rocket gallery icons from the bundled VAP videos.

This script reads actual VAP reward clips, extracts a frame, and recombines the
colour and alpha regions when the VAP configuration supplies their coordinates.
It never substitutes cartoon emoji, unrelated gifts or fabricated art.
The resulting artwork is solely used for level selection previews.
"""
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
MEDIA = ROOT / "nimzo/assets/room_rocket"
OUTPUT = MEDIA / "posters"


def mp4_config(media: Path):
    source = media.read_bytes()
    start = source.find(b"vapc")
    if start < 0:
        return None
    block = source[start + 4 : start + 200_000]
    brace = block.find(b"{")
    if brace < 0:
        return None
    try:
        obj, _ = json.JSONDecoder().raw_decode(
            block[brace:].decode("utf-8", "ignore")
        )
        return obj
    except (ValueError, UnicodeDecodeError):
        return None


def find_frame(value, names):
    if isinstance(value, dict):
        for name in names:
            rect = value.get(name)
            if isinstance(rect, dict):
                keys = ("x", "y", "w", "h")
                if all(key in rect for key in keys):
                    return tuple(int(rect[key]) for key in keys)
        for nested in value.values():
            found = find_frame(nested, names)
            if found:
                return found
    if isinstance(value, list):
        for nested in value:
            found = find_frame(nested, names)
            if found:
                return found
    return None


def take_frame(video, seconds, output):
    subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-y", "-ss", str(seconds),
         "-i", str(video), "-frames:v", "1", str(output)],
        check=True,
    )


def poster(level):
    video = MEDIA / f"vap_rocket_reward_{level}.mp4"
    if not video.is_file():
        raise RuntimeError(f"Missing original level {level} video")
    config = mp4_config(video)
    with tempfile.TemporaryDirectory() as tmp:
        frame = Path(tmp) / "frame.png"
        take_frame(video, 3.0, frame)
        with Image.open(frame) as source:
            image = source.convert("RGB")
    w, h = image.size
    color_rect = find_frame(config, ("rgbFrame", "rgb", "rgbRect")) if config else None
    mask_rect = find_frame(config, ("aFrame", "alphaFrame", "alpha", "alphaRect")) if config else None
    def valid(rect):
        if not rect:
            return False
        x, y, rw, rh = rect
        return rw > 0 and rh > 0 and x >= 0 and y >= 0 and x + rw <= w and y + rh <= h
    if valid(color_rect):
        x, y, rw, rh = color_rect
        rocket = image.crop((x, y, x + rw, y + rh)).convert("RGBA")
    else:
        # Tencent's common v1 arrangement: alpha left, RGB right.
        # VAP v2 coordinates are always preferred if declared.
        rocket = image.crop((w // 2, 0, w, h)).convert("RGBA")
    if valid(mask_rect):
        x, y, rw, rh = mask_rect
        alpha = image.crop((x, y, x + rw, y + rh)).convert("L")
        rocket.putalpha(alpha.resize(rocket.size, Image.Resampling.BILINEAR))
        bbox = rocket.getchannel("A").point(
            lambda px: 255 if px > 38 else 0).getbbox()
        if bbox:
            rocket = rocket.crop(bbox)
    # Maintain full original frame if metadata was not available; the still is
    # authentic source pixels, never a different rocket.
    if rocket.width < 50 or rocket.height < 50:
        raise RuntimeError(f"Video {level}: extracted frame too small")
    bg = Image.new("RGBA", (480, 480), "#0b1a2e")
    draw = ImageDraw.Draw(bg)
    draw.ellipse((22, 22, 458, 458), outline="#295f74", width=3)
    draw.ellipse((75, 75, 405, 405), fill="#123550")
    rocket.thumbnail((400, 400), Image.Resampling.LANCZOS)
    bg.alpha_composite(rocket, ((480 - rocket.width) // 2,
                                 (480 - rocket.height) // 2))
    target = OUTPUT / f"rocket_stage_{level}.png"
    bg.convert("RGB").save(target, "PNG", optimize=True)
    if target.stat().st_size < 8_000:
        raise RuntimeError(f"Poster {level} unexpectedly small")
    print(f"Level {level} authentic video poster: {target.stat().st_size} bytes")


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for stage in range(1, 7):
        poster(stage)


if __name__ == "__main__":
    main()

# ffmpeg is provisioned by the dedicated poster workflow.

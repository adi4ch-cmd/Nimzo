#!/usr/bin/env python3
"""Extract clean six-level Rocket stills from the original VAP fly animations.

VAP videos contain a full-size RGB frame and a half-resolution grayscale alpha
frame packed side-by-side. Never save these uncomposited source video frames.
"""
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
MEDIA = ROOT / "nimzo/assets/room_rocket"
OUTPUT = MEDIA / "posters"


def config(video: bytes) -> dict:
    pos = video.find(b"vapc")
    if pos < 0:
        raise ValueError("Missing original VAP metadata")
    data, _ = json.JSONDecoder().raw_decode(
        video[pos + 4:].decode("utf-8", "ignore")
    )
    info = data["info"]
    for name in ("rgbFrame", "aFrame"):
        rect = info.get(name)
        if not isinstance(rect, list) or len(rect) != 4:
            raise ValueError("Missing expected VAP frame coordinates")
    return info


def frame_from_video(src: Path, at: float) -> Image.Image:
    with tempfile.TemporaryDirectory() as tmp:
        output = Path(tmp) / "frame.png"
        subprocess.run(
            ["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-ss",
             str(at), "-i", str(src), "-frames:v", "1", str(output)],
            check=True,
        )
        return Image.open(output).convert("RGB")


def rect_crop(frame: Image.Image, coords: list[int]) -> Image.Image:
    x, y, w, h = coords
    if w <= 0 or h <= 0 or x < 0 or y < 0 or x + w > frame.width or y + h > frame.height:
        raise ValueError("Out-of-bounds packed VAP frame")
    return frame.crop((x, y, x + w, y + h))


def create_poster(stage: int) -> Path:
    original = MEDIA / f"vap_rocket_fly_{stage}.mp4"
    if not original.is_file():
        raise FileNotFoundError(original)
    info = config(original.read_bytes())
    packed = frame_from_video(original, 0.65)
    rocket = rect_crop(packed, info["rgbFrame"]).convert("RGBA")
    grayscale_alpha = rect_crop(packed, info["aFrame"]).convert("L")
    alpha = grayscale_alpha.resize(rocket.size, Image.Resampling.BILINEAR)
    rocket.putalpha(alpha)
    bounds = alpha.point(lambda px: 255 if px >= 36 else 0).getbbox()
    if bounds is None:
        raise ValueError(f"Blank Rocket frame for level {stage}")
    rocket = rocket.crop(bounds)
    rocket.thumbnail((410, 430), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (480, 480), "#0b1930")
    glow = Image.new("RGBA", (480, 480), (0, 0, 0, 0))
    pen = ImageDraw.Draw(glow)
    pen.ellipse((32, 62, 448, 448), fill=(39, 102, 146, 65))
    canvas = Image.alpha_composite(canvas, glow.filter(ImageFilter.GaussianBlur(25)))
    canvas.alpha_composite(
        rocket, ((480 - rocket.width) // 2, (480 - rocket.height) // 2)
    )
    result = OUTPUT / f"rocket_stage_{stage}.png"
    canvas.convert("RGB").save(result, optimize=True)
    if result.stat().st_size < 20_000:
        raise ValueError(f"Rocket thumbnail {stage} suspiciously small")
    print(f"Rocket stage {stage}: original fly clip composited: {result.stat().st_size} bytes")
    return result


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for level in range(1, 7):
        create_poster(level)


if __name__ == "__main__":
    main()

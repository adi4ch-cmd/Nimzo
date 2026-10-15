# Four free licensed car review renders

These are actual Blender/Cycles renders of a detailed CC-BY model. They are **review work**, not an approved six-gift release. No final lion/tiger assets, native Android alpha certification or final APK are included.

## Reproduce

Use Blender 4.3.2, Python 3 with Pillow/numpy, and FFmpeg with libx264/FFV1. Run from the repository root:

```sh
python3 tools/realistic_gifts/fetch_assets.py render-assets
blender --python-exit-code 1 -b -t 4 -P tools/realistic_gifts/car_scene.py -- --model render-assets/CarConcept.glb --hdri render-assets/studio_small_09_1k.exr --out rendered-red --color red --width 360 --samples 8 --denoise
python3 tools/realistic_gifts/encode.py rendered-red
python3 tools/realistic_gifts/verify.py rendered-red
python3 tools/realistic_gifts/room_preview.py rendered-red
```

Repeat with `--color black`, `gold`, or `blue` and a separate output directory. The saved `.blend` includes packed lighting/textures, authored model geometry and animated wheel/steering/path/camera controls. Keep ATTRIBUTION.md alongside source and rendered handoffs. Logos on excluded surfaces are removed before packing. For higher-quality render candidates, use `--width 1080 --samples 128 --denoise`; this is an instruction, not a claim that a 1080p master has been rendered.

The dispatchable `nimzo-free-car-previews.yml` workflow renders each color's 240 frames in four chunks and verifies the encoded media. It does not build an APK. Artifacts expire after three days; archive accepted source and media before expiry.

## Outputs and limits

- `rgba/frame_0001.png`–`frame_0240.png`: genuine RGBA render sequence, transparent endpoints.
- `preview.mp4`: ordinary H.264 review video on an explicit neutral background, 8 seconds/30 fps.
- `rgba_master.mkv`: lossless FFV1/BGRA alpha master; not a mobile playback format.
- `alpha_vap.mp4`: H.264 alpha-left/color-right stream with appended VAP-v2 `vapc` metadata. CPU-decoded mask/color checks do not verify Android compositing. Use the VAP renderer, never the ordinary opaque video overlay.
- `poster.png`, `thumbnail.webp`: transparent render-derived artwork.
- `room_light.mp4`, `room_dark_derived.mp4`: decoded VAP motion composited over a checked-in room screenshot and a derived dark stress background. These are desktop review composites, not Android recordings.
- `verification.json`: exact file hashes, stream/frame evidence and explicit pending device/Vivox checks.

Run the real encoder/decoder regression check with:

```sh
python3 -m unittest discover -s tools/realistic_gifts/tests -v
```

The regression uses moving synthetic test pixels only to test encoding, never as gift artwork. Every actual gift preview must originate from the model render sequence. App mappings remain inactive until visual acceptance, real Android alpha/voice tests and server-event integration checks pass. The pre-existing catalog, prices, accounts and transaction records are unchanged.

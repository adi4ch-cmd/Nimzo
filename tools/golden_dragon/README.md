# Golden Dragon — original 3D motion study

**Review candidate. NOT a production-complete premium gift.**

This source creates and renders real 3D geometry in Blender 4.3.2. It does not use an AI image, billboard, downloaded app animation, SVG or Flutter transforms. Its current sculpt/anatomy, shading, choreography and sampling need further art work to reach the user's premium cinematic reference. Do not enable it for paid gifts merely because encoding tests pass.

## Reproduce

Use the official Blender 4.3.2 Linux build (system Debian Blender lacks OpenImageDenoise). Official archive SHA-256: `4da1c956673c0485e63054e563ee69198cc8f80d8157dd7592dffc8a6a5592e6`.

```sh
python3 -m pip install -r tools/golden_dragon/requirements.txt
python3 -m unittest discover -s tools/golden_dragon/tests -v
blender -b -t 3 -P tools/golden_dragon/scene.py -- --out rendered-dragon --width 540 --samples 16
python3 tools/golden_dragon/pack.py rendered-dragon
python3 tools/golden_dragon/verify.py rendered-dragon
python3 tools/golden_dragon/room_preview.py rendered-dragon
```

For a higher-resolution art pass: use `--width 1080 --samples 128 --denoise`. This is a runnable setting, **not an already rendered 1080p master**. Denoising was slow on the available CPU. A diagnostic still uses `--frame 240`; `--build-only` saves a `.blend` without rendering. The saved `.blend` has no external dependencies and can render through Blender's normal animation command.

The render-only Actions workflow is `.github/workflows/nimzo-golden-dragon-render.yml`. It verifies the Blender download checksum, renders every frame, runs real FFmpeg encoding and uploads artifacts. It never builds an APK or writes to Supabase.

## Outputs

- `rgba/frame_0001.png`…`frame_0360.png`: full RGBA PNG sequence, film transparency, 12 seconds at 30 fps. Entry/exit fades multiply the completed premultiplied render in Blender’s compositor, preserving all edges without accumulating material-opacity bounces.
- `golden_dragon.blend`: geometry, materials, lighting, camera and keyframes.
- `golden_dragon_demo.mp4`: opaque neutral-background H.264 review video, deliberately **not** advertised as alpha.
- `golden_dragon_rgba.mkv`: lossless FFV1 BGRA review master, not an Android playback format.
- `golden_dragon_vap_candidate.mp4`: H.264 packed color+alpha with a real `vapc` v2 MP4 box. Requires the native VAP compositor; ordinary `video_player` shows two panels.
- `golden_dragon_poster.png`, `golden_dragon_thumbnail.webp`: alpha stills from frame 240 of the actual sequence; review assets, not activated catalog art.
- `golden_dragon_room_light.mp4`, `golden_dragon_room_dark_derived.mp4`: actual decoded VAP motion composited over screenshot backgrounds for desktop review; not Android recordings.
- `alpha_*`, `room_alpha_*`: CPU compositing checks using decoded VAP data. The light room background is the repository's existing room golden. The dark room background is a derived contrast stress test, not a real device screenshot.
- `verification.json`: actual stream counts, codec, dimensions, checksums, exact decoded RGBA comparison of all 360 FFV1 frames, alpha mask error and explicit device-verification flags.

## VAP layout and compatibility

Read `pack.py`, its real encode/decode test, and the player's actual API rather than playing the candidate with `video_player`. For 540×960 display, packed video is 1088×960. The full-resolution alpha rectangle is `[0,0,540,960]`; straight RGB is `[544,0,540,960]`. Four-pixel padding protects the panel boundary; dimensions are 16-aligned. The 540 export uses H.264 level 4.1; a 1080 export requires level 5.1 and a 2176×1920 packed decoder surface, so it especially requires device capability checks. The appended `vapc` box preserves existing MP4 chunk offsets. No chroma keying occurs.

Inspected packages: `flutter_vap_player` 2.1.1 and `vap_player_android` 2.1.1, using Tencent VAP 2.0.28. `VapPlayerController.asset` accepts `VapPlayerOptions(viewType: VapViewType.textureView, scaleType: VapScaleType.fitCenter, repeatCount: 0, mute: true)`. Initialize before play; handle `VapErrorEvent` and `VapCompletedEvent`, watchdog, cancellation and disposal. Native `ProducerRender` clears to transparent, uses the alpha/RGB rectangles, and `SurfaceEglHelper` requests 8 alpha bits.

These are source inspection and CPU file checks. **Android decoding, premultiplication at the Flutter surface boundary, frame pacing, thermals and Vivox microphone/audio coexistence have not been verified on devices.** No attached Android device was available. VAP readiness is not established by the existing room rocket call site.

## Production integration gate

Existing Golden Dragon UUID: `c3f41e6e-68d5-4e56-9253-33421ec18fc3`. A read-only production query on 2026-10-15 found active=true, server price 5,000,000, SVG artwork and no approved animation-media row. Never copy that observed price into a client pricing override.

Existing paths remain in `gift_repository.dart`, `verified_gift_broadcast.dart` and `gift_celebration_overlay.dart`; they still use the existing opaque MP4 fallback. **This change deliberately does not activate the candidate or change Flutter production routing.** Quality and native playback gates are unmet. An approved HTTPS MP4 is not enough to distinguish VAP from opaque video; do not put this candidate into `gift_animation_media.video_url` until a format-aware playback integration exists and is tested.

Before activation: approved high-quality art; inspect all motion; render sufficient samples/master; verify dark/light edges on two Android phones; verify MediaCodec/VAP completion/error/skip/background cleanup and Vivox; add format-aware UUID media routing with the existing opaque fallback; run widget queue/idempotency/recipient/quantity tests and real authenticated send/receive checks. Storage/CDN publishing must use a real approved location and documented hashes. Preserve server settlement, event deduplication, prices and every ledger entry. Do not trigger an intermediate APK.

## Provenance

All creature geometry, scale meshes, materials, lighting and motion in `scene.py` were generated for this task. No external model or texture is used; no third-party model attribution is needed for these files. No claim is made about the redistribution rights of earlier repository MP4s. Those files are retained unchanged.

Potential third-party replacements were researched, including MAXDESIGN-3D's CC Attribution Chinese Dragon on Sketchfab (`https://sketchfab.com/3d-models/chinese-dragon-a5ad5ec06f43461f95bb93e95fe7553b`). Its download API returned HTTP 401 without Sketchfab authentication. No such asset was downloaded, incorporated, or licensed by this work. A listing alone is not a provenance record for a future download.

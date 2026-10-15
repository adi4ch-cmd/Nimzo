# Golden Dragon render and validation plan

Goal: produce actual articulated 3D review footage and preserve settlement/fallback until quality and Android alpha gates pass.
Spec: user master task and docs/NIMZO_LOCKED_20_GIFTS_PREMIUM_VIP_2026-10-10.md.

1. Audit current branch, original MP4 streams/frames, gift UUID/event routing and pinned VAP API.
2. Build original Blender geometry and animated scene in tools/golden_dragon/scene.py. Render a diagnostic frame before a 360-frame, 30fps RGBA sequence. Inspect anatomy and framing. Keep review exports outside the Flutter bundle until accepted.
3. Encode neutral-background H.264 review, lossless RGBA archive, transparent poster and VAP color+alpha candidate with explicit metadata. Validate count, frame motion, edge alpha and decoded mask on light/dark backgrounds.
4. Add a render-only GitHub Actions workflow with no APK job and artifact upload. Inspect native VAP implementation. Do not route unverified packed media through video_player or activate candidate in production.
5. Run available media checks, Flutter analysis/tests if SDK can be installed, and document exact evidence and unmet gates. Commit to dedicated branch and publish review artifacts/PR if credentials permit.

Constraints: only Golden Dragon; existing UUID c3f41e6e-68d5-4e56-9253-33421ec18fc3; server price only; no database writes, APK, voice changes or deletion of fallback assets.
Review focus: alpha edge correctness; articulated rather than rigid movement; visually inadequate procedural anatomy; metadata/layout mismatch; no device evidence mistaken for production readiness.

Execution: inline, authorized by user's START NOW and execute-without-plan-stop instructions.

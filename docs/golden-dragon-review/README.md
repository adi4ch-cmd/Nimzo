# Golden Dragon rendered review files

**NOT production complete.** These are actual 12-second Blender 3D motion-study exports (360 frames, 30 fps, 540×960). The art remains below the user's requested premium standard. No candidate is activated in Flutter/Supabase and no APK was built.

- [Moving neutral-background MP4](golden_dragon_demo.mp4)
- [Moving light-room desktop composite](golden_dragon_room_light.mp4)
- [Moving derived-dark-room desktop composite](golden_dragon_room_dark_derived.mp4)
- [VAP v2 packed color+alpha candidate](golden_dragon_vap_candidate.mp4) — needs a VAP compositor; **Android playback unverified**.
- [Blender .blend and reproducible source ZIP](golden_dragon_source.zip)
- [Transparent rendered poster](golden_dragon_poster.png), [catalog thumbnail candidate](golden_dragon_thumbnail.webp)
- [Actual media verification](verification.json), [SHA-256 checksums](SHA256SUMS), [QA evidence](golden_dragon_qa_evidence.zip)

The room composites use a checked-in screenshot and a labeled derived-dark stress background. They are not Android recordings. Every lossless master RGBA frame was decoded and compared pixel-exact against the original PNGs. CPU VAP alpha MAE: 0.105/255. Device decoding, Flutter surface blending, Vivox coexistence and real gift send/receive remain pending.

Large RGBA frame ZIP (132 MB) and FFV1 master (74 MB) were produced locally in `/workspace/artifacts/dragon/` and are also outputs of the running render-only Actions workflow. They are intentionally outside Git and the Flutter bundle. GitHub's release upload endpoint rejected the upload with HTTP 401; these smaller review artifacts are hosted on the dedicated review branch instead. No production CDN URL was invented.

[Full audit and open gates](../GOLDEN_DRAGON_CGI_REVIEW_2026-10-15.md) · [Reproduction](../../tools/golden_dragon/README.md) · [Draft PR #7](https://github.com/adi4ch-cmd/Nimzo/pull/7)

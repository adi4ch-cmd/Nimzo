# Profile and room screenshot fixes — 2026-10-24

The first two owner screenshots are visual references from another app. The three NIMZO screenshots show a duplicate membership badge/oversized nameplate, missing applied collectibles in profile sections, a plain room-user card and clipped mic-seat identity. Existing accounts, rooms, purchases, relationships and balances are preserved; no production data or schema is changed.

## Implemented

- Public profile shows one standalone membership identity. The premium username chip fits its content instead of painting a full-width dark block.
- Profile frame and rides/entrance sections include the actual server-confirmed applied membership originals or publicly verified equipped Store items. They do not create ownership records. Preview taps open original media; missing/expired entitlement cannot manufacture an equipped item. Legacy collectibles remain visible.
- Room-user card has a compact real-art header, centered real avatar/frame, cream/gold native card layout, real profile/country/bio and existing level values. Applied membership cards and manual Store card/frame overrides are supported. Social, gifting, mention, seat moderation and leave actions remain. Edit Profile now opens the actual editing route.
- Fifteen-seat grid uses compact nameplates and Store identity spacing. The mute icon overlays the avatar rather than taking another text row. Occupied muted seats and long names fit320/360/390dp, including the320x640 reconnect flow. Muted users do not animate Store mic waves from stale speaking state. Room-theme contrast is respected.
- The voice-disabled Android entrypoint now returns its real SDK-deferred status. Flutter reports voice unavailable, skips token requests and does not display a microphone-permission retry for this build. Genuine SDK-enabled permission-denial behavior remains. Vivox is still deferred; this does not enable voice audio.

## Evidence and limits

Initial red regressions reproduced permission misclassification, duplicated profile art and nameplate overflow. A muted occupied seat also reproduced12px overflow. Targeted component/voice/profile tests passed61 checks, and the final occupied-room/reconnect walkthrough passed7 checks. Analyzer:0 errors/0 warnings; informational style notices remain. Feature-lock, source-original checksum and native auth-key guards passed. Full Flutter regression and Android15 install/startup are required in the1.0.43 build workflow before publication.

[Profile header](ui/profile-room-fixes-20261024/profile-header-host.png), [actual applied collections](ui/profile-room-fixes-20261024/profile-collections-host.png), [room-user card](ui/profile-room-fixes-20261024/room-card-host.png), [voice-deferred room](ui/profile-room-fixes-20261024/room-voice-deferred-host.png): actual Flutter host captures with explicit test state; not Android/physical-device screenshots.

The owner explicitly requested a new APK with these fixes.1.0.43 is a TEST release, includes the latest Falla/Hafla source choices, retains existing genuine-media gaps and does not claim complete20-pack or authenticated Android acceptance. No automatic-update manifest is published. Development signing may differ from older test APKs; existing installations/data must be preserved if an update is rejected.

Final visual review caught insufficient contrast in the dark-room voice-unavailable notice. A regression reproduced contrast below4.5:1; the corrected themed panel and text passed the contrast assertion and all7 occupied-room/reconnect checks. The earlier build attempt was cancelled before publication so only the corrected APK is delivered.

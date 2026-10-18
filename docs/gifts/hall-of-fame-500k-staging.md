# Hall of Fame — 500,000 coin NIMZO gift (staged)

Gift ID: `53f6278f-1770-5be9-ae07-329c34f36c47`
Name: **Hall of Fame**
Category: `premium`
Server price: **500000 coins**
Icon: `nimzo/assets/gifts/hall_of_fame.svg` (new original vector icon)
Animated format: Tencent VAP v2 (packed RGB + alpha), 7.9 sec / 237 frames / 30 fps. Audio is muxed into the VAP file.

## Work completed
- NIMZO Supabase `public.gifts` contains the exact ID/name/price and icon path, currently `active=false`.
- Flutter artwork renderer supports the icon, and gift tray now has Premium category.
- Verified room gift event stream permits Hall of Fame ID, looks up `gift_animation_media.approved=true` HTTPS video, and routes it to an alpha-aware `flutter_vap_player: 2.1.1` overlay.
- Room payment is still server-authoritative through existing `send_gift` RPC, with idempotency and backend price checks unchanged.
- The app requires a verified remote video URL; no unapproved third-party MP4 is bundled or published in GitHub.
- The test-only VAP file is held in the conversation package, **not** the repo and **not** the production Supabase storage.

## No production release yet
The user-provided ZIP contained repeated `17ae.com` watermarks. The reconstructed video has remaining traces and altered regions, and rights to source media/audio have not been verified. **Do not set active=true or approved=true** for that candidate. New media must have authorized, watermark-free rights, and pass full-frame, native Android and real iOS playback including original sound with Vivox active.

The staged Supabase catalog entry is intentionally invisible in normal gift tray queries. Users cannot spend 500000 coins on it.

## Release steps after media authorization/QA
1. Obtain a clean licensed VAP v2 `video.mp4`, 237-frame or other validated duration, and correct `vapc` atom.
2. Upload the media through Supabase Storage API (not through `storage.objects` SQL) to an HTTPS address; verify network response and downloaded checksum.
3. Test Tencent VAP native transparency, audio and queue completion on Android and physical iOS while Vivox voice is connected. Check payment UX in a disposable wallet/test room.
4. Set `gift_animation_media` row to a verified HTTPS `video_url`, `duration_ms` and `approved=true` only after these checks.
5. Enable the gift by setting `public.gifts.active=true`. Confirm exact price 500000 and only then merge/release the approved branch.
6. Never adjust live wallet balances to simulate a test. Preserve existing Sports Car and transaction records.

No APK has been built or approved from this branch.

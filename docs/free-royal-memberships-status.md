# NIMZO Free Royal Membership — implementation checkpoint (2026-10-16)

## References
- User-supplied VIP video: 1000117670.mp4 (148.6s); VIP1–VIP8.
- User-supplied SVIP video: 1000117666.mp4 (42.8s); SVIP1–SVIP9.
- Videos are visual references. Third-party creature/vehicle art is NOT bundled or redistributed.

## Implemented
- Existing retired paid membership is still disabled and cannot charge coins.
- Separate RLS-protected `free_memberships` table; no purchase, deadline or payment fields.
- Authenticated `activate_free_membership('vip'|'svip', tier)` checks tier bounds and active account, creates/upserts a free selection and updates display kind. Existing other kind selection is preserved.
- Original 17 tier-specific SVG emblems and animated native Flutter royal stage.
- Real navigation to /vip and /svip and free activation UI.
- Original themed VIP1–VIP8 and SVIP1–SVIP9 collection screens.
- Selected member badge, avatar halo (Me, public profile, mini profile, occupied mic seats), and colored chat bubble border.
- Original wallet, coin, diamond and historical paid entitlement data not modified.

## Intentionally not claimed complete
- Video-equivalent photorealistic 3D animal/mount/vehicle entrance media and alpha playback are NOT created in this work.
- Room themes, synced full-screen entry broadcasts, special GIF portraits and high-fidelity mic waves are not integrated yet. Cards in collection are explicitly labeled previews.
- Full physical-device testing and two-device Vivox coexistence remain unverified.
- The SVG crests are original vector artworks, not a claim of copying the video artwork or providing cinematic 3D models.

## Production migration
`supabase/migrations/20261016100000_free_royal_memberships.sql` is additive. Old VIP/SVIP membership assignments stay retired; old purchase/reward functions remain disabled.

## Testing
- CI uses Flutter 3.47.6, runs `flutter analyze` and full `flutter test`.
- Android verification build workflow uses the existing native Vivox SDK integration and package/signing checks.
- APK availability is determined by the actual completed GitHub Actions run, not by source compilation alone.

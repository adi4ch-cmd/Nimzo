# NIMZO Android 1.0.20+120 — Gifts, medals, profile and room fixes

Release built from the existing feature/profile-reference-redesign branch, after the final gift-only and Flutter regression workflow passed.

- Match the existing catalog gift artwork with the specific NIMZO bundled images; replace eight flat/missing mappings without altering gift prices or transaction records.
- Use premium gift tray tiles; real SVGA effect badges only where the genuine clips are bundled (Rocket and Sports Car).
- Read equipped Royal Crest from authenticated store ownership, including users' full profile, Me, room mini-profile, mic seats, and joined-member list.
- Preserve prior VIP/SVIP, Room Rocket, Profiles, Moments, Active levels, and server-side stale-room-presence cleanup.
- Never reset profiles, wallet balances, user IDs or gift ledgers.
- Device-side voice, login, gift sending and media playback still require user test; no production signing is assumed.

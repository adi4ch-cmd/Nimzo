# NIMZO paid gift and Rocket delivery recovery (1.0.32 test)

Live read-only audit on 2026-10-19:
- Room `c4de6b18-72b6-49d0-8b54-8a127e5cf168` received actual server-side Rocket events at thresholds **5M, 10M, 20M, 30M, 50M** while cumulative room gifting showed **51M**. The next level is 100M. No payouts or extra wallet rewards were issued.
- The `room_diamond_blast_events` and `gift_animation_events` tables are in the `supabase_realtime` publication and have authenticated per-room RLS reads.
- Existing playback relied solely on Realtime delivery to show milestones, and the gift broadcast dropped the first snapshot without distinguishing new post-join events from history.
- The 1.0.31 APK contains 12 Rocket clips with the Tencent `vapc` MP4 atom. Fly clips are 1.5s; reward clips are approximately 10s. Reward stages 1–3 have no AAC sound track. Reward stages 4–6 have AAC, but old player used `mute:true`.

Corrective source:
- Each joined room now reads only its own recent, authenticated, **server-settled events** every 3 seconds. Initial time cutoff and ID dedup prevent replaying old results. Stale rooms/cycles are excluded; there are no financial writes.
- Gift event recovery is also read-only. The new send does not run again to show missed animations, so no duplicate debit.
- Rocket 4–6 original audio is unmuted, and native VAP initialization errors and watchdog timeouts display a visible 3s failure indication.

Still needed before claiming complete:
- Verify incoming gift video in a two-device Android room with Vivox voice connected.
- Send a **new** gift only with explicit user consent, and only if necessary; avoid repeatedly spending coins. Do not recreate or replay old threshold events to manufacture a pass.
- Verify VAP texture compositing, sound level and Rocket stage graphics on a physical phone.
- Full-screen player and preview cards exist. The staged Libra/Aries (100K each) and Romantic Blossom, Ice Queen Magic, Tiger Warrior (500K each) are still **not paid-sendable** because their commercial-use-rights-cleaned, full-alpha original media is not approved. Do not falsely describe the previews as active.

Changes are staged in a draft PR and not merged into the production branch. Flutter CI and Android APK results must be independently verified.

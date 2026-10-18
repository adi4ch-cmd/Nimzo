# Issue 15 visual comparison matrix

Reference: owner video, 385.626822s. Pairs use targeted timestamps from the existing inventory, not another full extraction.
NIMZO captures are headless Flutter test fixtures, not real account/device photographs. Empty and unavailable data are intentional.
Images are normalized with aspect-preserving padding to 360×800; secondary fixture captures retain their existing 390×844 aspect ratio.
Comparison cards annotate actual differences and owner-required deviations; they are not equality or pixel-parity certificates.
The source 23 PNG files remain absent; their committed filename map was cross-referenced, not marked visually verified.

| Video | NIMZO surface | Evidence | Difference / verification |
|---|---|---|---|
| 00:01 | login | [Annotated comparison](compare-001-login.webp) | Email/Facebook/Google only. Mobile and Quick Login intentionally excluded; original NIMZO identity. |
| 00:17 | profile-details | [Annotated comparison](compare-017-profile-details.webp) | Compact fields, avatar, gender and sticky Save. Real profile fields retained; no age or ID fabricated. |
| 00:30 | checkin-unavailable | [Annotated comparison](compare-030-checkin-unavailable.webp) | Attendance unavailable in this fixture; no synthetic rewards shown. Live claim behavior unchanged. |
| 00:37 | home | [Annotated comparison](compare-037-home.webp) | Explore hierarchy and country chips retained. Empty rooms instead of fabricated people, banners or counters. |
| 00:47 | home-country-filter | [Annotated comparison](compare-047-home-country-filter.webp) | Searchable country filter opens and dismisses. Native keyboard and emoji flags require Android QA. |
| 00:57 | party | [Annotated comparison](compare-057-party.webp) | Horizontal Party rows use existing rooms. This fixture is empty; no invented member thumbnails. |
| 01:12 | moments | [Annotated comparison](compare-072-moments.webp) | Original empty mascot; Square/Follow retained. Actual model supports one image per post. |
| 01:16 | composer | [Annotated comparison](compare-076-composer.webp) | Compact photo tile, text area, Mention/topic chips and header Post. Duplicate large bottom action removed. |
| 01:34 | messages | [Annotated comparison](compare-094-messages.webp) | Compact inbox/search, original mascot. All/Unread only: presence data does not support Online. |
| 01:41 | profile | [Annotated comparison](compare-101-profile.webp) | Compact eight shortcuts and original SVIP banner crest. Balances explicitly unavailable in fixture. |
| 02:00 | public-profile | [Annotated comparison](compare-120-public-profile.webp) | Real identity/stats/collections remain; cover geometry is existing NIMZO layout, not pixel parity. |
| 02:09 | friends | [Annotated comparison](compare-129-friends.webp) | Compact tabs/search with original mascot. No synthetic friends or presence. |
| 02:19 | profile-details | [Annotated comparison](compare-139-profile-details.webp) | Sticky Save remains visible while details scroll; no profile contract changes. |
| 02:33 | ranking-tabs | [Annotated comparison](compare-153-ranking-tabs.webp) | Supported Wealth/Charm weekly/monthly queries retained. Unsupported ranking modes explicitly unavailable. |
| 02:38 | store | [Annotated comparison](compare-158-store.webp) | Original two-column design gallery, category art, preview-only labels; verified medal catalog remains separate. |
| 02:54 | family | [Annotated comparison](compare-174-family.webp) | Original purple palace backdrop and mascot. Family directory and Create remain explicitly unavailable. |
| 03:03 | cp | [Annotated comparison](compare-183-cp.webp) | Original heart crest and reward gallery. Unknown relationship duration stays unknown; no reward claims. |
| 03:08 | cp-gallery | [Annotated comparison](compare-188-cp-gallery.webp) | Original decorative CP rewards with inspectable preview dialogs; no invented tiers, durations or claim action. |
| 03:27 | membership-tier-1 | [Annotated comparison](compare-207-membership-tier-1.webp) | Original winged crest instead of a generic medal/diamond. Tier 1 purple; preview only. |
| 03:38 | membership-tier-4 | [Annotated comparison](compare-218-membership-tier-4.webp) | Six tier palettes retained, including red tier 4. Original art, not a copy of proprietary 3D assets. |
| 03:44 | membership-tier-6 | [Annotated comparison](compare-224-membership-tier-6.webp) | Tier six teal palette and original crest; all six tiers remain viewable without granting membership. |
| 03:58 | membership-perk-17 | [Annotated comparison](compare-238-membership-perk-17.webp) | All 20 popup pages navigable; square art and compact height fixed; close/previous/next retained. |
| 04:35 | create-room | [Annotated comparison](compare-275-create-room.webp) | Audio-only creation. Original mountain treatment and existing real media picker/create action retained. |
| 04:54 | room-seat-sheet | [Annotated comparison](compare-294-room-seat-sheet.webp) | Seat actions preserved; disabled permission-safe moderation entries; Cancel keeps room joined. |
| 05:04 | room-reactions | [Annotated comparison](compare-304-room-reactions.webp) | Reaction picker opens, selection updates the outgoing draft, and dismisses without sending a message. |
| 05:07 | room | [Annotated comparison](compare-307-room.webp) | Exactly ten custom microphone-chair tiles in 5x2, not the reference 12. No fabricated room occupants. |
| 05:18 | secondary-public_profile | [Annotated comparison](compare-318-secondary-public_profile.webp) | Profile data/collections and supported deep content retained; original cover arrangement differs. |
| 05:30 | secondary-room_settings | [Annotated comparison](compare-330-secondary-room_settings.webp) | Existing settings controls and handlers preserved. Ten-seat requirement remains fixed. |
| 05:40 | room-music | [Annotated comparison](compare-340-room-music.webp) | Compact local music sheet retained. Imported-track controls remain unchanged; no Vivox changes. |
| 05:44 | room-music | [Annotated comparison](compare-344-room-music.webp) | Compact local playback presentation; native file picking and actual audio require device verification. |
| 05:48 | room-exit | [Annotated comparison](compare-348-room-exit.webp) | White exit confirmation and cancellation verified. Native Android back/device behavior still needs owner test. |
| 05:50 | room-exit | [Annotated comparison](compare-350-room-exit.webp) | White confirmation with Keep/Exit actions; cancel keeps room session alive. |
| 06:10 | store-Rides | [Annotated comparison](compare-370-store-Rides.webp) | Original entrance vehicle preview has bounded replay and reduced-motion support. Not an equipped entrance effect. |
| 06:19 | mini-profile | [Annotated comparison](compare-379-mini-profile.webp) | Room profile presentation captured separately; real room member/photo parity is not certified. |

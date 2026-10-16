# Verified gift animation backend

Applied to live Supabase on 2026-10-09 via migration
`verified_gift_animation_events_country_scope`.

- `gift_animation_events` is populated only by an AFTER INSERT trigger on `gift_events`, not by client submissions.
- Gifts with a unit price below 1,000,000 are excluded.
- 35M/50M unit-price gifts are `country` scope; all other 1M+ are `room` scope.
- Event rows carry sender, receiver, gift, quantity, original room, country and unit price.
- Authenticated SELECT is RLS-limited to the user's country for country events, or their room membership for room events.
- Unique gift event ID prevents duplicates. No existing users, balances or gifts were modified.

Pending: client-side Realtime subscription, country normalization beyond uppercase trim, approved animation media, end-to-end settlement/playback tests. No production-grade guarantee yet.

# Fifteen microphone seats — verification

Migration: `20261021000634_room_fifteen_mic_seats.sql`.

## Database behavior

On 2026-10-21, tested in an isolated PostgreSQL 17 container. The disposable schema used minimal room/profile/auth tables and the live `create_room`, `take_seat`, and `mod_mute_seat` function definitions. It is a focused seat integration test, not a full Supabase schema reset.

Before migration, `fifteen_mic_seats.sql` failed with `FAIL new room requires 15 seats`. After migration the same transactional script passed:

- New rooms initialize exactly 15 microphone seats.
- Seat 15 can be taken; direct inserts of seats 0 and 16 fail the constraint, and the seating RPC rejects 16.
- Ordinary members cannot lock or assign microphones.
- Room moderators can lock and mute microphones.
- Owners can unlock and assign a member to a new seat; the old seat is cleared.
- Locked and occupied destinations cannot be overwritten by assignment.
- Anonymous roles lack control RPC execute grants; an authenticated request with no user ID is also rejected.

A separate pre-migration fixture contained an existing occupied, locked, muted seat. Applying the migration added the other 14 seats and preserved all three original state values. No existing seat was deleted or replaced.

Run the transactional behavior test against a disposable project that has the migration applied:

```sh
psql "$NIMZO_TEST_DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/fifteen_mic_seats.sql
```

## Live additive migration

The coordinating agent reviewed and applied the migration on 2026-10-21, then reported these read-only checks:

- Both existing rooms have 15 seats (30 total).
- All 20 preexisting seat rows retained the identical aggregate digest: `789da0d46b0efa8c386926eb455e8e47`.
- Profile and wallet counts, and wallet sums, remained unchanged.
- Anonymous microphone assignment was denied.

No real user identifiers or account details are included here.

## Flutter behavior

The focused seat repository and room reconnect tests passed (4 tests). They cover the 15-seat grid as three aligned rows of five, usable controls at 320×640 and 390×844, member-only action visibility, moderator lock and mute dispatch, microphone reconnection, and canceled room exits. The original grid regression failed on missing seat 11 before implementation. A subsequent 320×640 failure-banner overflow was reproduced and fixed by reducing microphone panel padding and tile height.

```sh
cd nimzo
flutter test --no-pub test/room_seat_repository_test.dart test/room_reconnect_test.dart --reporter expanded
```

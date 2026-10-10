# NIMZO Voice Media Recovery — Android Test APK

This release includes the deployed production voice-token endpoint and tested
Flutter room recovery behavior.

- Respect short Vivox media interruptions for six seconds so the SDK can
  attempt native network recovery without concurrent login attempts.
- Prevent a false permanent-disconnect banner when upgrading a mic seat from
  receive-only to transmit-authorized mode.
- Clear the disconnect banner when native media reconnects.
- Keep a manual Retry if the media remains unavailable after the grace period.
- No claim that the mobile-network root cause is resolved; on-device voice QA
  and Vivox diagnostics are still needed.
- Never reset profiles, user IDs, rooms, memberships, VIP/SVIP, wallets,
  coins, medals, balances, gift transactions or auth identities.
- All targeted voice and room reconnect regression tests passed on commit
  069da9347967d1db6e502b81d85ff0f91e4e17ae.
- Build only an installable test APK if the verified permanent signing key is
  not configured; do not represent an ephemeral development certificate as a
  production update.

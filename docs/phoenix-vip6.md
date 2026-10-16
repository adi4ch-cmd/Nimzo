# VIP 6 Phoenix

Phoenix decorations use `phoenix_membership(p_user)` and the existing protected profile membership fields. This RPC uses the server clock and security invoker permissions, requires authentication, and grants no access based on Nimzo ID. A missing/invalid response or an unavailable backend gives the standard presentation.

The shared auto-disposed entitlement stream refreshes every 20 seconds, expires at the server-derived deadline and limits its display lease to 30 seconds. Request latency is subtracted. App backgrounding clears entitlement; returning to the foreground requests a fresh one. Purchases, gift restrictions, prices, rewards and all other VIP/SVIP tiers retain their existing authorization.

The Phoenix mark is original Flutter vector artwork in `phoenix_widgets.dart`. No new image or animation assets were imported. Frame rotation and entry wing motion use bounded controllers and repaint boundaries; reduced motion keeps static artwork and the entry announcement. Offscreen frames stop their controller.

Shared decorators cover the own/public profile, profile hub, room user mini profile, occupied voice seats, room chat and sender gift tray. The VIP 6 selector exposes previews without activating membership. Premium chat bodies retain dark text on the existing light surface.

Room entries are written only by a private database trigger after a genuine room membership insertion. Duplicate joins emit nothing. The trigger copies the exact `joined_at` wall-time boundary, and RLS exposes events only to joined room members from that boundary onward. The client suppresses historical snapshots, deduplicates events, caps its queue at five, confirms live entitlement, checks event age including response latency, and rejects pending responses that span lifecycle transitions.

## Verification

`supabase/tests/phoenix.sql` creates temporary accounts inside a transaction and rolls everything back. It checks active/expired/restricted membership, other-tier preservation, nonmembers/missing accounts, membership write protection, server-only entry writes, duplicate joins and outsider event reads.

Flutter tests cover server-clock activation with a clock-skewed date, target user lookup, expiry fallback, failed refresh, backgrounding, large text and narrow nameplates, reduced motion/offscreen frames, entry history/duplicates/staleness and delayed lifecycle responses. Existing room fixture tests isolate the new live stream. Room chat tests assert readable body colors both with and without Phoenix.

## Android delivery

Version: 1.0.10 (110). The existing release pipeline preserves the permanent signing certificate. Without its signing secrets, CI compiles and uploads an explicitly unsigned release-mode APK candidate and verifies native Vivox contracts. This candidate cannot be installed or used by the updater. The signed publisher still stops at the existing signing requirement; it never substitutes a key. Provision `NIMZO_KEYSTORE_BASE64`, `NIMZO_KEYSTORE_PASSWORD`, `NIMZO_KEY_ALIAS` and `NIMZO_KEY_PASSWORD` to build the installable release.

Automated verification does not establish physical-device audio, installation, OAuth or payment behavior. The user-visible release goal remains incomplete until an installable signed APK is produced and verified.

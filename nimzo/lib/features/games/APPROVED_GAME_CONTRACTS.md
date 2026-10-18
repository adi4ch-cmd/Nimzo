# Approved game execution gaps

The approved catalog contains Fruit Party Jackpot, Grady Lion, Bigetar, Slot,
Teen Patti, Lucky Wheel 77, and Bounty Football. All seven remain server-disabled.
`nimzo-ui-2.html` defines visual boards and explicitly describes random demo
results, not authoritative server outcomes. No approved execution contract was
found in the repository. The legacy `fruit_party` and `fruit_wheel` RPC paths
must not be reused for these identities.

Teen Patti is the fifth catalog entry: its reference has Player A/B/C with
2x/9x/2x multipliers and example card hands. This does not approve traditional
Teen Patti rules. Bounty Football is the seventh entry: its reference has
Home/Draw/Away with 2.5x/6x/2.5x. Approval must confirm that seventh identity,
match/outcome source, and full rules; catalog order is not such approval.

Each approved slug requires approved configuration/rules and versioning,
round/phase/deadline and reconnect state, wager limits/options, authenticated
room-membership authorization, idempotent wager submission, atomic wallet debit,
server-owned outcome and payout, and persisted settlement/history. Clarify gross
versus net multipliers, odds/probabilities, special options, cancellation/refund
policy, and error handling before enabling financial controls.

Current interactions only inspect reference options and preview chip amounts.
Selections do not create wagers, rounds, outcomes, winnings, or wallet writes.
The room overlay supports lower-65-percent, expanded, minimized, restored, and
closed states while retaining the existing room and voice controls. A rendering
engine such as Phaser cannot fill these missing game contracts.

## 2026-10-18: HTML5 in-room practice integration

Three owner-requested game screens are now bundled as fully offline WebView assets in the current Flutter room host:
- **Lucky 77**: `assets/games/lucky77_room_demo.html`, the separately approved 2×/8×/2× layout and chip controls.
- **Grady Lion**: `assets/games/grady_lion_auto.html`, approved 20-second automatic betting phases and room-compatible winner presentation. Winner names/DPs are still *demo-only sample data*; real player rankings require authenticated backend events.
- **Jackpot**: `assets/games/jackpot_9lines_demo.html`, provisional 9-payline/500–1M HTML practice. The owner explicitly rejected this generic visual as not matching their source video; **not final and not approved for production**.

All three use a strict **minimize/expand-only** JavaScript channel. The real Flutter voice room stays mounted underneath; its chat/mic UI is not duplicated. No WebView can read Supabase credentials or issue financial RPCs. The client-side spin result is NOT authoritative and MUST NOT move actual user coins.

### Paid-coin wagering blockers

The existing `public.play_game` server RPC executes only the legacy `fruit_wheel`/`fruit_party` identities. Changing the client `serverEnabled` flag or accepting client-generated HTML results is prohibited. Before a paid game can be enabled, each game must have reviewed independent server contracts, rules/odds, bet limits, a controlled multiplayer round clock, CSPRNG seed/outcome, replay/idempotency protection (including selected options and amounts), debit + settlement in one audited transaction, void/refund policies, reconciliation, independent verification and relevant legal/commercial authorizations. Existing rechargeable, exchangeable coins could have monetary value. The demo must never charge or pay out wallet coins on Android release builds.

No migrations were applied and no production wallet balance was changed for this HTML5 integration.

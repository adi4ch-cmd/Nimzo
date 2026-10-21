# Real Premium Store Implementation Plan

Goal: replace misleading Store previews with verified original media and preserve account inventory.
Architecture: keep existing Supabase catalog/ownership/equipment; add a locally pinned media registry and reusable media renderer. Imported items must have real bytes, declared assets and reported redistribution authorization. Preserve legacy IDs and artwork in a separate collection. No APK until end-to-end gates pass.
Spec: user CODEX MASTER TASK, 2026-10-20.
Execution: native, autonomous as explicitly requested.

Constraints: base 8073d98908f823d6ff5d83ba8b1fc13ea25cda6d; version >=1.0.36+136; no feature removal, no paid checkout, no VIP entitlement restoration. Tana/Vani permission unverified. DangLive owner authorization reported by user. PAG unsupported until native decoder proven.

- [ ] Audit bytes, compare DangLive inventory SHA256, record every accessible file including unsupported resources.
- [ ] Add media registry, real SVGA preview lifecycle/error handling and static artwork rendering. Verify decoded animation parameters and no cropped canvas.
- [ ] Add server-validated unequip and public visual equipment read RPC without exposing ownership inventories. Test unauthorized calls, unowned items and cross-user isolation in rolled-back transactions.
- [ ] Separate original legacy collection; use media registry for genuine previews and collect/equip actions. Preserve original owned IDs.
- [ ] Connect avatar frames to Profile and room users; supported decorations and themes to relevant components. Do not activate items without working renderers.
- [ ] Add source-only CI analyzer/regression/widget/asset decoder checks. No APK workflow trigger.
- [ ] Document before/after and exact remaining blockers; release only after native/Vivox/relogin/device gates pass.

Review focus: account switches, failed decoder futures after disposal, unrecognized/unsupported server catalog IDs, inactive owned items, small Android viewports. Tests must exercise these boundaries, not just search source strings.

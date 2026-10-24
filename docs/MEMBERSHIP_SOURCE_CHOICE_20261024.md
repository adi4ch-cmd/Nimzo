# Falla/Hafla source preference and complete-pack priority — 2026-10-24

The owner prefers Falla SVIP and Hafla/Falla VIP, permits mixing sources, and now explicitly prefers fewer complete packs over ten incomplete ones. No membership, purchase, equipment, wallet or room is removed. Existing eligible tiers remain accessible; incomplete media is never promoted as a full package.

## Source selection

- SVIP1–10: Falla original empty portrait frames, static matching tier medals and numbered identity ribbons replace Voku frames and Hafla identity art. Existing Falla animated main crests and source-proven SVIP7–10 mic waves are retained. Frames originate from the source's level-up portrait presentation; their original role is recorded, and NIMZO renders them around the real avatar.
- VIP1–8: Hafla original numbered main crests, medals and identity badges. VIP7–8 use the original wide Hafla nameplates. VIP1–5 use original empty Hafla nine-patch chat bubbles; only their Android control border is excluded by canvas crop, without modifying bytes. Existing Hafla VIP1–6 animated entrances are retained.
- Hafla/Falla VIP9–10 matching main crests were not found. Existing exact-tier YoHo identities remain; no lower tier is relabeled.
- Working same-tier originals from the previous integration remain where these two sources provide no verified replacement. The result is **not falsely described as an exclusively Falla/Hafla full pack**.

The registry records original APK SHA-256, nested source path, media SHA-256, exact kind/tier, dimensions, role and crop. Multiple surfaces may reuse one original badge; the render manifest deduplicates byte-identical files instead of inflating media counts. Previous files remain in the repository.

## Deeper source verification

Both existing authorized local APK sets were inspected beyond filenames, including DEX string inventories and relevant resource-array consumers. Falla exposes367 membership-related resource/media entries; Hafla418. These are candidate entries, not counts of usable pack components.

Important exclusions confirmed by code usage:

- Falla `UserResUtils.I(int)` / `mSvipBubbleBgColor` is consumed by the membership header's **points tooltip**. It is not evidence of a real room-message bubble.
- Falla `UserResUtils.T(int)` / `mSvipPageBg` is consumed by **SVIPPageActivity**. Its tier podium backgrounds are membership-page artwork, not verified profile-card or room wallpapers.
- Hafla `svga/vip4.svga` through `vip8.svga` are selected from `VipBroadCastBean` in `TempBigGiftHelper.XEffectGift.bindView`. They are broadcasts, not confirmed room-join entrances. They do not fill missing VIP7–8 entrance slots.

These distinctions prevent plausible-looking privilege images, tooltips or broadcasts being advertised as a complete working package.

## Complete-pack boundary

Core media means a matching frame, entrance, full profile card, medal, nameplate, real chat bubble, speaking mic animation and room background. This is separate from entitlement and real Android acceptance.

The current registry has one source-complete **core-media candidate: VIP6**. Its sources are YoHo frame, Hafla entrance/identity/medal, Orii profile card/mic, BGChat bubble and Tana room wallpaper. This candidate is not an exclusively Falla/Hafla package, and authenticated Android acceptance is still unverified. No complete core-media package from only the two available Falla/Hafla APKs was established.

Other tiers retain functional available-item equipment, but their UI says **Apply available items** and **Package contents**, with missing-original status. Only source-complete core media receives full-set wording. This does not create or grant paid membership.

Remaining exact-tier originals: high-tier entrances, full SVIP profile cards/bubbles, VIP7–10 cards/bubbles/mic, SVIP1–2 mic, and room wallpapers except VIP6. These files were not verified in the available local archives; no claim is made that the upstream apps themselves lack them.

## Delivery and validation

This source revision is newer than published1.0.42. That APK is not overwritten and does not contain these source-choice changes. No additional APK is built by this change. Host rendering, source coverage and Apply/Remove are checked separately from authenticated Android playback.

[Actual Flutter host preview](ui/membership-source-choice-20261024/all20-source-preference-host.png), rendered with test membership state; not an Android capture. [Audit/validation summary](validation/membership-source-choice-20261024.json). The source index contains121 role mappings backed by105 distinct original files;67 source-slot selections were changed. Targeted29 tests and analyzer passed. Full source/backend CI is run on the pushed revision.

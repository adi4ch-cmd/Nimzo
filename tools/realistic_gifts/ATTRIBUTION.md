# Free asset provenance for the four car previews

No paid assets or subscriptions are used. These rights apply to the specific files below, not every item on a marketplace.

## Car Concept — CC BY 4.0

- Asset: [Car Concept](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/edc7c9e67c639d230715049ee31f9a96a6babbbe/Models/CarConcept).
- Model/textures: Eric Chadwick, © 2024 Darmstadt Graphics Group GmbH. Earlier base model: Unity Fan's public-domain Free Concept Car 004, as documented by the upstream author.
- [Asset-specific license](https://github.com/KhronosGroup/glTF-Sample-Assets/blob/edc7c9e67c639d230715049ee31f9a96a6babbbe/Models/CarConcept/LICENSE.md): [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/). Commercial use and adaptations permitted with attribution; license terms apply. Logos/trademarks are separately excluded.
- Source GLB SHA-256: `c272098089d78c5cd9fd9f24ff50ee8acf8d932c55f2d55fc10adb6c8998966b`.
- NIMZO changes: removed steering emblem and license-plate logo surfaces; purged orphan resources; revised four paint materials; animated existing wheel assemblies, steering, driving path and camera; added lighting, volumetric tire haze and premultiplied RGBA fade. Removed the diagnostic shadow-catcher plane after its finite edge was visible during exit. No replacement car geometry was generated procedurally.
- The model's author-provided part hierarchy/pivots are retained. The NIMZO rolling controls are added to that hierarchy. This is not a claim that a pre-existing skeletal car animation was included; upstream documents removal of the original FBX bones during optimization.

## Studio Small 09 environment — CC0

- [Specific HDRI asset](https://polyhaven.com/a/studio_small_09), from Poly Haven.
- [Poly Haven license](https://polyhaven.com/license): assets are CC0. No subscription or account needed.
- 1K EXR SHA-256: `44dcbed056512ecd8afd2a3d7ba73d2dd4c24694d0c72005fafcb2469bbc8fd4`.
- Used for actual image-based lighting/reflections; hidden from camera by Blender film transparency.

The car render output/source handoff retains this attribution. Before eventual app activation, include it in accessible in-app gift/legal credits; attribution in this repository alone is not the completed mobile attribution flow.

## Animals — not incorporated in final gifts

- [Running Tiger](https://sketchfab.com/3d-models/running-tiger-fc2c7fd74dd04e39935803b884c77258), Amil (francescolima74): the specific Sketchfab API record states CC BY 4.0 and commercial use allowed. A public CC-BY redistribution in AllenAI Objaverse was downloaded for inspection; source UID `fc2c7fd74dd04e39935803b884c77258`. Actual model has one Run animation; actual Blender inspection found 3,204 mesh vertices, one Run cycle and no strand groom. A Cycles diagnostic was rendered and rejected as insufficiently realistic for the requested premium furred animal; no walk/roar action is included. No complete Royal Tiger animation is claimed.
- [Royal Lion](https://sketchfab.com/3d-models/royal-lion-realistic-3d-character-52c58169b3354c02a66008ed3a98309e), lehipo: API confirms CC BY 4.0 and downloadable=true, but actual download access is not yet available here. The preview was inspected and rejected as a stylized sculptural lion, without convincing realistic fur. No render/quality acceptance.
- Anees Animates' “Realistic Tiger” UID `515f6c841a124b9897251cde436c2ae0` was rejected: its specific license is **CC BY-NC 4.0**, so it cannot be used for NIMZO's commercial gifts.
- Three other available CC-BY lion models were inspected and rejected as visibly low-poly/stylized or a cub; no lion footage or placeholder was substituted.

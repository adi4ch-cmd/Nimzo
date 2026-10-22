# Dynamic progression presentation (v3)

The approved `nimzo_remote_settings` key `progression.styles` controls only the colors, glyphs and compact shapes used by `ProfileLevelPill`. It never changes the actual server-provided level, XP, rank, label, eligibility, balance or entitlement. The three existing kinds remain Wealth, Charm and Active. No remote image/codec is required.

Example payload for an owner-authorized inactive staging row:

```json
{
  "version": 1,
  "styles": [
    {
      "kind": "wealth",
      "min_level": 1,
      "max_level": 20,
      "color": "emerald",
      "glyph": "diamond",
      "shape": "pill"
    },
    {
      "kind": "wealth",
      "min_level": 21,
      "max_level": 120,
      "color": "amber",
      "glyph": "star",
      "shape": "rounded"
    }
  ]
}
```

All six style fields are required. Kinds are `wealth`, `charm`, `active`. Inclusive level bounds must be integers between 1 and 120; same-kind bands must not overlap. There can be at most 36 styles. Colors are the compiled contrast-safe palette `emerald`, `sapphire`, `ruby`, `amethyst`, `amber`, `rose`, `slate`. Glyphs are `diamond`, `heart`, `sparkle`, `shield`, `star`, `bolt`. Shapes are `pill`, `rounded`, `square`. Arbitrary hex colors, font/codepoint values, SVG, URLs, animation, text, sizing, XP and grant fields are unsupported.

Unknown fields, wrong types, unsupported version/values, missing fields, excessive bands or overlaps reject the entire payload and use the original artwork. Uncovered bands and unavailable/out-of-range incoming levels retain original behavior. The number and accessibility label always use the incoming authoritative level and established kind label. Successful settings refresh/revision replaces the style; deactivation/removal reverts artwork after refresh without altering levels. Existing root content-sync wiring supplies revision invalidation and periodic refresh.

Verification: `test/level_style_catalog_test.dart` covers schema validation, inclusive boundaries, all allowed visual tokens and rejection of authority-like payload fields. `test/dynamic_level_pill_test.dart` covers unchanged level/semantics for all three kinds at 320px/1.8x text size, deactivation fallback and unavailable levels. Existing `test/profile_level_pill_test.dart` retains original default style checks. Tests are scheduled centrally by root; no APK/AAB/IPA or live setting write was performed for this implementation.

Owner publication permissions/schema validation remain the existing settings-table/backend responsibility. Client validation is defense in depth and confers no authority. Supported visual token and range changes use this setting without rebuilding; new glyph renderers, codecs or new gameplay/progression logic require shipped app code.

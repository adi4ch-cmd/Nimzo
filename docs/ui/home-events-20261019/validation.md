The Home header now uses the supplied purple gradient and My, Popular, Discover, New, Pakistan tabs. Home starts on My, combines recent/followed rooms without duplicates, and retains the existing room providers, country filter, rankings and Go Live action. Discover shows the five complete supplied banners. The second bottom destination is now Events; all five visible labels are Room, Events, Square, Message, Me. Events shares the reference header and banner list. Existing /games task links and /games?room= links still open the games catalog.

Banner artwork comes from the supplied screenshot, rendered through clipped source rectangles so phone chrome and the incomplete sixth banner are excluded. This change supplies display artwork, not campaign rules or reward settlement. No database, gift, economy or APK workflow changes were made.

Validation used Flutter 3.47.7 / Dart 3.13.5:

- 14 focused checks passed across home_events_reference_test.dart, events_routes_test.dart, home_reference_test.dart, home_refresh_test.dart, home_narrow_layout_test.dart, home_country_filter_test.dart, home_country_sheet_test.dart and issue15_navigation_test.dart.
- Events previews at 320 and 390 logical pixels were captured after explicitly waiting for the banner image to decode. The previews use Noto Serif for Android's serif family.
- flutter analyze --no-pub --no-fatal-infos exited successfully: no errors or warnings; 48 informational lint findings.
- git diff --check passed. Independent code review found no remaining actionable defects.

The full test suite is not green. Its run reported 356 passes and 15 failures. The default-My check was corrected and passed in the final focused verification. The other 14 failures also reproduced on an isolated copy of unchanged release-source commit f1140e5, using the same Flutter SDK and dependencies:

- asset_bundle_integrity_test.dart: missing retired rose.png asset.
- clone_constraints_test.dart: obsolete seven-game catalog expectation.
- reference_preview_test.dart: Home and game golden image mismatches. The Home fixture now uses My's provider; its saved screenshot still predates this redesign.
- master_visual_preview_test.dart: room overlay golden mismatch.
- issue15_room_walkthrough_test.dart: room sheet checks at 320, 360 and 390.
- tingle_video_ui_test.dart: obsolete ranking tab checks at 320, 360 and 390.
- remaining_visual_qa_test.dart: existing games catalog golden mismatch.
- room_user_sheet_test.dart: gift-sheet opening, member actions, and own-seat gift expectations.

No APK was built or released for this UI change.

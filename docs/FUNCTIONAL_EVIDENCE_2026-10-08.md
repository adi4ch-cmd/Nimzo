# Functional evidence — 8 October 2026

Inspection baseline: HEAD `ff58ce4` plus the functional completion changes in this delivery. This is a functional source inventory, not a repeated visual audit and not a production write test. Pending files can change after inspection; root validation and final diff take precedence.

Evidence levels: **S** source connection inspected; **M** existing automated/mock/contract test files inspected (presence alone is not a fresh pass); **C** previously recorded disposable schema-clone verification; **L** previously recorded live read-only metadata/probes; **D-unverified** genuine session, device/provider or production-write behavior not exercised. No tests were executed by this inventory author and no production mutation was made. Existing recorded analyzer/172-test results apply to their recorded baseline, not automatically to this pending diff.

Prior live evidence establishes 45 public tables with RLS, all 35 then-literal client RPC names present, protected wallet/profile counters, realtime publication and two active Edge Functions. Those baseline counts do not include subsequently deployed preferences/support tables and RPCs and do not prove end-to-end behavior. Root reports live deployment `20261008165336` with RLS/grants/triggers read-verified and PostgreSQL 17 clone authorization/ownership/domain tests passing. Moderation migration `20261008170422` is also live: authenticated RPCs and distinct Kick/Ban admin/owner/SVIP/rejoin contracts were verified against the clone; 13 focused client tests passed. These results are root-provided evidence, not independently rerun by this inventory author. The four gift/ranking/VIP replacements were subsequently deployed as `20261008094444`; older sentences in the backend checkpoint saying “not deployed” are superseded by its deployment update and voice deployment report.

| UI / feature / route | UI exists | Backend exists | Connected | Tested evidence | Missing | Exact blocker |
| --- | --- | --- | --- | --- | --- | --- |
| `/`, `/onboarding` | Splash/onboarding | Not needed | Router/auth redirect | M auth_redirect, profile_setup_redirect | Device startup | D-unverified |
| `/login`, `/register`, `/verify` | Email, Google, Facebook, verification/retry | GoTrue; profile/wallet init | AuthRepository → GoTrue | S; M validators, auth redirects; C account fixtures | Genuine signup/email/OAuth flow | Real provider redirects, configuration and genuine session unavailable |
| `/forgot`, `/update-password` | Recovery/change-password | GoTrue reset/update | Auth calls and recovery redirect | S; M redirect coverage | Email deep-link/device recovery | Genuine mailbox/session/device unavailable |
| `/profile-setup`, profile edit | Name/bio/gender/DOB/country/language/avatar/cover | profiles own-row update; media storage references | Direct update with returned-row guard, upload | S; M profile_repository/image_format; C protected fields/language | Live upload/update/read-back | Genuine session/upload/read-back unavailable; live storage policies read-verified by root |
| `/home` | Banner, room categories/list, refresh | banners, rooms_ranked, my_rooms, follow_room | Repositories/providers | S; M home_refresh/data_flow; L security-invoker view | Actual authenticated feed/realtime | Session/device unavailable |
| `/discover` | User search, profile access | profiles | Numeric ID or escaped username/display-name query | S; M security_contract | Authenticated search behavior | Genuine session unavailable |
| `/create-room`, `/room/:id` | Permanent room, join/password/leave, ten seats, chat/gifts | create/join/leave/take/leave-seat, mic_seats, room_members | RPCs and realtime streams | S; M room_session/reconnect; C IDs/ten seats/one membership; L invariants | Real multi-device/realtime lifecycle | Sessions/devices absent; all-status owner guard local migration remains undeployed |
| `/room/:id/settings` | Name/theme/privacy/password/permissions/avatar/moderators | update_room_settings overloads, set_moderator, room_member_list | Owner UI → RPC; server authorization required independently of owner query parameter | S; C supported room contracts; M interactions | Owner/member device exercise; atomic combined avatar/settings save | Genuine owner session; main settings and avatar are separate RPCs |
| Room user sheet | Profile/follow/friend/block/report/mute/distinct Kick/Ban | Social/reports; moderation RPCs deployed in `20261008170422` | Client actions connected to authenticated moderation RPCs and seat streams | S; root C admin/owner/SVIP/rejoin and clone match; root 13 client tests passed; L RPC deployment | Real multi-device and provider-enforced immediate moderation | Vivox admin/revoke semantics and devices absent |
| Room chat/tools Clean | Message send/read, own-message cleanup | send_room_message, clear_room_chat; join-time RLS | RPC/stream | S; C clock/cleanup/reentry; M targeted integration | Live delivery | Genuine sessions/devices absent |
| Room tools Broadcast/Gathering | Announcement text/time UI | Existing room chat transport | Sends text via supplied callback | S | Dedicated scheduled event/broadcast system | These are chat announcements, no scheduler/event contract |
| Room Vote/Video/Mora/Calculator/Wheel/Prize | Panels/options | No matching authoritative execution | Unavailable/read-only | S | Voting, video, game results, gift totals, prizes | Product/service contracts absent; preview controls do not settle anything |
| Room Music/PK/treasure | Panels | No matching execution contract | Explicit unavailable | S | Audio library, PK settlement, treasure eligibility/schedule/prizes | Authoritative contracts/provider content absent |
| `/games`, `/games-play`, room game overlay | Seven approved boards; expand/minimize/restore/close; option/chip selection | No seven-game outcome/settlement contracts | Catalog disabled; previews only | S; M game_catalog/layout/room_game_host | All approved game execution | Rules/config/version, rounds, membership, wagers/debit, server outcome/payout/history/idempotency absent |
| Legacy fruit game repository paths | No approved-catalog mapping | fruit_party/fruit_wheel legacy RPCs | Existing legacy paths retained | S; M game_repository_validation/game_and_economy | Approved compatibility | Legacy identities are not substitutes |
| `/moments`, `/moments/create`, `/moments/:id/edit`, `/moments/:id` | Feed/detail/create/edit/delete/like/comments/report/gift | moments_feed, moments/likes/comments/reports, toggle_like, delete_moment_comment, send_moment_gift | Queries/RPC/storage references | S; M editor retry/comment identity/lifecycle/update/gift refresh; C gift settlement/replays | Genuine media/social workflows | Session/storage transport unverified; pending retry fixes need final test results |
| `/messages`, `/chat/:id` | Conversation list, drafts, send/read | conversation_list, send_private_message, mark_read, messages realtime; deployed preferences enforcement | Repository/RPC plus read-invalidation stream | S; root 8 focused messaging/notification tests passed; C preferences authorization | Live transport and push | Genuine sessions/devices absent; automated stream behavior is not device delivery |
| `/notifications` | Categories, mark all read | notifications, mark_notifications_read; gift notification trigger deployed | Queries/RPC plus new read-invalidation stream | S; root 8 focused messaging/notification tests passed; L gift trigger deployment/publication | Device push | registerDevice has no observed lib consumer; FCM lifecycle/delivery and devices unverified |
| `/profile`, `/profile/:id` | Me/public profile, gifts/tags/models/photos/collections/stats/visits | profiles, profile_stats/profile_gifts/record_visit, collections/tags/models/couples | Repository queries/RPC | S; M profile_content/repository/model/gift refresh; C counters | Authenticated production workflow | Genuine session; collection ownership award/purchase contract separate |
| `/social/:kind/:id` | Followers/following/visitors, friend/follow actions | follows/visitors/friendships/accept_friend/record_visit | Queries/direct writes/RPC | S; M social_avatar/session_identity | Multi-user requests | Genuine sessions absent |
| Privacy → blocked users | Connected list/unblock screen | blocks owner writes | Repository list/delete and privacy navigation | S; current connected UI reported by root | Genuine authenticated list/unblock workflow | Genuine session/device unavailable |
| `/cp` | Couple requests/invite/accept/cancel | couple_requests/couples, accept_couple_request | Queries/inserts/RPC/deletes | S; M couple_panel_layout; L deployed collection/CP schema | Production two-user workflow | Genuine sessions absent |
| `/ranking` | Wealth/Charm/Room weekly/monthly; unsupported combinations guarded | leaderboard, weekly_star | Supported repository calls | S; C six combinations/self-gift/daily rejection; L deployed repair; M targeted | Daily/Gift/Active authoritative rankings | Distinct ranking contracts absent |
| `/levels` | Stored wealth/charm/activity totals, server level fields | profiles counters | Stored fields only | S; C protected counters; pending M profile_levels | Thresholds/activity awards/progression | Authoritative thresholds/accrual policy absent; zero total is not engine completion |
| `/wallet` | Coins/diamonds | wallets, protected balances/ledger | Own-row read | S; C RLS/debit/credit/reconciliation; L unaffiliated read probe | Live settlement/device view | Genuine session absent; no fabricated balances |
| Room/profile/Moment gifts | Catalog, recipient/quantity, errors/retry | gifts/events, send_gift/send_moment_gift | RPC idempotency keys; pending errors/recipient/refresh fixes | S; C splits/concurrent single settlement/payload binding; L deployed repaired definitions; M gift tests | Live settlement/provider transport | Production financial writes intentionally not exercised; root validates pending fixes |
| `/vip`, `/svip` | Ten-tier presentation, status/progress, claims | vip_status, svip_thresholds, daily/Friday reward catalogs and claims | Server status/catalog, supported claims; purchase unavailable | S; C active/expired/preactivation cycles; M vip presentation/tiers; L deployed progress | Native VIP purchase, locked ten-tier live catalog, Sunday rewards | Live eight legacy SVIP tiers; locked catalog migration undeployed; Sunday 21:00 Riyadh contract missing |
| `/recharge` | Server packages and native IAP checkout with provider gate | recharge_packages; verify-purchase v6 ACTIVE with JWT verification; service-only apply_recharge | Native IAP/provider gate and Google account binding connected | S; root L v6 ACTIVE/JWT; existing C economy rules; sandbox path does not grant live credits | Genuine store purchase/receipt/credit and device checkout | Real provider products/credentials/receipt/device unavailable; Apple server account-token contract missing and blocked |
| `/settings`, `/info/Account` | Account ID/password/logout/update | Existing Auth/profile contracts | Calls wired, logout room/voice cleanup | S; M logout_cleanup | Real revocation/device handoff | Genuine session/device unavailable |
| `/info/Language` | Language selection | profiles language | Direct profile persistence | S; C language persistence; M targeted | Full app localization | Selection persistence alone does not provide translated UI |
| Settings notifications, `/info/Privacy` private-message switch | Connected PreferenceControls | user_preferences/user_settings/update_user_settings and message enforcement deployed `20261008165336` | Repository/control/server enforcement connected | S; root L RLS/grants/triggers; root C PG17 auth/owner/domain tests passed | Genuine authenticated preference persistence/use | Session/device unavailable; delivery-provider behavior remains unverified |
| `/info/Help and feedback`, support requests | Connected ticket submission/readback UI | support_tickets/submit_support_ticket deployed `20261008165336` | Form/repository/owner reads connected | S; root L RLS/grants/triggers; root C PG17 contracts passed | Staff response/operator/contact workflow | Operator and confirmed contact details pending; ticket submission is not support staffing |
| Account deletion | Connected deletion-request UI | account_deletion_requests/request_account_deletion deployed `20261008165336` | UI/repository/request queue connected | S; root L policies/grants; root C owner/auth contracts passed | Actual data/session erasure processing | Request queue is not completed erasure; operator/retention processing contract needed |
| Terms/privacy/legal | Connected legal drafts in settings/About | Static content; no backend needed | Navigable UI connected | S; root reports connection | Approved legal text/operator/contact/jurisdiction | Confirmed operator/contact/jurisdiction and legal approval pending; draft rendering is not approval |
| `/info/About`, Check for updates | Installed version and manual/startup update | GitHub release metadata/native Android bridge | Download/hash/package/build/signature checks and installer handoff | S; M app_update/settings_about/native update; recorded prior native/workflow tests | Actual install/update success | Physical Android device/installer permission flow not exercised |
| `/info/Task` | Daily checkin/gift/10-minute task rows | No authoritative claim engine | Disabled | S | Eligibility, schedules, idempotent rewards | Task contract absent |
| `/info/Store` | Working coin-package navigation plus explicitly labelled cosmetic previews/prices | Collections exist, no consumer store/inventory purchase contract | Unavailable | S | Catalog/ownership/purchase/equip/expiry | Authoritative store contract absent; static price is not purchasable product |
| `/info/Honor Wall` | Real owned medal collection; labelled room medal previews | Profile collections | Current-user ownership query | S; final widget suite | Room medal eligibility | No approved server room medal award contract |
| `/info/:title` other title | Generic unavailable fallback | None asserted | None | S | Requested service | No implemented route-specific feature |
| `/reseller`, admin functions | Route constant/repository only; no registered visible reseller/admin screen | reseller/admin RPC repository contracts | No visible router consumer | S; L baseline literal RPC existence | Navigable authorized product workflow | Missing router/screens/permissions interaction; do not claim UI implementation |
| Android voice/listen/microphone/reconnect | Room controls/error/retry/status | voice-token v5; service-only voice_access | Dart/native bridge; explicit anonymous callback keep rules repair JNI exact-name lookup | S; M Dart/native/Edge; L config readiness401; root APK107 R8 evidence showed onVivoxEvent removed | New release DEX callback gate/build and real authenticated audio | Release APK must pass concrete DEX callback gate; genuine session/devices unavailable; config readiness is not audio success |
| iOS voice | Flutter service interface | Same token authorization | Native iOS implementation absent | S | Native SDK/audio integration | No iOS native voice bridge/device evidence |

## Storage and access evidence

Client references avatars, covers, moments, room-images and profile-collectibles. Root freshly read-verified live storage policies: avatar/cover INSERT, UPDATE and SELECT require the user folder; the moments user_upload policy checks its user folder; room-image writes require room ownership; profile-collectible uploads require admin authorization. This supersedes the initial repository-only policy provenance gap. Read-verifying policies does not exercise genuine upload/upsert/download/delete, transport, MIME/size failures or cleanup. Public media URLs imply public read exposure by design; deletion/orphan cleanup is not established by displaying a URL. The prior public-table RLS count alone does not establish Storage access; the separate live policy inspection supplies that evidence. Genuine uploads and device media workflows remain unverified.

## Confirmed connection gaps versus external validation

- `Routes.reseller` is defined but no `/reseller` GoRoute exists; admin/reseller repositories alone are not a user feature.
- `NotificationRepository.registerDevice` has no consumer call site under `lib`; device registration and FCM delivery are missing connections, in addition to provider/device validation.
- The former recharge connection gap is repaired: native IAP/provider gates and Google account binding now connect checkout to verify-purchase v6. Genuine payment/device credit remains unverified and Apple is blocked by the missing server account-token contract.
- Support/preferences/deletion UI is connected and migration is deployed with clone/live metadata evidence. Support operator responses, legally approved drafts and completed account erasure are separate unresolved workflows.
- All seven approved games remain server-disabled. Their visual/demo outcomes and multipliers do not authorize financial rules. Exact gaps are documented in `nimzo/lib/features/games/APPROVED_GAME_CONTRACTS.md`.

## Evidence sources and limitations

Read `nimzo/lib/app/router.dart`, `routes.dart`, all feature repository/service query and RPC references, visible settings/room/game/recharge panels, Edge sources/tests and storage migration policy definitions. Updated deployment/focused-test/storage/native evidence above was supplied by root during this active pass; no full suite was rerun by this author. Existing evidence: `docs/backend/2026-10-08-verification.md`, `docs/voice/2026-10-08-repair-and-deployment.md`, `docs/NIMZO_FINAL_DEVELOPMENT_2026-10-08.md`. Automated tests listed below are source evidence and should be matched to root's final run, not counted as live or device tests.

## Complete source endpoint index

Automatically collected literal table, RPC and Edge references from all `nimzo/lib` files; dynamic room RPC names and storage buckets are recorded separately below. A reference is not proof its route is reachable or live contract is deployed.

| Source | Tables / views | Literal RPCs | Edge functions |
| --- | --- | --- | --- |
| `nimzo/lib/features/admin/admin_repository.dart` | — | admin_reports, admin_set_status | — |
| `nimzo/lib/features/auth/data/auth_service.dart` | room_members | leave_room | — |
| `nimzo/lib/features/discover/discover_screen.dart` | avatars | — | — |
| `nimzo/lib/features/discover/leaderboard_repository.dart` | banners | leaderboard, weekly_star | — |
| `nimzo/lib/features/games/game_repository.dart` | — | play_game | — |
| `nimzo/lib/features/gifts/gift_repository.dart` | gift_events, gifts | send_gift, send_profile_gift | — |
| `nimzo/lib/features/home/home_screen.dart` | room-images | — | — |
| `nimzo/lib/features/messages/message_repository.dart` | messages | conversation_list, mark_read, send_message | — |
| `nimzo/lib/features/messages/messages_screen.dart` | avatars | — | — |
| `nimzo/lib/features/moments/moment_repository.dart` | moment_comments, moment_likes, moments, reports | moments_feed, send_moment_gift, toggle_like | — |
| `nimzo/lib/features/moments/moments_screen.dart` | avatars, moments | — | — |
| `nimzo/lib/features/notifications/notification_repository.dart` | notifications | mark_notifications_read, register_device | — |
| `nimzo/lib/features/profile/me_screen.dart` | avatars, covers | — | — |
| `nimzo/lib/features/profile/profile_collections.dart` | profile_owned_collectibles | — | — |
| `nimzo/lib/features/profile/profile_repository.dart` | couples, models, profile_tags, profiles | profile_gifts, profile_stats, record_visit | — |
| `nimzo/lib/features/recharge/recharge_repository.dart` | recharge_packages | — | verify-purchase |
| `nimzo/lib/features/reseller/reseller_repository.dart` | profiles | reseller_recharge | — |
| `nimzo/lib/features/rooms/data/room_chat_repository.dart` | gift_events, room_members, room_messages | clear_room_chat, send_room_chat | — |
| `nimzo/lib/features/rooms/data/room_extras_repository.dart` | reports, room_members, room_messages | create_room, send_room_message, set_moderator, set_room_password, update_room_settings | — |
| `nimzo/lib/features/rooms/data/room_repository.dart` | mic_seats, profiles, room_members, rooms, rooms_ranked | create_room, follow_room, get_room_moderation, my_rooms | — |
| `nimzo/lib/features/rooms/data/room_settings_repository.dart` | reports, rooms | room_member_list, set_moderator, update_room_settings | — |
| `nimzo/lib/features/rooms/presentation/room_overlays.dart` | avatars, room-images | — | — |
| `nimzo/lib/features/rooms/presentation/room_screen.dart` | avatars, room-images | — | — |
| `nimzo/lib/features/rooms/presentation/room_user_sheet.dart` | avatars | — | — |
| `nimzo/lib/features/settings/user_preferences.dart` | — | update_user_settings, user_settings | — |
| `nimzo/lib/features/social/social_repositories.dart` | blocks, follows, friendships, visitors | accept_friend, record_visit | — |
| `nimzo/lib/features/social/social_screens.dart` | avatars, couple_requests, profiles | respond_couple_request | — |
| `nimzo/lib/features/support/support_repository.dart` | support_tickets | request_account_deletion, submit_support_ticket | — |
| `nimzo/lib/features/vip/vip_repository.dart` | svip_friday_rewards, svip_thresholds, vip_daily_rewards | claim_svip_friday, claim_vip_daily, vip_status | — |
| `nimzo/lib/features/voice/vivox_voice_service.dart` | — | — | voice-token |
| `nimzo/lib/features/wallet/wallet_screen.dart` | wallets | — | — |

Dynamic RoomRepository calls and moderation include join/leave, take/leave seat and kick/ban/mute RPCs through named wrappers; consult the current repository for exact argument contracts. Conditional social tables: visitors/follows; media buckets: avatars/covers. Storage `.from` references are buckets rather than public database tables. Approved games remain server-disabled; no dynamic legacy call establishes approved settlement.

## Automated test source inventory

- `nimzo/test/app_update_service_test.dart`
- `nimzo/test/auth_redirect_test.dart`
- `nimzo/test/backend_targeted_integration_test.dart`
- `nimzo/test/blocked_users_test.dart`
- `nimzo/test/conversation_tile_test.dart`
- `nimzo/test/couple_panel_layout_test.dart`
- `nimzo/test/data_flow_test.dart`
- `nimzo/test/final_master_ui_test.dart`
- `nimzo/test/game_and_economy_test.dart`
- `nimzo/test/game_catalog_test.dart`
- `nimzo/test/game_layout_test.dart`
- `nimzo/test/game_repository_validation_test.dart`
- `nimzo/test/gift_artwork_test.dart`
- `nimzo/test/gift_rejection_test.dart`
- `nimzo/test/gift_retry_test.dart`
- `nimzo/test/gift_room_recipient_test.dart`
- `nimzo/test/gift_settlement_error_test.dart`
- `nimzo/test/home_reference_test.dart`
- `nimzo/test/home_refresh_test.dart`
- `nimzo/test/logout_cleanup_test.dart`
- `nimzo/test/master_overlay_layout_test.dart`
- `nimzo/test/master_visual_preview_test.dart`
- `nimzo/test/message_draft_test.dart`
- `nimzo/test/message_read_refresh_test.dart`
- `nimzo/test/moment_comment_identity_test.dart`
- `nimzo/test/moment_comment_lifecycle_test.dart`
- `nimzo/test/moment_delete_confirmation_test.dart`
- `nimzo/test/moment_editor_retry_test.dart`
- `nimzo/test/moment_gift_contract_test.dart`
- `nimzo/test/moment_gift_refresh_test.dart`
- `nimzo/test/moment_update_contract_test.dart`
- `nimzo/test/notification_interactions_test.dart`
- `nimzo/test/profile_content_test.dart`
- `nimzo/test/profile_gift_refresh_test.dart`
- `nimzo/test/profile_image_format_test.dart`
- `nimzo/test/profile_levels_test.dart`
- `nimzo/test/profile_model_test.dart`
- `nimzo/test/profile_repository_test.dart`
- `nimzo/test/profile_setup_redirect_test.dart`
- `nimzo/test/recharge_checkout_test.dart`
- `nimzo/test/reference/reference_assets_test.py`
- `nimzo/test/reference_design_test.dart`
- `nimzo/test/reference_preview_test.dart`
- `nimzo/test/remaining_interactions_test.dart`
- `nimzo/test/remaining_visual_qa_test.dart`
- `nimzo/test/room_game_host_test.dart`
- `nimzo/test/room_reconnect_test.dart`
- `nimzo/test/room_session_test.dart`
- `nimzo/test/room_user_sheet_test.dart`
- `nimzo/test/security_contract_test.dart`
- `nimzo/test/session_identity_test.dart`
- `nimzo/test/settings_about_test.dart`
- `nimzo/test/social_avatar_test.dart`
- `nimzo/test/support_content_test.dart`
- `nimzo/test/update/native_apk_update_test.py`
- `nimzo/test/user_errors_test.dart`
- `nimzo/test/validators_test.dart`
- `nimzo/test/vip_presentation_test.dart`
- `nimzo/test/vip_tiers_test.dart`
- `nimzo/test/voice/native_response_wait_test.py`
- `nimzo/test/voice/native_voice_contract_test.py`
- `nimzo/test/voice/vivox_voice_service_test.dart`

## Release callback defect evidence

The actual public release107 R8 usage report lists the removed MainActivity listener `onVivoxEvent(String,int,String)`. The native bridge requires this exact name and signature through JNI GetMethodID. Running `tools/verify_vivox_callback.py` on the downloaded107 APK fails because no concrete callback implementation remains. The repair uses an explicit anonymous listener plus narrow keep rules; release packaging must pass the new concrete DEX verification gate. This proves a release artifact defect, not successful physical audio. No connected Android device or genuine authenticated test session was available.

Owner clarification: level thresholds for 1–120 and Active earning rules remain approval-pending; no invented thresholds are deployed. Operator identity/contact/jurisdiction are unconfirmed; legal documents remain review-required drafts.

## Final verification for 1.0.8+108

- dart format: 165 files, zero changes required. flutter pub get and analyzer pass, no analyzer issues. Full Flutter suite: 229 passing tests, no failures. Golden generation/recheck passed; screenshots are fixture-based, not device captures.
- Native voice contract suite: 6 pass; native update handoff contract: 1 pass; tool tests: 3 pass; reference source contract: 1 pass. Edge authorization/payment tests: 16 pass. Provider responses are fixtures, not genuine purchases.
- Postgres17 isolated clone settings/support/gift replay/RLS and moderation suites pass. Reviewed settings/support and room moderation migrations deployed to the linked project; live grants/RLS/function metadata verified. verify-purchase v6 deployed. No production user data/balance test writes.
- Signed release APK build succeeds. Actual DEX callback gate passes for MainActivity$1; permanent certificate matches pinned identity. Package io.nimzo.app; version1.0.8 build108; minSdk24. APK ZIP integrity, packaged three-ABI Vivox libraries, 16KB ZIP alignment and 64-bit Vivox ELF alignment pass.
- APK SHA256: 239dbf2fec3df874ead4ed706a417892303c2e85ebc1ff36715364a825d5e511.
- Signing certificate SHA256: b11d41ae3037f16d639dc606af2ebf0150bf805a204577c7858cc044ff46bb4a. No key regenerated.
- Physical microphone/audio, installer, genuine login session, genuine purchase and iOS native voice remain unverified. GitHub automatic compilation still requires developer-side signing secrets; verified public APK publication uses a separate signature/checksum/native-verified workflow.

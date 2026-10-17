# Full walkthrough evidence and UI continuation

Source: owner-supplied `screen-20261018-001658.mp4`, Drive ID
`1YQ1eqKObPVsQ6YrWDKlNppu_1xoP2Z6l`. Downloaded completely on 2026-10-17 UTC.
See `extraction-summary.json` for byte count, duration and SHA-256.

FFmpeg produced 1,543 quarter-second samples and 541 scene-change candidates
(`scene > 0.08`). These are reference samples, **not** a certification that an
automated detector finds every tap or that four samples per second capture every
animation frame. The original video remains the source for frame-accurate replay.
Contact sheets spanning 00:00–06:20 and the final 06:23–06:25 frames were manually inspected. No proprietary
Tingle graphics have been added to the app or committed as production assets.

## Reproduce

```sh
python tools/ui/extract_tingle_reference.py /path/to/tingle.mp4 /path/outside/repository/evidence
```

The current local evidence is `/workspace/reference/`: `tingle.mp4`,
`frames/frame-00001.jpg` … `frame-01543.jpg`, `states/state-00001.jpg` …,
`full-overview/sheet-01.jpg` … `sheet-03.jpg`, and `index.json`.
Sample number N maps to `(N - 1) / 4` seconds. Scene candidates retain their
original `pts_time` in the index. Do not check the 1.13 GB video into git.

## Timestamp inventory

Intervals are manual navigation landmarks, rounded to seconds; use the indexed
quarter-second frames for exact opening/closing transitions. Repeated scroll
positions, skeletons and modal transitions are retained in the extraction.

| Time | Surface / interaction / state | Visible reference details | NIMZO handling |
|---|---|---|---|
| 00:00–00:03 | Login, terms tap | Lavender fade; logo left of title; white email/password fields; violet Continue | Compact NIMZO identity and fields; **Email/Facebook/Google only**, per owner override |
| 00:03–00:08 | Terms/privacy, vertical scroll, back | White header; black legal paragraphs | Existing NIMZO legal copy retained; Tingle's policy is not copied |
| 00:08–00:14 | Login acceptance, submit, dim/loading | Terms control; violet busy indicator | Existing auth callbacks retained |
| 00:14–00:19 | Profile Details, avatar load, scroll | Center round avatar; lilac page; compact white fields; gender pills; Bio Details | Reduced oversized controls; exposed existing bio editor |
| 00:19–00:24 | Country picker, list scroll, select | White round-top sheet; search; flags in rows | Existing country picker retained |
| 00:24–00:27 | Profile save and Home loading | Disabled/loading submit; room skeleton grid | Existing save/read behavior retained |
| 00:27–00:33 | Daily check-in overlay | Lavender/gold reward grid; yellow CTA; dim room list | Existing check-in UI/action retained; no reward changes |
| 00:33–00:43 | Explore, scroll, banner motion | Light blue/lilac; small tabs; flags; dense two-column room cards; pink Go Live | Gradient/header/card density corrected; verified rooms only |
| 00:43–00:48 | New/PK tabs and reload | Skeletons then populated grid | Existing new-room and PK routes retained |
| 00:48–00:54 | Follow tab, list scroll | Selected Follow white; same dense grid | Existing followed rooms retained |
| 00:54–01:03 | Party list, Follow, scroll | Pink horizontal room rows, member thumbnails, banner carousel | Added Party/Follow directory using existing rooms; Games tab embeds the unchanged existing catalog |
| 01:03–01:07 | Games list | Third Party/Custom tabs; compact pink list rows | Existing games left unchanged |
| 01:07–01:13 | Square/Moments loading/feed | Sky header; small text tabs; white rounded feed cards | Header and feed spacing corrected; existing real post actions |
| 01:13–01:16 | Post Moments, image/text/topic state | White page, small add-photo tile, gray text area, mention row, topic chips | Compact composer; existing upload/save unchanged |
| 01:16–01:19 | Feed back, scroll | Two-photo cards; caption, topic chips, heart/comment/share counts | Existing data model has one image; multi-image parity remains unverified |
| 01:19–01:31 | Conversation, scroll, gift tray | White chat; magenta bubbles; voice/media cards; dark gift tray; quantity controls | Existing messages/gifts untouched; video-call capability excluded |
| 01:31–01:38 | Message inbox, Online tab | Lavender page; small All/Online/Unread pills; official announcement; plain rows; empty illustration | Compact inbox, announcement link, collapsible search; All/Unread only (no fabricated online presence) |
| 01:38–01:43 | My Profile, scroll | Identity/counts/coins/SVIP above 2x4 shortcuts; compact menu below | Corrected order; real balances/stats or unknown markers |
| 01:43–01:47 | Coins, ledger | Orange hero; small recharge row; white history | Frozen wallet/coins implementation retained |
| 01:47–01:50 | Offline Recharge list/search | Country pills; agent rows; contact icons | Existing recharge integrations retained |
| 01:50–01:54 | Top-Up Coins loading/payment cards | Payment gateway strip; two-column price cards | No billing/economy changes |
| 01:54–01:58 | Profile returns, identity tap/loading | Lavender hub | New hierarchy retained |
| 01:58–02:07 | Public profile, Data/other tabs, empty | Large photo cover; offset avatar/stats; horizontal tabs; wealth stripe; gift/fan/info rows | Existing full profile retained; room mini-profile cover/light surface corrected |
| 02:07–02:11 | Friends loading/empty, back | White header; small purple selected tab; search; empty mascot | Added local search, compact header/tabs; no synthetic people |
| 02:11–02:15 | Public profile horizontal tabs | Empty content; selected purple tab moves | Existing supported tabs retained |
| 02:15–02:23 | Edit Profile Details, scroll/save | Same avatar/white field proportions; sticky-looking purple Save | Controls compacted; DOB validation preserved |
| 02:23–02:35 | Ranking Rich/Gift, Daily/Weekly/Monthly, sender/receiver | Blue-purple upper region; white compact vertical rank rows | Removed unrelated large hero/podium; retained supported queries |
| 02:35–02:46 | My Store, Avatar Frame/Party Theme previews, scroll | Small category icons; dense two-column recommendations; preview area/category grid | Removed oversized Collection hero; compact categories; original design previews only |
| 02:46–02:55 | Family list and scroll | Ornate purple photo backdrop; bordered family cards; Create Family | Original purple unavailable-state screen; no invented family records or creation action |
| 02:55–02:59 | Profile to CP loading | Profile hub then purple transition | Existing navigation retained |
| 02:59–03:12 | CP Space top and rewards scroll | Purple/gold heart; counters; paired avatars; locked reward cards | Existing original CP artwork retained; missing proprietary reward art documented |
| 03:12–03:17 | Bind CP confirmation, Friends empty | Purple dialog Cancel/Continue; purple search/list | Added confirmation before existing partner search; no couple/economy changes |
| 03:17–03:22 | Back to hub, SVIP open | Purple page transition | Existing route |
| 03:22–03:44 | SVIP 1–6, scroll, loading | Purple/green/pink/red/blue/teal; ornate avatar hero; 8 identity tiles; 12 privilege icons | Six palettes, compact hero, eight identity previews and twelve privilege previews |
| 03:44–04:11 | Privilege preview carousel, repeated swipes/close | White rounded central popup; preview image; title/body; page indicator | Original icon illustrations; swipe/previous/next/dismiss implemented; no grants/purchases |
| 04:11–04:27 | Profile scroll, menu and back | Compact menu rows; hub banners | Corrected hub order and density |
| 04:27–04:32 | Go Live mode selection | Black video-mode placeholder, Audio Room selection | Audio-only owner restriction: NIMZO goes directly to audio creation |
| 04:32–04:49 | Create Audio Room, keyboard, photo chooser | Mountain gradient; square photo; compact translucent fields; public/private pills; coral Go Live | Compact controls/original mountain drawing; real picker/create unchanged |
| 04:49–04:54 | Room join and empty-seat menu | Plum room; white bottom action sheet; Seat Here/Give/Lock/Mute/Cancel | Existing permission-safe actions; ten seats in 5x2 preserved |
| 04:54–05:02 | Room controls, Games overlay open/close | Plum header/icons; dark grid; violet overlay | Game implementation frozen |
| 05:02–05:07 | Reaction popup, select, close | White round-top sheet; 4+2 yellow expressions with tiny labels | Grid and labels corrected; chosen emoji edits actual outgoing draft |
| 05:07–05:12 | Gift popup, category/quantity, close | Dark tray over room | Existing gifts and economy untouched |
| 05:12–05:22 | In-room mini profile, expand, close | Light profile panel; photo cover; offset avatar; data rows | Added real cover/light panel; existing social and moderation actions preserved |
| 05:22–05:27 | Room/announcement/member states | Small upper banner; chat at bottom | Existing real chat and verified events only |
| 05:27–05:34 | Room settings, scroll, seat mode sheet | White rounded sheet; image/name/welcome; compact rows; seating previews | Existing settings retained; seat count fixed at ten by owner override |
| 05:34–05:44 | Music list, folders, multi-select | White list; purple audio icons; Add Music/Confirm Add | Existing local audio picker/player retained; Vivox unchanged |
| 05:44–05:50 | Exit room popup, cancel/exit | Rounded white dialog; red exit mark; pale Keep/Exit | Existing confirmed-exit behavior retained |
| 05:50–06:06 | Home/hub/Party, scroll | Same gradients/lists | Main screens and Party directory corrected; populated member/avatar and banner parity remains open |
| 06:06–06:14 | Second populated voice room, entrance effect | Dark custom theme; framed avatars; room background animation | Existing themes/effects unchanged; licensed asset parity remains open |
| 06:14–06:23 | Public room profile overlay, expand | Large photo; white stats/profile panel; follow and hello actions | Light cover treatment; supported real actions retained |
| 06:23–06:25.627 | Dismiss/return and recording end | Profile dismissal, ongoing room chat and animated seat effects | Preserved in quarter-second and scene extraction |

## Constraints and remaining acceptance work

This continuation is **not** accepted as pixel-perfect or a complete UI certificate.
The original 23 screenshot files were not present in this workspace; their committed
reference map was consulted. Existing repo goldens are previous NIMZO screenshots,
not evidence that those images match Tingle. Proprietary 3D frames, mascots,
entrance art, animated banners, multi-image posts, populated Party/Family states, and all
fine icon/motion timing differences remain explicit review gaps. No backend,
authentication controller, wallet, economy, database, game or Vivox source is
changed. No APK/AAB is built or published. Backend remains blocked until owner
explicit authorization after UI review.

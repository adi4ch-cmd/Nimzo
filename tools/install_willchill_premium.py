#!/usr/bin/env python3
"""Install user-provided WillChill preview media into the existing NIMZO 1.0.36 repo.

Run from NIMZO repo root AFTER unpacking WillChill_NIMZO_Premium_Integration.zip
at the repository root. Never deletes/replaces gifts, profiles or Supabase tables.
"""
from pathlib import Path
import sys

repo=Path.cwd()
flutter=repo/'nimzo'
lock=flutter/'FEATURES.lock.json'
if not lock.exists() or not (flutter/'lib/app/router.dart').exists():
    sys.exit('ERROR: run at NIMZO repository root (nimzo/FEATURES.lock.json required).')
if not (flutter/'assets/willchill_premium/catalog.json').exists():
    sys.exit('ERROR: premium assets are not unpacked. No changes made.')
if not (flutter/'lib/features/premium/willchill_premium_screen.dart').exists():
    sys.exit('ERROR: premium Dart gallery missing. No changes made.')

pubspec = flutter/'pubspec.yaml'
router = flutter/'lib/app/router.dart'
store = flutter/'lib/features/store/store_live_catalog.dart'
paths=[pubspec,router,store]
original={p:p.read_text(encoding='utf-8') for p in paths}
updated=dict(original)

# Flutter asset bundles are NOT recursive: declare all categories explicitly.
asset_lines=[
  '    - assets/willchill_premium/catalog.json',
  '    - assets/willchill_premium/audio/',
  '    - assets/willchill_premium/entrances/',
  '    - assets/willchill_premium/games/',
  '    - assets/willchill_premium/gifts/',
  '    - assets/willchill_premium/room_fx/',
  '    - assets/willchill_premium/store/',
  '    - assets/willchill_premium/svip/',
  '    - assets/willchill_premium/vip/',
]
for line in asset_lines:
    if line not in updated[pubspec]:
        # Append to existing assets list, before the end of YAML file.
        if '    - assets/room_rocket/posters/' not in updated[pubspec]:
            sys.exit('ERROR: cannot find expected pubspec Flutter assets anchor.')
        updated[pubspec]=updated[pubspec].replace('    - assets/room_rocket/posters/',
            '    - assets/room_rocket/posters/\n'+line,1)

import_line="import '../features/premium/willchill_premium_screen.dart';"
if import_line not in updated[router]:
    anchor="import '../features/store/store_screen.dart';"
    if anchor not in updated[router]:
        sys.exit('ERROR: router.dart was changed; check import manually.')
    updated[router]=updated[router].replace(anchor,anchor+'\n'+import_line,1)

svip_before="GoRoute(path: '/svip', redirect: (_, __) => Routes.profile),"
svip_after="GoRoute(path: '/svip', builder: (_, __) => const WillChillPremiumScreen(initialGroup: 'svip'))," 
if svip_before in updated[router]:
    updated[router]=updated[router].replace(svip_before,svip_after,1)
elif svip_after not in updated[router]:
    sys.exit('ERROR: unknown /svip route; no changes made.')
vip_before="GoRoute(path: Routes.vip, redirect: (_, __) => Routes.profile),"
vip_after="GoRoute(path: Routes.vip, builder: (_, __) => const WillChillPremiumScreen(initialGroup: 'vip'))," 
if vip_before in updated[router]:
    updated[router]=updated[router].replace(vip_before,vip_after,1)
elif vip_after not in updated[router]:
    sys.exit('ERROR: unknown VIP route; no changes made.')

store_import="import '../premium/willchill_premium_screen.dart';"
if store_import not in updated[store]:
    anchor="import 'package:flutter_riverpod/flutter_riverpod.dart';"
    if anchor not in updated[store]:sys.exit('ERROR: store import anchor missing.')
    updated[store]=updated[store].replace(anchor,anchor+'\n'+store_import,1)
button="""          IconButton(
            tooltip: 'Preview premium media',
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => const WillChillPremiumScreen(),
              ),
            ),
          ),
"""
if "tooltip: 'Preview premium media'" not in updated[store]:
    anchor="          IconButton(\n            tooltip: 'Refresh Store',"
    if anchor not in updated[store]:sys.exit('ERROR: expected refresh button absent; store was changed.')
    updated[store]=updated[store].replace(anchor,button+anchor,1)

# Validate all inputs before writing a single source file.
assert all('assets/willchill_premium/' in updated[p] for p in (pubspec,))
assert 'WillChillPremiumScreen' in updated[router]
assert "tooltip: 'Preview premium media'" in updated[store]
for p in paths:
    if original[p]!=updated[p]:
        p.write_text(updated[p],encoding='utf-8')
        print('PATCHED',p)
    else:
        print('UNCHANGED',p)
print('Assets + SVIP/VIP preview routes registered. Existing Store, coins, grants, gifts and Rocket untouched.')
print('IMPORTANT: before release run flutter pub get, flutter analyze, flutter test, device/VAP/Vivox coexistence checks.')

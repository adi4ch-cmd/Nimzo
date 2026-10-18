#!/usr/bin/env python3
"""Build review thumbnails and annotated pairs; never writes golden baselines.

Inputs are screenshots from NIMZO_CAPTURE_DIR and the targeted video frames
(named NNN.jpg). Requires Pillow. Originals stay outside the repository.
"""
import argparse
import html
import textwrap
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps

PAIRS = [
    (1, 'login', 'Email/Facebook/Google only. Mobile and Quick Login intentionally excluded; original NIMZO identity.'),
    (17, 'profile-details', 'Compact fields, avatar, gender and sticky Save. Real profile fields retained; no age or ID fabricated.'),
    (30, 'checkin-unavailable', 'Attendance unavailable in this fixture; no synthetic rewards shown. Live claim behavior unchanged.'),
    (37, 'home', 'Explore hierarchy and country chips retained. Empty rooms instead of fabricated people, banners or counters.'),
    (47, 'home-country-filter', 'Searchable country filter opens and dismisses. Native keyboard and emoji flags require Android QA.'),
    (57, 'party', 'Horizontal Party rows use existing rooms. This fixture is empty; no invented member thumbnails.'),
    (72, 'moments', 'Original empty mascot; Square/Follow retained. Actual model supports one image per post.'),
    (76, 'composer', 'Compact photo tile, text area, Mention/topic chips and header Post. Duplicate large bottom action removed.'),
    (94, 'messages', 'Compact inbox/search, original mascot. All/Unread only: presence data does not support Online.'),
    (101, 'profile', 'Compact eight shortcuts and original SVIP banner crest. Balances explicitly unavailable in fixture.'),
    (120, 'public-profile', 'Real identity/stats/collections remain; cover geometry is existing NIMZO layout, not pixel parity.'),
    (129, 'friends', 'Compact tabs/search with original mascot. No synthetic friends or presence.'),
    (139, 'profile-details', 'Sticky Save remains visible while details scroll; no profile contract changes.'),
    (153, 'ranking-tabs', 'Supported Wealth/Charm weekly/monthly queries retained. Unsupported ranking modes explicitly unavailable.'),
    (158, 'store', 'Original two-column design gallery, category art, preview-only labels; verified medal catalog remains separate.'),
    (174, 'family', 'Original purple palace backdrop and mascot. Family directory and Create remain explicitly unavailable.'),
    (188, 'cp-gallery', 'Original decorative CP rewards with inspectable preview dialogs; no invented tiers, durations or claim action.'),
    (224, 'membership-tier-6', 'Tier six teal palette and original crest; all six tiers remain viewable without granting membership.'),
    (304, 'room-reactions', 'Reaction picker opens, selection updates the outgoing draft, and dismisses without sending a message.'),
    (344, 'room-music', 'Compact local playback presentation; native file picking and actual audio require device verification.'),
    (350, 'room-exit', 'White confirmation with Keep/Exit actions; cancel keeps room session alive.'),
    (183, 'cp', 'Original heart crest and reward gallery. Unknown relationship duration stays unknown; no reward claims.'),
    (207, 'membership-tier-1', 'Original winged crest instead of a generic medal/diamond. Tier 1 purple; preview only.'),
    (218, 'membership-tier-4', 'Six tier palettes retained, including red tier 4. Original art, not a copy of proprietary 3D assets.'),
    (238, 'membership-perk-17', 'All 20 popup pages navigable; square art and compact height fixed; close/previous/next retained.'),
    (275, 'create-room', 'Audio-only creation. Original mountain treatment and existing real media picker/create action retained.'),
    (294, 'room-seat-sheet', 'Seat actions preserved; disabled permission-safe moderation entries; Cancel keeps room joined.'),
    (307, 'room', 'Exactly ten custom microphone-chair tiles in 5x2, not the reference 12. No fabricated room occupants.'),
    (318, 'secondary-public_profile', 'Profile data/collections and supported deep content retained; original cover arrangement differs.'),
    (330, 'secondary-room_settings', 'Existing settings controls and handlers preserved. Ten-seat requirement remains fixed.'),
    (340, 'room-music', 'Compact local music sheet retained. Imported-track controls remain unchanged; no Vivox changes.'),
    (348, 'room-exit', 'White exit confirmation and cancellation verified. Native Android back/device behavior still needs owner test.'),
    (370, 'store-Rides', 'Original entrance vehicle preview has bounded replay and reduced-motion support. Not an equipped entrance effect.'),
    (379, 'mini-profile', 'Room profile presentation captured separately; real room member/photo parity is not certified.'),
]


def normalized(path, size=(360, 800)):
    image = Image.open(path).convert('RGB')
    return ImageOps.pad(image, size, color='#eeeaf6', method=Image.Resampling.LANCZOS)


def build(captures, reference, output):
    output.mkdir(parents=True, exist_ok=True)
    shots = output / 'screens'
    shots.mkdir(exist_ok=True)
    names = []
    for path in sorted(captures.glob('*.png')):
        destination = shots / f'{path.stem}.webp'
        if destination.exists() and destination.stat().st_mtime >= path.stat().st_mtime:
            names.append(path.stem)
            continue
        im = Image.open(path).convert('RGB')
        im.thumbnail((540, 1200), Image.Resampling.LANCZOS)
        im.save(destination, quality=82, method=0)
        names.append(path.stem)
    rows = []
    sections = []
    for seconds, stem, note in sorted(PAIRS):
        actual = captures / f'{stem}-360.png'
        if not actual.exists():
            actual = captures / f'{stem}-390.png'
        source = reference / f'{seconds:03}.jpg'
        if not actual.exists() or not source.exists():
            rows.append(f'| {seconds//60:02}:{seconds%60:02} | {stem} | Missing capture; not verified | {note} |')
            continue
        card = Image.new('RGB', (744, 954), 'white')
        draw = ImageDraw.Draw(card)
        draw.text((12, 10), f'Reference {seconds//60:02}:{seconds%60:02}', fill='#351745')
        draw.text((384, 10), f'NIMZO {actual.stem.rsplit("-",1)[-1]}dp', fill='#351745')
        card.paste(normalized(source), (6, 32))
        card.paste(normalized(actual), (378, 32))
        draw.line((371, 32, 371, 832), fill='#a243f5', width=2)
        wrapped = textwrap.wrap(note, width=100)
        for idx, line in enumerate(wrapped):
            draw.text((12, 847 + idx * 17), line, fill='#351745')
        filename = f'compare-{seconds:03}-{stem}.webp'
        card.save(output / filename, quality=85, method=0)
        stamp=f'{seconds//60:02}:{seconds%60:02}'
        rows.append(f'| {stamp} | {stem} | [Annotated comparison]({filename}) | {note} |')
        sections.append(f'<figure><a href="{filename}"><img loading="lazy" src="{filename}" alt="{html.escape(stem)} at {stamp}"></a><figcaption>{stamp} · {html.escape(stem)}</figcaption></figure>')
    (output / 'comparison-matrix.md').write_text('''# Issue 15 visual comparison matrix

Reference: owner video, 385.626822s. Pairs use targeted timestamps from the existing inventory, not another full extraction.
NIMZO captures are headless Flutter test fixtures, not real account/device photographs. Empty and unavailable data are intentional.
Images are normalized with aspect-preserving padding to 360×800; secondary fixture captures retain their existing 390×844 aspect ratio.
Comparison cards annotate actual differences and owner-required deviations; they are not equality or pixel-parity certificates.
The source 23 PNG files remain absent; their committed filename map was cross-referenced, not marked visually verified.

| Video | NIMZO surface | Evidence | Difference / verification |
|---|---|---|---|
'''+'\n'.join(rows)+'\n')
    (output / 'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>NIMZO issue 15 review</title><style>body{font:14px system-ui;background:#f3eff8;color:#281434;margin:24px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:20px}figure{margin:0}img{width:100%;height:auto;border-radius:8px}figcaption{padding:8px}h1{font-size:24px}</style><h1>NIMZO UI device-test review</h1><p>Headless test fixtures; reference differences are annotated. Physical-device parity remains unverified. No screenshot is a purchase or entitlement claim.</p><main>'''+''.join(sections)+'</main><h2>All captured states</h2><ul>'+''.join(f'<li><a href="screens/{html.escape(n)}.webp">{html.escape(n)}</a></li>' for n in names)+'</ul></html>')
    print(f'{len(names)} captures, {len(sections)} comparison pairs')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures', type=Path)
    parser.add_argument('reference', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    build(args.captures, args.reference, args.output)

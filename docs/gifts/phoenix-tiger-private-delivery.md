# Phoenix and Holy Tiger — private delivery

Four approved gifts: Hall of Fame at 500,000 coins; Dragon Throne, Ice Fire Phoenix and Holy Tiger at 1,000,000 coins each. Tiger uses the corrected
unmuted second replay soundtrack. Animation and thumbnail bytes stay outside
the public repository and APK bundle.

The gift-media gateway validates a signed-in active account. Animation links
require a recent server-settled event visible through the viewer's event RLS,
or the viewer's own recent negative gift ledger receipt. Thumbnail links
require login. Exact fixed paths in a private bucket receive 60-second signed
URLs. Anonymous access, unverified payments and arbitrary paths are rejected.
The existing VAP network player handles transparent playback. Existing server
RPCs remain responsible for coin settlement; no client price is authoritative.

Deployment state: all four animations and thumbnails uploaded to the private
NIMZO Supabase bucket. The temporary exact-file upload bootstrap is removed
following successful ingestion. Source publishing is explicitly owner-approved.
Activation uses the existing catalog and existing server settlement RPCs.
No APK is built by this source-only QA workflow. An updated client is required
for new gift identities and private media playback. Native device/Vivox QA is
still required; backend activation alone cannot update an installed old APK.

Runtime interception or recording remains possible; private delivery is not DRM
and cannot make rendered gifts completely copy-proof.

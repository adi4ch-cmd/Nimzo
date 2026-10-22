# v3 Codespace SDK and voice evidence — 2026-10-21

Status: **BLOCKED for actual SDK compatibility and runtime voice acceptance**.
The owner confirms the SDK exists in the existing GitHub Codespace. The results
below establish the current session's visibility, not SDK absence. No APK, AAB
or IPA was built; the build helper's main entry point was not invoked.

## Authorized access evidence

- `gh api user --jq '{login,id}'`: authenticated as `adi4ch-cmd`, ID 317117926.
- `gh api user/codespaces`: HTTP success, `total_count: 0`, empty list. This is
  only the current integration's returned visibility.
- `gh api repos/adi4ch-cmd/Nimzo/codespaces`: **HTTP 403**, exact message
  `Resource not accessible by integration`.
- `gh codespace list --repo adi4ch-cmd/Nimzo --json name,state,repository`:
  **HTTP 403**, `Resource not accessible by integration` on the repository
  Codespaces endpoint. No Codespace name was available for a read-only remote
  shell session; no Codespace was created, stopped, deleted or reset.
- The connected GitHub `get_repo` succeeds for `adi4ch-cmd/Nimzo`, repository
  ID 1394453334, with repository admin/pull/push permissions. Repository
  access does not establish permission to access Codespace machines.
- Tool discovery exposes GitHub repository operations but no Codespace listing,
  remote shell or attached-machine filesystem tool.
- The cloud environment status reports a running managed **cloud** environment,
  current observations, unrestricted/enforced HTTP access, and no configured
  secrets, runtime variables, outbound identities or capabilities. The local
  policy has `vpn_configured: false` and no permitted TCP domains/ranges. This
  describes this workspace, not the owner's existing Codespace.

## Local SDK search

Only SDK filenames were searched, without reading credential/private files.
`Vxc.h`, AARs and `libvivox-sdk.so`/`libvivoxsdk.so` did not match under
`/workspace` (Git history/generated build caches excluded).

The helper's known roots do not exist in this environment:
`/tmp/vivox/android`, `/tmp/vivox`, `/workspaces/nimzo-premium-qa`,
`/workspaces/Nimzo`, `/workspaces/nimzo`, `/workspaces`, `/opt/vivox`,
`/home/agent/vivox`, `/home/agent/sdk`.
The native Vivox source directories in `/workspace/Nimzo-v3`, `/workspace/Nimzo`
and `/workspace/Nimzo-integration` contain bridge source, not the SDK filenames.
No proprietary header/AAR/ELF was accessible for validation or redistribution.

## Concrete source hardening

`tools/validate_vivox_sdk.py` provides an independent read-only validator:

```bash
python3 tools/validate_vivox_sdk.py --header /SDK/include/Vxc.h \
  --aar /SDK/sdk-release.aar --native /SDK/arm64-v8a/libvivox-sdk.so \
  --abi arm64-v8a
```

This command does not build or extract files. It requires the six bridge header
files together, checks ELF magic/class/little-endian architecture/ET_DYN/header
size, the AAR's `classes.jar` and `com/vivox/sdk/JniHelpers.class`, the requested
ABI's Vivox library, and byte identity between loose and packaged libraries.
Duplicate relevant ZIP entries and oversized members are rejected. It returns
input paths and SHA256 digests, without emitting SDK bytes.

This is a packaging consistency check, not proof of matching header/API version,
Java method signatures, exported dynamic symbols, license authorization, a fully
loadable ELF, or working audio. Those require the actual SDK and later approved
device validation. Synthetic fixtures must never be presented as vendor SDK proof.

The CMake source now requires one `Vxc.h` and its sibling headers, an explicit
Android ABI and exactly one native library in that ABI's directory. It fails
instead of silently falling back to a different ABI or choosing between releases.
The Python validator independently inspects the actual ELF architecture because
directory names alone cannot prove ABI. A narrowly selected SDK root is required.

## JNI and audio source findings

- Six Java native declarations exactly match the six JNI export names.
  Callback lookup uses `(Ljava/lang/String;ILjava/lang/String;)V`; R8 keep rules
  retain the interface and concrete callback implementation.
- Java imports `com.vivox.sdk.JniHelpers` and calls `init(context)` before native
  initialization. Actual SDK Java class/method and native API compatibility are
  blocked until the owner-confirmed SDK is accessible.
- Anonymous login uses separately server-issued login/channel access tokens and
  the account name derived from the signed SIP identity. Initial mic muting waits
  for its SDK response; a join response alone is not treated as media connectivity.
  Dart waits for `audioConnected`, handles native errors/timeouts, and requests
  fresh server authorization before enabling capture.
- Native calls execute on the serial Java worker. Native response waits use wall
  time and dispatch queued events; response handle strings are copied before the
  SDK messages are destroyed. Safe diagnostics use stages/status, not token bodies.
- Android requests RECORD_AUDIO and, during a new microphone permission request
  on Android 12+, optional BLUETOOTH_CONNECT. If RECORD_AUDIO is already granted,
  that path does not request missing Bluetooth permission. This is an observed
  source limitation; headset routing remains a device acceptance requirement.
- `setSpeaker` controls Vivox speaker mute, not a proven Android route selector.
  No app-level AudioManager route/focus implementation was found in this bridge;
  actual SDK-managed routing and coexistence with Gift/Rocket audio require device
  evidence. No unsupported routing fix was guessed without SDK/device access.

## Verification and remaining acceptance

`python3 -m unittest discover -s nimzo/test/voice -p '*test.py' -v`:
**7 passed**. These exercise source contracts plus host-compiled extracted queue
wait/stage functions with synthetic SDK messages; they do not compile the full
JNI bridge against proprietary headers.

`python3 -W error::ResourceWarning -m unittest discover -s tools -p test_validate_vivox_sdk.py -v`:
**9 passed, 1 skipped** at this checkpoint. Fixtures cover valid arm64 packaging,
wrong ELF machine, truncated ELF, executable instead of shared object, mismatched
AAR/native bytes, missing ABI/helper/header and duplicate archive members.
The configure-only CMake behavior fixture was skipped because `cmake` is absent
from PATH and the checked standard Android SDK/CMake locations. No CMake build
command is part of that fixture. Flutter voice tests are delegated to the root's
central no-APK dependency/test setup; this file does not claim their outcome.

Required next evidence is authorized read-only access to the existing Codespace
or its SDK root, then actual header/AAR/ELF and linkage verification. Later, only
after the master pre-build gate permits the integrated final artifact, acceptance
must cover two real users, all 15 seats, join/leave/reconnect, mic deny/grant,
host/moderator transmission authorization, wired/Bluetooth routing, background/
foreground, logout/login, and simultaneous Gift/Rocket playback. These are
**BLOCKED/unverified**, not PASS based on source checks. Preserve the existing
Codespace, all local worktrees and uncommitted work; do not publish SDK bytes.


## Owner update
The owner explicitly deferred Vivox ("vivox abi skip kro") and subsequently authorized a TEST APK after dynamic source/backend completion. Codespace access is not required for that QA build. Voice remains required for final full-task acceptance; no claim of SDK absence or working native voice is made.

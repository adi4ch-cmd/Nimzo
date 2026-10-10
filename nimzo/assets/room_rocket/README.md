# NIMZO Room Rocket - 6 levels / 12 VAP clips
The old Diamond Blast room UI is retired; its database progress and ledger records
are retained to avoid affecting settled gift transactions and older APK installs.

Install the extracted, user-provided Haza 4.9.0 media from
NIMZO_Room_Rocket_12_VAP_Assets.zip into nimzo/assets/room_rocket/.
Reward assets are vap_rocket_reward_1.mp4 through vap_rocket_reward_6.mp4,
and optional lead-ins are vap_rocket_fly_1.mp4 through vap_rocket_fly_6.mp4.

Verified reward SHA-256 hashes, in level order:
1 0188090003c1f42bfb1d47e352b62f15ca67c0931864af57b6a7a881d76b115e
2 1cf36d4a7ec75216e4a74ede6375a842f009d7613507f0e04a83a90cd57b5f38
3 352642effd22491cff2bed42cb74ff989f0a18764af628bf5394a09e991c122b
4 cffd9eab89d89977800db96c3cccdc4d6fad2d88b22d46c866e81f995140924d
5 744bd8f9b9608c9d72d3d3639f49b86d43e0e4d627a86151c3b774948b021ae9
6 146aea9c91eefe10dc0802a7da838b4b53a2629667fe71fd6ae89005a17deb92

These videos are Tencent VAP with encoded transparency/masks and require native
VAP playback; normal video_player rendering would expose the mask. The playback
is muted to protect voice communication.

IMPORTANT: This repository has no binary upload path through the currently
available GitHub connector. This README is also a placeholder so the directory
exists for Flutter dependency resolution. A final APK must not be built until
the original clips are committed and validated with the media audit.

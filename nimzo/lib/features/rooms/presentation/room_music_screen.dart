import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

/// Local, user-selected music. This does not claim to broadcast media into
/// Vivox: shared-room audio requires a separately authorized mixer/relay.
class RoomMusicScreen extends StatefulWidget {
  const RoomMusicScreen({super.key});

  @override
  State<RoomMusicScreen> createState() => _RoomMusicScreenState();
}

class _RoomMusicScreenState extends State<RoomMusicScreen> {
  final player = AudioPlayer();
  final tracks = <PlatformFile>[];
  int? playingIndex;
  bool busy = false;
  double volume = .55;
  String? error;

  Future<void> importTracks() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
        withData: false,
      );
      if (selection == null) return;
      final usable = selection.files.where((f) =>
        f.path != null && f.path!.isNotEmpty).toList();
      setState(() {
        tracks.addAll(usable);
        error = usable.isEmpty
            ? 'The selected audio could not be opened.'
            : null;
      });
    } catch (_) {
      if (mounted) setState(() =>
        error = 'Could not open audio files from this device.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> playTrack(int index) async {
    if (busy) return;
    if (index < 0 || index >= tracks.length) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await player.stop();
      await player.setFilePath(tracks[index].path!);
      await player.setVolume(volume);
      if (!mounted) return;
      setState(() => playingIndex = index);
      unawaited(player.play().catchError((Object _) {
        if (mounted) {
          setState(() => error = 'Could not play this audio file.');
        }
      }));
    } catch (_) {
      if (mounted) setState(() {
        error = 'This audio file is unsupported or inaccessible.';
        playingIndex = null;
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff6f4ff),
    appBar: AppBar(
      title: const Text('Music', style: TextStyle(
        color: Color(0xff2f2149), fontWeight: FontWeight.w900)),
      centerTitle: true,
      backgroundColor: Colors.white,
    ),
    body: ListView(
      key: const ValueKey('room-real-audio-library'),
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff6434b3), Color(0xffa94de8),
                Color(0xffbc71e9)]),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(children: [
            const Icon(Icons.music_note_rounded,
              size: 50, color: Color(0xffffdb96)),
            const SizedBox(height: 11),
            Text(
              playingIndex == null
                  ? 'Nothing playing'
                  : tracks[playingIndex!].name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = player.duration ?? Duration.zero;
                final total = duration.inMilliseconds;
                final progress = total == 0
                    ? 0.0
                    : (position.inMilliseconds / total).clamp(0.0, 1.0);
                return Slider(
                  key: const ValueKey('music-playback-seek'),
                  value: progress,
                  activeColor: const Color(0xffffd59a),
                  inactiveColor: const Color(0x88ffffff),
                  onChanged: playingIndex == null || total == 0
                      ? null
                      : (value) => player.seek(
                          Duration(milliseconds: (total * value).round())),
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous track',
                  onPressed: busy || playingIndex == null
                    || playingIndex! <= 0 ? null
                    : () => playTrack(playingIndex! - 1),
                  icon: const Icon(Icons.skip_previous_rounded,
                    color: Colors.white, size: 33),
                ),
                const SizedBox(width: 18),
            StreamBuilder<bool>(
              stream: player.playingStream,
              builder: (context, snapshot) {
                final playing = snapshot.data ?? false;
                return IconButton.filledTonal(
                  tooltip: playing ? 'Pause' : 'Play',
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xff762bc4),
                    backgroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white38),
                  onPressed: playingIndex == null || busy
                      ? null
                      : () => playing ? player.pause() : player.play(),
                  icon: Icon(playing
                      ? Icons.pause_rounded : Icons.play_arrow_rounded),
                );
              },
            ),
                const SizedBox(width: 18),
                IconButton(
                  tooltip: 'Next track',
                  onPressed: busy || playingIndex == null
                    || playingIndex! >= tracks.length - 1 ? null
                    : () => playTrack(playingIndex! + 1),
                  icon: const Icon(Icons.skip_next_rounded,
                    color: Colors.white, size: 33),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(children: [
              const Icon(Icons.volume_down_rounded,
                color: Colors.white70),
              Expanded(child: Slider(
                key: const ValueKey('music-volume'),
                activeColor: const Color(0xffffd69d),
                inactiveColor: const Color(0x77ffffff),
                value: volume,
                onChanged: (value) {
                  setState(() => volume = value);
                  unawaited(player.setVolume(value));
                },
              )),
              const Icon(Icons.volume_up_rounded,
                color: Colors.white70),
            ]),
          ]),
        ),
        const SizedBox(height: 17),
        FilledButton.icon(
          key: const ValueKey('music-add-from-phone'),
          onPressed: busy ? null : importTracks,
          icon: const Icon(Icons.library_music_outlined),
          label: Text(busy ? 'Loading…' : 'Choose Music From Phone'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xff933be9),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Personal playback only. This plays on your phone; it is not '
          'yet broadcast to other room members.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xff867397)),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center),
        ],
        const SizedBox(height: 18),
        if (tracks.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No music selected. Add your own audio files to play them.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (var index = 0; index < tracks.length; index++)
            Card(
              child: ListTile(
                key: ValueKey('music-track-$index'),
                leading: const Icon(Icons.audiotrack,
                  color: Color(0xffa145ee)),
                title: Text(tracks[index].name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: playingIndex == index
                    ? const Text('Selected')
                    : null,
                onTap: busy ? null : () => playTrack(index),
                trailing: Icon(
                  playingIndex == index
                      ? Icons.equalizer_rounded
                      : Icons.play_circle_outline_rounded,
                ),
              ),
            ),
      ],
    ),
  );
}

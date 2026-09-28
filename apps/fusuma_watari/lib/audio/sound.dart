import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum Sfx { step, slide, swing, key, serve, bump, clear, undo, tap }

/// Sound effects and background music. All failures are swallowed: a game
/// must keep running on devices where audio is unavailable.
abstract class Sound {
  void play(Sfx sfx);
  void setEnabled({required bool sfx, required bool music});
  void pauseMusic();
  void resumeMusic();
  void dispose();
}

class SilentSound implements Sound {
  @override
  void play(Sfx sfx) {}
  @override
  void setEnabled({required bool sfx, required bool music}) {}
  @override
  void pauseMusic() {}
  @override
  void resumeMusic() {}
  @override
  void dispose() {}
}

class PluginSound implements Sound {
  PluginSound() {
    _init();
  }

  static const _voices = 3;
  final Map<Sfx, List<AudioPlayer>> _pool = {};
  final Map<Sfx, int> _next = {};
  AudioPlayer? _bgm;
  bool _sfxOn = false;
  bool _musicOn = false;
  bool _musicPlaying = false;
  bool _ready = false;

  Future<void> _init() async {
    try {
      // Mix with other apps and respect the iOS silent switch.
      await AudioPlayer.global.setAudioContext(AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
        respectSilence: true,
      ).build());
      for (final s in Sfx.values) {
        final players = <AudioPlayer>[];
        for (var i = 0; i < _voices; i++) {
          final p = AudioPlayer();
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setSource(AssetSource('audio/${s.name}.wav'));
          players.add(p);
        }
        _pool[s] = players;
        _next[s] = 0;
      }
      final bgm = AudioPlayer();
      await bgm.setReleaseMode(ReleaseMode.loop);
      await bgm.setVolume(0.24);
      await bgm.setSource(AssetSource('audio/bgm.wav'));
      _bgm = bgm;
      _ready = true;
      _applyMusic();
    } catch (e) {
      debugPrint('audio unavailable: $e');
    }
  }

  @override
  void play(Sfx sfx) {
    if (!_sfxOn || !_ready) return;
    final players = _pool[sfx];
    if (players == null) return;
    final i = _next[sfx]!;
    _next[sfx] = (i + 1) % players.length;
    final p = players[i];
    p.seek(Duration.zero).then((_) => p.resume()).catchError((_) {});
  }

  @override
  void setEnabled({required bool sfx, required bool music}) {
    _sfxOn = sfx;
    _musicOn = music;
    _applyMusic();
  }

  void _applyMusic() {
    final bgm = _bgm;
    if (bgm == null) return;
    if (_musicOn && !_musicPlaying) {
      _musicPlaying = true;
      bgm.resume().catchError((_) {});
    } else if (!_musicOn && _musicPlaying) {
      _musicPlaying = false;
      bgm.pause().catchError((_) {});
    }
  }

  @override
  void pauseMusic() {
    if (_musicPlaying) _bgm?.pause().catchError((_) {});
  }

  @override
  void resumeMusic() {
    if (_musicPlaying) _bgm?.resume().catchError((_) {});
  }

  @override
  void dispose() {
    for (final ps in _pool.values) {
      for (final p in ps) {
        p.dispose();
      }
    }
    _bgm?.dispose();
  }
}

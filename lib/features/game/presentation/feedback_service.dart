import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart';

import '../../settings/settings_controller.dart';

enum SoundEffect {
  cardDeal,
  cardFlip,
  chip,
  bet,
  raise,
  fold,
  click,
  timerWarning,
  win,
  lose,
  roomJoin,
  gameStart,
}

enum MusicTrack { lobby, table, victory }

/// Sound abstraction so tests can swap in a silent or recording implementation.
abstract interface class SoundService {
  void play(SoundEffect effect);
  void playMusic(MusicTrack track);
  void stopMusic();
}

/// Plays the bundled `assets/audio/*.wav` effects. Each effect keeps its own low-latency
/// player so rapid sounds (chips, deals) can overlap instead of cutting each other off.
class AudioSoundService implements SoundService {
  final _players = <SoundEffect, AudioPlayer>{};
  var _broken = false;

  static const _files = {
    SoundEffect.cardDeal: 'card_deal.wav',
    SoundEffect.cardFlip: 'card_flip.wav',
    SoundEffect.chip: 'chip.wav',
    SoundEffect.bet: 'bet.wav',
    SoundEffect.raise: 'raise.wav',
    SoundEffect.fold: 'fold.wav',
    SoundEffect.click: 'click.wav',
    SoundEffect.timerWarning: 'timer_warning.wav',
    SoundEffect.win: 'win.wav',
    SoundEffect.lose: 'lose.wav',
    SoundEffect.roomJoin: 'room_join.wav',
    SoundEffect.gameStart: 'game_start.wav',
  };

  @override
  void play(SoundEffect effect) {
    if (_broken) return;
    _play(effect);
  }

  Future<void> _play(SoundEffect effect) async {
    try {
      final player = _players.putIfAbsent(effect, () {
        final p = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
        p.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build(),
        );
        return p;
      });
      await player.stop();
      await player.play(AssetSource('audio/${_files[effect]}'));
    } catch (e) {
      // No audio backend (tests, unsupported platform): stay silent rather than crash.
      _broken = true;
      debugPrint('Sound disabled: $e');
    }
  }

  @override
  void playMusic(MusicTrack track) {}

  @override
  void stopMusic() {}
}

final soundServiceProvider = Provider<SoundService>(
  (ref) => AudioSoundService(),
);

/// Turns engine events into sound + haptics, honouring the user's settings.
class FeedbackService {
  FeedbackService(this._ref);
  final Ref _ref;

  void play(SoundEffect e) {
    if (_ref.read(settingsProvider).sound) {
      _ref.read(soundServiceProvider).play(e);
    }
  }

  void haptic(void Function() h) {
    if (_ref.read(settingsProvider).vibration) h();
  }

  void click() {
    play(SoundEffect.click);
    haptic(HapticFeedback.selectionClick);
  }

  void timerWarning() {
    play(SoundEffect.timerWarning);
    haptic(HapticFeedback.lightImpact);
  }

  void onEvents(List<GameEvent> events, String me) {
    for (final e in events) {
      switch (e.type) {
        case GameEvent.cardsDealt:
          play(SoundEffect.gameStart);
          play(SoundEffect.cardDeal);
          haptic(HapticFeedback.lightImpact);
        case GameEvent.playerSeen:
          play(SoundEffect.cardFlip);
        case GameEvent.playerBet:
          final raise = e.data['kind'] == 'RAISE';
          play(raise ? SoundEffect.raise : SoundEffect.bet);
          play(SoundEffect.chip);
          if (e.playerId == me) {
            haptic(
              raise ? HapticFeedback.mediumImpact : HapticFeedback.lightImpact,
            );
          }
        case GameEvent.playerFolded:
          play(SoundEffect.fold);
        case GameEvent.gameEnded:
          final won = (e.data['winnerIds'] as List?)?.contains(me) ?? false;
          play(won ? SoundEffect.win : SoundEffect.lose);
          if (won) haptic(HapticFeedback.heavyImpact);
      }
    }
  }
}

final feedbackServiceProvider = Provider<FeedbackService>(
  (ref) => FeedbackService(ref),
);

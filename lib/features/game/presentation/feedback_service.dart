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

/// Sound abstraction. The default implementation uses system sounds; swap in an
/// audio-package implementation once sound assets are added to the project.
abstract interface class SoundService {
  void play(SoundEffect effect);
  void playMusic(MusicTrack track);
  void stopMusic();
}

class SystemSoundService implements SoundService {
  @override
  void play(SoundEffect effect) {
    switch (effect) {
      case SoundEffect.click:
      case SoundEffect.bet:
      case SoundEffect.raise:
      case SoundEffect.chip:
      case SoundEffect.timerWarning:
        SystemSound.play(SystemSoundType.click);
      default:
        break;
    }
  }

  @override
  void playMusic(MusicTrack track) {}

  @override
  void stopMusic() {}
}

final soundServiceProvider = Provider<SoundService>((ref) => SystemSoundService());

/// Turns engine events into sound + haptics, honouring the user's settings.
class FeedbackService {
  FeedbackService(this._ref);
  final Ref _ref;

  void play(SoundEffect e) {
    if (_ref.read(settingsProvider).sound) _ref.read(soundServiceProvider).play(e);
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
          if (e.playerId == me) haptic(raise ? HapticFeedback.mediumImpact : HapticFeedback.lightImpact);
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

final feedbackServiceProvider = Provider<FeedbackService>((ref) => FeedbackService(ref));

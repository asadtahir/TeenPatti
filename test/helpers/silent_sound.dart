import 'package:teen_patti/features/game/presentation/feedback_service.dart';

/// Tests have no audio plugin, so they swap the real player for one that does nothing.
class SilentSoundService implements SoundService {
  @override
  void play(SoundEffect effect) {}

  @override
  void playMusic(MusicTrack track) {}

  @override
  void stopMusic() {}
}

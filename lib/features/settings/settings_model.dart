import 'dart:convert';

enum GraphicsQuality { low, medium, high, ultra }

class AppSettings {
  const AppSettings({
    this.sound = true,
    this.music = true,
    this.vibration = true,
    this.notifications = true,
    this.reduceMotion = false,
    this.graphicsQuality = GraphicsQuality.high,
    this.language = 'en',
  });

  final bool sound;
  final bool music;
  final bool vibration;
  final bool notifications;
  final bool reduceMotion;
  final GraphicsQuality graphicsQuality;
  final String language;

  AppSettings copyWith({
    bool? sound,
    bool? music,
    bool? vibration,
    bool? notifications,
    bool? reduceMotion,
    GraphicsQuality? graphicsQuality,
    String? language,
  }) =>
      AppSettings(
        sound: sound ?? this.sound,
        music: music ?? this.music,
        vibration: vibration ?? this.vibration,
        notifications: notifications ?? this.notifications,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        graphicsQuality: graphicsQuality ?? this.graphicsQuality,
        language: language ?? this.language,
      );

  Map<String, Object?> toJson() => {
        'sound': sound,
        'music': music,
        'vibration': vibration,
        'notifications': notifications,
        'reduceMotion': reduceMotion,
        'graphicsQuality': graphicsQuality.name,
        'language': language,
      };

  factory AppSettings.fromJson(Map<String, Object?> j) {
    const d = AppSettings();
    return AppSettings(
      sound: j['sound'] as bool? ?? d.sound,
      music: j['music'] as bool? ?? d.music,
      vibration: j['vibration'] as bool? ?? d.vibration,
      notifications: j['notifications'] as bool? ?? d.notifications,
      reduceMotion: j['reduceMotion'] as bool? ?? d.reduceMotion,
      graphicsQuality: GraphicsQuality.values.asNameMap()[j['graphicsQuality']] ??
          d.graphicsQuality,
      language: j['language'] as String? ?? d.language,
    );
  }

  String encode() => jsonEncode(toJson());

  /// Tolerates missing or corrupt data by falling back to defaults.
  static AppSettings decode(String? raw) {
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(
          (jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      return const AppSettings();
    }
  }
}

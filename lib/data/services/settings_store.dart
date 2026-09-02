import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Preferências do usuário. Imutável; alterações passam por [copyWith].
class AppSettings {
  const AppSettings({
    this.hapticsEnabled = true,
    this.wifiOnly = true,
    this.backgroundDownloads = true,
    this.darkTheme = false,
    this.localeCode = 'pt_BR',
    this.maxConcurrent = 2,
    this.preferAudio = false,
  });

  final bool hapticsEnabled;
  final bool wifiOnly;
  final bool backgroundDownloads;
  final bool darkTheme;
  final String localeCode;
  final int maxConcurrent;

  /// Quando ligado, o app sugere áudio (MP3/M4A) por padrão.
  final bool preferAudio;

  AppSettings copyWith({
    bool? hapticsEnabled,
    bool? wifiOnly,
    bool? backgroundDownloads,
    bool? darkTheme,
    String? localeCode,
    int? maxConcurrent,
    bool? preferAudio,
  }) {
    return AppSettings(
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      backgroundDownloads: backgroundDownloads ?? this.backgroundDownloads,
      darkTheme: darkTheme ?? this.darkTheme,
      localeCode: localeCode ?? this.localeCode,
      maxConcurrent: maxConcurrent ?? this.maxConcurrent,
      preferAudio: preferAudio ?? this.preferAudio,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'hapticsEnabled': hapticsEnabled,
        'wifiOnly': wifiOnly,
        'backgroundDownloads': backgroundDownloads,
        'darkTheme': darkTheme,
        'localeCode': localeCode,
        'maxConcurrent': maxConcurrent,
        'preferAudio': preferAudio,
      };

  static AppSettings fromJson(Map<String, dynamic> json) => AppSettings(
        hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
        wifiOnly: json['wifiOnly'] as bool? ?? true,
        backgroundDownloads: json['backgroundDownloads'] as bool? ?? true,
        darkTheme: json['darkTheme'] as bool? ?? false,
        localeCode: json['localeCode'] as String? ?? 'pt_BR',
        maxConcurrent: (json['maxConcurrent'] as num?)?.toInt() ?? 2,
        preferAudio: json['preferAudio'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.hapticsEnabled == hapticsEnabled &&
      other.wifiOnly == wifiOnly &&
      other.backgroundDownloads == backgroundDownloads &&
      other.darkTheme == darkTheme &&
      other.localeCode == localeCode &&
      other.maxConcurrent == maxConcurrent &&
      other.preferAudio == preferAudio;

  @override
  int get hashCode => Object.hash(hapticsEnabled, wifiOnly, backgroundDownloads,
      darkTheme, localeCode, maxConcurrent, preferAudio);
}

/// Persistência das preferências em `SharedPreferences`.
class SettingsStore {
  SettingsStore(this._prefs);

  static const String _key = 'directtube.settings.v1';

  final SharedPreferences _prefs;

  static Future<SettingsStore> open() async =>
      SettingsStore(await SharedPreferences.getInstance());

  AppSettings load() {
    final String? raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      final Map<String, dynamic> json =
          (jsonDecode(raw) as Map<String, dynamic>);
      return AppSettings.fromJson(json);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) =>
      _prefs.setString(_key, jsonEncode(settings.toJson()));
}

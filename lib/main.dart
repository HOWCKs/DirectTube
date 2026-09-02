import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/haptics.dart';
import 'data/engine/download_engine.dart';
import 'data/engine/engine_registry.dart';
import 'data/engine/youtube_explode_engine.dart';
import 'data/engine/ytdlp_engine.dart';
import 'data/services/download_manager.dart';
import 'data/services/file_store.dart';
import 'data/services/player_service.dart';
import 'data/services/search_service.dart';
import 'data/services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final SettingsStore settingsStore = await SettingsStore.open();
  final AppSettings settings = settingsStore.load();
  Haptics.enabled = settings.hapticsEnabled;

  // Ordem importa: motor YouTube nativo primeiro, yt-dlp como fallback amplo.
  final EngineRegistry registry = EngineRegistry(<DownloadEngine>[
    YoutubeExplodeEngine(),
    YtDlpEngine(),
  ]);

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final DownloadManager manager = DownloadManager(
    registry: registry,
    files: FileStore(),
    prefs: prefs,
    maxConcurrent: settings.maxConcurrent,
  );

  runApp(DirectTubeApp(
    settingsStore: settingsStore,
    manager: manager,
    search: SearchService(registry),
    audioPlayer: AudioPlayerService(),
  ));
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uma faixa de áudio encontrada nas pastas escolhidas do dispositivo.
class DeviceTrack {
  const DeviceTrack({
    required this.path,
    required this.title,
    required this.folder,
    required this.sizeBytes,
  });

  final String path;
  final String title;
  final String folder;
  final int sizeBytes;
}

/// Escaneia as pastas de música escolhidas pelo usuário e expõe as faixas
/// para o player. Singleton para sobreviver entre abas.
class DeviceMusicService extends ChangeNotifier {
  DeviceMusicService._();

  /// Instância compartilhada.
  static final DeviceMusicService instance = DeviceMusicService._();

  static const MethodChannel _channel = MethodChannel('com.directtube.app/media');
  static const String _foldersKey = 'directtube.devicefolders.v1';

  List<String> folders = <String>[];
  List<DeviceTrack> tracks = <DeviceTrack>[];
  bool scanning = false;
  bool permissionGranted = false;
  SharedPreferences? _prefs;

  bool get ready => _prefs != null;

  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    folders = _prefs!.getStringList(_foldersKey) ?? <String>[];
    if (folders.isNotEmpty) {
      await rescan();
    }
  }

  Future<void> _persistFolders() async {
    await _prefs?.setStringList(_foldersKey, folders);
  }

  /// Pede a permissão de leitura de áudio ao sistema.
  Future<bool> ensurePermission() async {
    final bool? granted =
        await _channel.invokeMethod<bool>('requestAudioPermission');
    permissionGranted = granted ?? false;
    notifyListeners();
    return permissionGranted;
  }

  /// Abre o seletor de pasta do sistema e, se escolhida, a adiciona.
  Future<void> addFolder() async {
    final String? picked = await _channel.invokeMethod<String>('pickFolder');
    if (picked == null || picked.isEmpty) return;
    if (!folders.contains(picked)) {
      folders.add(picked);
      await _persistFolders();
      notifyListeners();
      await rescan();
    }
  }

  Future<void> removeFolder(String path) async {
    folders.remove(path);
    await _persistFolders();
    notifyListeners();
    await rescan();
  }

  /// Revarre as pastas escolhidas em busca de áudio.
  Future<void> rescan() async {
    if (scanning) return;
    scanning = true;
    notifyListeners();
    try {
      final List<dynamic>? raw = await _channel
          .invokeListMethod<dynamic>('scanFolders', <String, dynamic>{
        'paths': folders,
      });
      tracks = (raw ?? <dynamic>[]).map((dynamic item) {
        final Map<dynamic, dynamic> map = item as Map<dynamic, dynamic>;
        return DeviceTrack(
          path: (map['path'] as String?) ?? '',
          title: (map['title'] as String?) ?? 'Áudio',
          folder: (map['folder'] as String?) ?? '',
          sizeBytes: (map['size'] as num?)?.toInt() ?? 0,
        );
      }).toList(growable: false);
    } catch (_) {
      tracks = <DeviceTrack>[];
    }
    scanning = false;
    notifyListeners();
  }
}

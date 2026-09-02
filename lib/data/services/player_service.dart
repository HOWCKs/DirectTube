import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Reprodução de áudio dos arquivos baixados (arquivos locais).
///
/// `position` é um [ValueNotifier] para que a barra de progresso se redesenhe
/// sem reconstruir a tela inteira a cada tick.
class AudioPlayerService extends ChangeNotifier {
  AudioPlayerService() {
    _subscriptions.add(_player.positionStream.listen((Duration value) {
      position.value = value;
    }));
    _subscriptions.add(_player.playerStateStream.listen((PlayerState _) {
      notifyListeners();
    }));
    _subscriptions.add(_player.durationStream.listen((Duration? _) {
      notifyListeners();
    }));
    _subscriptions.add(_player.sequenceStateStream.listen((SequenceState? _) {
      notifyListeners();
    }));
  }

  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  final ValueNotifier<Duration> position = ValueNotifier<Duration>(Duration.zero);

  String? _path;
  String? _title;
  String? _videoPath;
  String? _videoTitle;
  bool _loading = false;
  String? _error;

  String? get path => _path;
  String? get videoPath => _videoPath;

  /// `true` quando o item atual é vídeo (a tela usa `video_player`).
  bool get isVideo => _videoPath != null;

  String? get title => isVideo ? _videoTitle : _title;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get hasItem => _path != null || _videoPath != null;

  /// Abre um vídeo baixado (a reprodução em si fica com `video_player`).
  Future<void> openVideo({required String path, required String title}) async {
    await _player.pause();
    _videoPath = path;
    _videoTitle = title;
    _path = null;
    _title = null;
    _error = null;
    notifyListeners();
  }

  bool get isPlaying => _player.playing;

  Duration get duration => _player.duration ?? Duration.zero;

  bool get isCompleted =>
      _player.processingState == ProcessingState.completed;

  Future<void> open({required String path, required String title}) async {
    _loading = true;
    _error = null;
    _videoPath = null;
    _videoTitle = null;
    _path = path;
    _title = title;
    notifyListeners();
    try {
      await _player.setFilePath(path);
      position.value = Duration.zero;
      await _player.play();
    } catch (error) {
      _error = 'Não consegui reproduzir este arquivo.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    if (!hasItem) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      if (isCompleted) await _player.seek(Duration.zero);
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> seek(Duration value) async {
    await _player.seek(value);
    position.value = value;
  }

  Future<void> skipBy(Duration delta) async {
    Duration target = position.value + delta;
    if (target < Duration.zero) target = Duration.zero;
    final Duration total = duration;
    if (total > Duration.zero && target > total) target = total;
    await seek(target);
  }

  Future<void> stop() async {
    await _player.pause();
    _path = null;
    _title = null;
    _videoPath = null;
    _videoTitle = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    unawaited(_player.dispose());
    position.dispose();
    super.dispose();
  }
}

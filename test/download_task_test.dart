import 'package:directtube/data/models/download_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DownloadTask task = DownloadTask(
    id: 'task-1',
    mediaId: 'dQw4w9WgXcQ',
    title: 'Vídeo de teste',
    sourceUrl: 'https://youtu.be/dQw4w9WgXcQ',
    formatId: '18',
    extension: 'mp4',
    isAudioOnly: false,
    createdAt: DateTime(2026, 1, 2, 3, 4, 5),
    engineId: 'youtube-explode',
    formatLabel: '360p MP4',
  );

  group('progress', () {
    test('é zero sem tamanho total', () {
      expect(task.progress, 0);
      expect(task.copyWith(totalBytes: 0).progress, 0);
    });

    test('calcula a fração e trunca em 1.0', () {
      expect(task.copyWith(receivedBytes: 50, totalBytes: 200).progress, 0.25);
      expect(task.copyWith(receivedBytes: 999, totalBytes: 200).progress, 1.0);
    });
  });

  group('status', () {
    test('canPause/canResume/canCancel', () {
      expect(DownloadStatus.running.canPause, isTrue);
      expect(DownloadStatus.queued.canPause, isTrue);
      expect(DownloadStatus.paused.canPause, isFalse);
      expect(DownloadStatus.paused.canResume, isTrue);
      expect(DownloadStatus.failed.canResume, isTrue);
      expect(DownloadStatus.completed.canCancel, isFalse);
      expect(DownloadStatus.canceled.canCancel, isFalse);
      expect(DownloadStatus.completed.isTerminal, isTrue);
      expect(DownloadStatus.running.isTerminal, isFalse);
    });
  });

  group('copyWith', () {
    test('limpa o erro ao voltar para a fila', () {
      final DownloadTask failed =
          task.copyWith(status: DownloadStatus.failed, error: 'Sem conexão');
      expect(failed.error, 'Sem conexão');
      expect(failed.copyWith(status: DownloadStatus.queued).error, '');
    });

    test('mantém identidade e metadados', () {
      final DownloadTask updated = task.copyWith(receivedBytes: 42);
      expect(updated.id, 'task-1');
      expect(updated.mediaId, 'dQw4w9WgXcQ');
      expect(updated.formatLabel, '360p MP4');
      expect(updated.receivedBytes, 42);
    });
  });

  group('retry', () {
    test('zera progresso, erro e velocidade', () {
      final DownloadTask failed = task.copyWith(
        status: DownloadStatus.failed,
        receivedBytes: 1000,
        error: 'Falha',
        speedBytesPerSecond: 99,
      );
      final DownloadTask retried = failed.retry();
      expect(retried.status, DownloadStatus.queued);
      expect(retried.receivedBytes, 0);
      expect(retried.error, isNull);
      expect(retried.speedBytesPerSecond, 0);
      expect(retried.totalBytes, failed.totalBytes);
    });
  });

  group('JSON', () {
    test('ida e volta preserva os campos', () {
      final DownloadTask original = task.copyWith(
        status: DownloadStatus.paused,
        receivedBytes: 1234,
        totalBytes: 9999,
        filePath: '/sdcard/Download/x.mp4',
        speedBytesPerSecond: 12.5,
      );
      final DownloadTask restored =
          DownloadTask.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.mediaId, original.mediaId);
      expect(restored.title, original.title);
      expect(restored.status, DownloadStatus.paused);
      expect(restored.receivedBytes, 1234);
      expect(restored.totalBytes, 9999);
      expect(restored.filePath, original.filePath);
      expect(restored.speedBytesPerSecond, 12.5);
      expect(restored.createdAt, original.createdAt);
      expect(restored.isAudioOnly, isFalse);
    });

    test('tolera status desconhecido', () {
      final Map<String, dynamic> json = task.toJson()
        ..['status'] = 'estado-que-nao-existe';
      expect(DownloadTask.fromJson(json).status, DownloadStatus.queued);
    });

    test('usa o id como mediaId quando ele falta (dados antigos)', () {
      final Map<String, dynamic> json = task.toJson()..remove('mediaId');
      expect(DownloadTask.fromJson(json).mediaId, 'task-1');
    });
  });
}

import 'package:directtube/data/models/download_task.dart';
import 'package:directtube/data/services/download_queue.dart';
import 'package:flutter_test/flutter_test.dart';

DownloadTask _task(
  String id, {
  DownloadStatus status = DownloadStatus.queued,
  bool audio = false,
}) {
  return DownloadTask(
    id: id,
    mediaId: 'media-$id',
    title: 'Título $id',
    sourceUrl: 'https://youtube.com/watch?v=$id',
    formatId: '18',
    extension: audio ? 'm4a' : 'mp4',
    isAudioOnly: audio,
    createdAt: DateTime(2026, 1, 1),
    status: status,
    formatLabel: audio ? 'M4A 128k' : '360p MP4',
  );
}

void main() {
  group('DownloadQueue.add', () {
    test('adiciona e recusa ids repetidos', () {
      final DownloadQueue queue = DownloadQueue();
      expect(queue.add(_task('a')), isTrue);
      expect(queue.add(_task('a')), isFalse);
      expect(queue.length, 1);
    });
  });

  group('DownloadQueue.startable', () {
    test('respeita maxConcurrent e a ordem de chegada', () {
      final DownloadQueue queue = DownloadQueue(maxConcurrent: 2);
      queue.addAll(<DownloadTask>[_task('a'), _task('b'), _task('c')]);

      expect(queue.startable().map((DownloadTask t) => t.id), <String>['a', 'b']);

      queue.update(_task('a', status: DownloadStatus.running));
      expect(queue.startable().map((DownloadTask t) => t.id), <String>['b']);

      queue.update(_task('b', status: DownloadStatus.running));
      expect(queue.startable(), isEmpty);
      expect(queue.runningCount, 2);
    });

    test('libera vaga quando uma tarefa conclui', () {
      final DownloadQueue queue = DownloadQueue(maxConcurrent: 1);
      queue.addAll(<DownloadTask>[_task('a'), _task('b')]);
      queue.update(_task('a', status: DownloadStatus.running));
      expect(queue.startable(), isEmpty);

      queue.complete('a', '/tmp/a.mp4');
      expect(queue.startable().map((DownloadTask t) => t.id), <String>['b']);
    });
  });

  group('transições de estado', () {
    test('pause só vale para rodando/na fila', () {
      final DownloadQueue queue = DownloadQueue();
      queue.add(_task('a', status: DownloadStatus.running));
      queue.add(_task('b', status: DownloadStatus.completed));

      expect(queue.pause('a'), isTrue);
      expect(queue.statusOf('a'), DownloadStatus.paused);
      expect(queue.pause('b'), isFalse);
      expect(queue.pause('inexistente'), isFalse);
    });

    test('resume reentra na fila e limpa o erro', () {
      final DownloadQueue queue = DownloadQueue();
      queue.add(_task('a', status: DownloadStatus.running));
      queue.fail('a', 'Sem conexão');
      expect(queue.statusOf('a'), DownloadStatus.failed);
      expect(queue.byId('a')!.error, 'Sem conexão');

      expect(queue.resume('a'), isTrue);
      expect(queue.statusOf('a'), DownloadStatus.queued);
      expect(queue.byId('a')!.error, isNull);
    });

    test('complete grava o caminho e zera velocidade', () {
      final DownloadQueue queue = DownloadQueue();
      queue.add(_task('a', status: DownloadStatus.running));
      queue.update(queue.byId('a')!.copyWith(speedBytesPerSecond: 1234));
      expect(queue.complete('a', '/sdcard/a.mp4'), isTrue);

      final DownloadTask task = queue.byId('a')!;
      expect(task.isComplete, isTrue);
      expect(task.filePath, '/sdcard/a.mp4');
      expect(task.speedBytesPerSecond, 0);
    });

    test('pauseAll atinge fila e execução', () {
      final DownloadQueue queue = DownloadQueue();
      queue.addAll(<DownloadTask>[
        _task('a', status: DownloadStatus.running),
        _task('b', status: DownloadStatus.queued),
        _task('c', status: DownloadStatus.completed),
      ]);
      expect(queue.pauseAll(), 2);
      expect(queue.countBy(DownloadStatus.paused), 2);
      expect(queue.statusOf('c'), DownloadStatus.completed);
    });

    test('clearFinished remove apenas terminais', () {
      final DownloadQueue queue = DownloadQueue();
      queue.addAll(<DownloadTask>[
        _task('a', status: DownloadStatus.completed),
        _task('b', status: DownloadStatus.running),
        _task('c', status: DownloadStatus.canceled),
      ]);
      final List<DownloadTask> removed = queue.clearFinished();
      expect(removed.map((DownloadTask t) => t.id), <String>['a', 'c']);
      expect(queue.tasks.map((DownloadTask t) => t.id), <String>['b']);
    });
  });

  group('restore', () {
    test('rebaixa o que estava rodando quando o app morreu', () {
      final DownloadQueue queue = DownloadQueue();
      queue.restore(<DownloadTask>[
        _task('a', status: DownloadStatus.running),
        _task('b', status: DownloadStatus.paused),
        _task('c', status: DownloadStatus.completed),
      ]);
      expect(queue.statusOf('a'), DownloadStatus.queued);
      expect(queue.statusOf('b'), DownloadStatus.paused);
      expect(queue.statusOf('c'), DownloadStatus.completed);
    });
  });
}

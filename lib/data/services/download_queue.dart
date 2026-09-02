import '../models/download_task.dart';

/// Fila de downloads: ordenação, concorrência e transições de estado.
///
/// Classe pura (sem Flutter, sem I/O) para que toda a regra de negócio seja
/// coberta por testes unitários (`test/download_queue_test.dart`).
class DownloadQueue {
  DownloadQueue({this.maxConcurrent = 2});

  /// Quantos downloads rodam ao mesmo tempo.
  final int maxConcurrent;

  final List<DownloadTask> _tasks = <DownloadTask>[];

  List<DownloadTask> get tasks => List<DownloadTask>.unmodifiable(_tasks);

  int get length => _tasks.length;

  bool get isEmpty => _tasks.isEmpty;

  int countBy(DownloadStatus status) =>
      _tasks.where((DownloadTask t) => t.status == status).length;

  int get runningCount => countBy(DownloadStatus.running);

  int get activeCount =>
      countBy(DownloadStatus.running) + countBy(DownloadStatus.queued);

  int get completedCount => countBy(DownloadStatus.completed);

  DownloadTask? byId(String id) {
    for (final DownloadTask task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  int indexOf(String id) => _tasks.indexWhere((DownloadTask t) => t.id == id);

  /// Adiciona uma tarefa. Retorna `false` se o id já existir.
  bool add(DownloadTask task) {
    if (byId(task.id) != null) return false;
    _tasks.add(task);
    return true;
  }

  bool addAll(Iterable<DownloadTask> tasks) {
    bool any = false;
    for (final DownloadTask task in tasks) {
      if (add(task)) any = true;
    }
    return any;
  }

  /// Tarefas que podem começar agora, respeitando [maxConcurrent] e a ordem
  /// de chegada (FIFO pela data de criação, com desempate por inserção).
  List<DownloadTask> startable() {
    int slots = maxConcurrent - runningCount;
    if (slots <= 0) return const <DownloadTask>[];

    final List<DownloadTask> queued = _tasks
        .where((DownloadTask t) => t.status == DownloadStatus.queued)
        .toList();

    final List<DownloadTask> result = <DownloadTask>[];
    for (final DownloadTask task in queued) {
      if (slots == 0) break;
      result.add(task);
      slots--;
    }
    return result;
  }

  /// Substitui a versão armazenada de uma tarefa (por id).
  bool update(DownloadTask task) {
    final int index = indexOf(task.id);
    if (index < 0) return false;
    _tasks[index] = task;
    return true;
  }

  DownloadStatus? statusOf(String id) => byId(id)?.status;

  bool pause(String id) {
    final DownloadTask? task = byId(id);
    if (task == null || !task.status.canPause) return false;
    return update(task.copyWith(
      status: DownloadStatus.paused,
      speedBytesPerSecond: 0,
    ));
  }

  /// Pausa tudo que está rodando ou na fila (ex.: usuário saiu do Wi-Fi).
  int pauseAll() {
    int count = 0;
    for (final DownloadTask task in List<DownloadTask>.of(_tasks)) {
      if (task.status.canPause && pause(task.id)) count++;
    }
    return count;
  }

  bool resume(String id) {
    final DownloadTask? task = byId(id);
    if (task == null || !task.status.canResume) return false;
    return update(task.retry());
  }

  bool cancel(String id) {
    final DownloadTask? task = byId(id);
    if (task == null || !task.status.canCancel) return false;
    return update(task.copyWith(
      status: DownloadStatus.canceled,
      speedBytesPerSecond: 0,
    ));
  }

  bool fail(String id, String message) {
    final DownloadTask? task = byId(id);
    if (task == null) return false;
    return update(task.copyWith(
      status: DownloadStatus.failed,
      error: message,
      speedBytesPerSecond: 0,
    ));
  }

  bool complete(String id, String filePath) {
    final DownloadTask? task = byId(id);
    if (task == null) return false;
    return update(task.copyWith(
      status: DownloadStatus.completed,
      filePath: filePath,
      speedBytesPerSecond: 0,
      error: '',
    ));
  }

  bool remove(String id) {
    final int index = indexOf(id);
    if (index < 0) return false;
    _tasks.removeAt(index);
    return true;
  }

  /// Remove tarefas finalizadas (concluídas ou canceladas).
  List<DownloadTask> clearFinished() {
    final List<DownloadTask> removed = _tasks
        .where((DownloadTask t) => t.status.isTerminal)
        .toList(growable: false);
    _tasks.removeWhere((DownloadTask t) => t.status.isTerminal);
    return removed;
  }

  void clear() => _tasks.clear();

  /// Restaura a fila a partir da persistência, rebaixando para "na fila"
  /// qualquer tarefa que estava rodando quando o app morreu.
  void restore(List<DownloadTask> tasks) {
    _tasks
      ..clear()
      ..addAll(tasks.map((DownloadTask t) =>
          t.status == DownloadStatus.running
              ? t.copyWith(status: DownloadStatus.queued, speedBytesPerSecond: 0)
              : t));
  }
}

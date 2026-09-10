import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/download_task.dart';

/// Notificações de download com barra de progresso e ações
/// **Pausar/Retomar** e **Cancelar**, operáveis sem abrir o app.
///
/// Tocar no corpo da notificação chama [onOpen] (navega para Downloads).
class DownloadNotifications {
  DownloadNotifications();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'directtube_downloads';

  /// Chamado quando o usuário toca numa ação da notificação.
  /// `action` é 'pause' ou 'cancel'; `taskId` identifica a tarefa.
  static void Function(String taskId, String action)? onAction;

  /// Chamado quando o usuário toca no corpo da notificação.
  static void Function()? onOpen;

  bool _ready = false;

  Future<void> init() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: android);
    final bool ok = await _plugin.initialize(
          settings,
          onDidReceiveNotificationResponse: _handleResponse,
        ) ??
        false;
    if (ok) {
      final AndroidFlutterLocalNotificationsPlugin? androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      _ready = true;
    }
  }

  void _handleResponse(NotificationResponse response) {
    final String? taskId = response.payload;
    if (taskId == null || taskId.isEmpty) {
      onOpen?.call();
      return;
    }
    final String action = response.actionId ?? 'open';
    if (action == 'open') {
      onOpen?.call();
    } else {
      onAction?.call(taskId, action);
    }
  }

  /// Id estável da notificação para uma tarefa.
  static int idFor(String taskId) => taskId.hashCode.abs() % 1000000;

  Future<void> showProgress(DownloadTask task) async {
    if (!_ready) return;
    final int? total = task.totalBytes;
    final double frac =
        (total ?? 0) > 0 ? task.receivedBytes / total! : 0;
    final int pct = (frac * 100).clamp(0, 100).toInt();
    final bool paused = task.status == DownloadStatus.paused;
    final bool running = task.status == DownloadStatus.running;

    final AndroidNotificationDetails details = AndroidNotificationDetails(
      _channelId,
      'Downloads',
      channelDescription: 'Progresso das músicas e vídeos baixando',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: running,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: pct,
      indeterminate: total == null && running,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction('pause', 'Pausar', cancelNotification: false),
        AndroidNotificationAction('cancel', 'Cancelar'),
      ],
    );

    await _plugin.show(
      idFor(task.id),
      task.title,
      paused ? 'Pausado · $pct%' : 'Baixando · $pct%',
      NotificationDetails(android: details),
      payload: task.id,
    );
  }

  Future<void> showTerminal(DownloadTask task) async {
    if (!_ready) return;
    final bool done = task.status == DownloadStatus.completed;
    final AndroidNotificationDetails details = AndroidNotificationDetails(
      _channelId,
      'Downloads',
      channelDescription: 'Progresso das músicas e vídeos baixando',
      importance: done ? Importance.defaultImportance : Importance.low,
      priority: done ? Priority.defaultPriority : Priority.low,
      onlyAlertOnce: false,
    );
    await _plugin.show(
      idFor(task.id),
      task.title,
      done
          ? 'Concluído · salvo na memória'
          : (task.status == DownloadStatus.failed
              ? 'Falhou · ${task.error ?? ''}'
              : 'Cancelado'),
      NotificationDetails(android: details),
      payload: task.id,
    );
  }

  Future<void> dismiss(String taskId) => _plugin.cancel(idFor(taskId));
}

/// Sincroniza o estado da fila com as notificações, publicando progresso
/// enquanto ativo e um aviso único ao concluir/falhar/cancelar.
class NotificationBridge {
  NotificationBridge(this.notifications);

  final DownloadNotifications notifications;
  final Map<String, DownloadStatus> _last = <String, DownloadStatus>{};

  Future<void> sync(List<DownloadTask> tasks) async {
    for (final DownloadTask task in tasks) {
      final DownloadStatus? prev = _last[task.id];
      final DownloadStatus status = task.status;

      if (status == DownloadStatus.running ||
          status == DownloadStatus.paused ||
          status == DownloadStatus.queued) {
        await notifications.showProgress(task);
      } else if (status.isTerminal) {
        if (prev != status) {
          if (status == DownloadStatus.canceled) {
            await notifications.dismiss(task.id);
          } else {
            await notifications.showTerminal(task);
          }
        }
      }
      _last[task.id] = status;
    }
  }
}

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('com.directtube.app/media');

/// Abre o seletor de compartilhamento do sistema com [text] (link da mídia).
Future<void> shareText(String text) =>
    _channel.invokeMethod<void>('share', <String, dynamic>{'text': text});

/// Traduz exceções técnicas (inglês, stack trace) para mensagens curtas em
/// pt-BR que cabem numa snackbar/painel. Mantido puro e testável.
String friendlyError(Object error) {
  final String text = error.toString();

  if (text.contains('RequestLimitExceededException') ||
      text.contains('rate limit')) {
    return 'O YouTube limitou pedidos deste IP agora. Aguarde ~1 minuto e '
        'toque em “Tentar de novo”.';
  }
  if (text.contains('VideoUnavailableException') ||
      text.contains('VideoUnavailable')) {
    return 'Este vídeo está indisponível, privado ou removido.';
  }
  if (text.contains('VideoUnplayableException') ||
      text.contains('unplayable')) {
    return 'Este vídeo não permite extração (restrição do dono).';
  }
  if (text.contains('AgeRestricted')) {
    return 'Vídeo com restrição de idade; exige conta verificada.';
  }
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection reset')) {
    return 'Sem conexão estável com a internet.';
  }
  if (text.contains('HttpException') || text.contains('status code 4')) {
    return 'O YouTube recusou o pedido; tente novamente em instantes.';
  }
  if (text.contains('no such file') || text.contains('ENOENT')) {
    return 'Não consegui gravar o arquivo neste armazenamento.';
  }
  if (text.length > 160) return '${text.substring(0, 160)}…';
  return text;
}

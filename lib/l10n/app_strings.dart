import 'package:flutter/widgets.dart';

/// Strings do app (pt-BR padrão + inglês).
///
/// Sem `gen-l10n` de propósito: zero dependência de codegen na build, o que
/// elimina uma classe inteira de falha na CI e mantém tudo testável.
abstract class AppStrings {
  const AppStrings();

  String get localeCode;
  String get languageLabel;

  // Marca
  String get appName => 'DirectTube';
  String get tagline;

  // Navegação
  String get home;
  String get downloads;
  String get player;
  String get library;
  String get settings;

  // Início
  String get searchHint;
  String get searchAction;
  String get pasteAction;
  String get searching;
  String get resolving;
  String get noResults;
  String get recentLinks;
  String get trendingTitle;

  // Formatos / download
  String get formats;
  String get download;
  String get quality;
  String get audioOnly;
  String get needsMuxing;
  String get startDownload;

  // Fila
  String get queued;
  String get running;
  String get paused;
  String get completed;
  String get failed;
  String get canceled;
  String get pauseAll;
  String get clearFinished;
  String get emptyQueue;
  String get retry;
  String get cancel;
  String get remove;

  // Biblioteca
  String get music;
  String get videos;
  String get emptyLibrary;
  String get openWith;

  // Player
  String get nowPlaying;
  String get nothingPlaying;

  // Ajustes
  String get haptics;
  String get hapticsHint;
  String get wifiOnly;
  String get wifiOnlyHint;
  String get background;
  String get backgroundHint;
  String get preferAudio;
  String get preferAudioHint;
  String get appearance;
  String get darkTheme;
  String get language;
  String get maxConcurrent;
  String get engines;
  String get about;
  String get legalNotice;
  String get version;

  // Erros
  String get invalidLink;
  String get noEngine;

  static AppStrings forLocale(Locale locale) {
    if (locale.languageCode.toLowerCase().startsWith('pt')) {
      return const PtBrStrings();
    }
    return const EnStrings();
  }
}

class PtBrStrings extends AppStrings {
  const PtBrStrings();

  @override
  String get localeCode => 'pt_BR';
  @override
  String get languageLabel => 'Português (Brasil)';
  @override
  String get tagline => 'Baixe vídeo e música sem pressa.';

  @override
  String get home => 'Início';
  @override
  String get downloads => 'Downloads';
  @override
  String get player => 'Player';
  @override
  String get library => 'Biblioteca';
  @override
  String get settings => 'Ajustes';

  @override
  String get searchHint => 'Colar link ou buscar';
  @override
  String get searchAction => 'Buscar';
  @override
  String get pasteAction => 'Colar';
  @override
  String get searching => 'Buscando…';
  @override
  String get resolving => 'Analisando link…';
  @override
  String get noResults => 'Nada encontrado para essa busca.';
  @override
  String get recentLinks => 'Links recentes';
  @override
  String get trendingTitle => 'Resultados';

  @override
  String get formats => 'Formatos';
  @override
  String get download => 'Baixar';
  @override
  String get quality => 'Qualidade';
  @override
  String get audioOnly => 'Somente áudio';
  @override
  String get needsMuxing => 'Requer módulo FFmpeg';
  @override
  String get startDownload => 'Iniciar download';

  @override
  String get queued => 'Na fila';
  @override
  String get running => 'Baixando';
  @override
  String get paused => 'Pausado';
  @override
  String get completed => 'Concluído';
  @override
  String get failed => 'Falhou';
  @override
  String get canceled => 'Cancelado';
  @override
  String get pauseAll => 'Pausar tudo';
  @override
  String get clearFinished => 'Limpar concluídos';
  @override
  String get emptyQueue => 'Nenhum download na fila.';
  @override
  String get retry => 'Tentar de novo';
  @override
  String get cancel => 'Cancelar';
  @override
  String get remove => 'Remover';

  @override
  String get music => 'Músicas';
  @override
  String get videos => 'Vídeos';
  @override
  String get emptyLibrary => 'Sua biblioteca está vazia por enquanto.';
  @override
  String get openWith => 'Abrir com…';

  @override
  String get nowPlaying => 'Tocando agora';
  @override
  String get nothingPlaying => 'Nada tocando. Escolha um item na Biblioteca.';

  @override
  String get haptics => 'Resposta tátil';
  @override
  String get hapticsHint => 'Vibração curta ao tocar nos controles';
  @override
  String get wifiOnly => 'Baixar só em Wi-Fi';
  @override
  String get wifiOnlyHint => 'Evita gastar seus dados móveis';
  @override
  String get background => 'Baixar em segundo plano';
  @override
  String get backgroundHint => 'A fila continua com a tela bloqueada';
  @override
  String get preferAudio => 'Preferir áudio';
  @override
  String get preferAudioHint => 'Sugere MP3/M4A ao abrir um link';
  @override
  String get appearance => 'Aparência';
  @override
  String get darkTheme => 'Tema escuro';
  @override
  String get language => 'Idioma';
  @override
  String get maxConcurrent => 'Downloads simultâneos';
  @override
  String get engines => 'Motores de download';
  @override
  String get about => 'Sobre';
  @override
  String get legalNotice =>
      'Baixe apenas conteúdo que você tem o direito de salvar. Respeite os '
      'termos de uso das plataformas e os direitos autorais.';
  @override
  String get version => 'Versão';

  @override
  String get invalidLink => 'Não reconheci esse link.';
  @override
  String get noEngine => 'Nenhum motor disponível para este link.';
}

class EnStrings extends AppStrings {
  const EnStrings();

  @override
  String get localeCode => 'en';
  @override
  String get languageLabel => 'English';
  @override
  String get tagline => 'Download video and music, no rush.';

  @override
  String get home => 'Home';
  @override
  String get downloads => 'Downloads';
  @override
  String get player => 'Player';
  @override
  String get library => 'Library';
  @override
  String get settings => 'Settings';

  @override
  String get searchHint => 'Paste a link or search';
  @override
  String get searchAction => 'Search';
  @override
  String get pasteAction => 'Paste';
  @override
  String get searching => 'Searching…';
  @override
  String get resolving => 'Resolving link…';
  @override
  String get noResults => 'Nothing found for that search.';
  @override
  String get recentLinks => 'Recent links';
  @override
  String get trendingTitle => 'Results';

  @override
  String get formats => 'Formats';
  @override
  String get download => 'Download';
  @override
  String get quality => 'Quality';
  @override
  String get audioOnly => 'Audio only';
  @override
  String get needsMuxing => 'Requires FFmpeg module';
  @override
  String get startDownload => 'Start download';

  @override
  String get queued => 'Queued';
  @override
  String get running => 'Downloading';
  @override
  String get paused => 'Paused';
  @override
  String get completed => 'Completed';
  @override
  String get failed => 'Failed';
  @override
  String get canceled => 'Canceled';
  @override
  String get pauseAll => 'Pause all';
  @override
  String get clearFinished => 'Clear finished';
  @override
  String get emptyQueue => 'No downloads in the queue.';
  @override
  String get retry => 'Try again';
  @override
  String get cancel => 'Cancel';
  @override
  String get remove => 'Remove';

  @override
  String get music => 'Music';
  @override
  String get videos => 'Videos';
  @override
  String get emptyLibrary => 'Your library is empty for now.';
  @override
  String get openWith => 'Open with…';

  @override
  String get nowPlaying => 'Now playing';
  @override
  String get nothingPlaying => 'Nothing playing. Pick a track in Library.';

  @override
  String get haptics => 'Haptic feedback';
  @override
  String get hapticsHint => 'Short vibration when touching controls';
  @override
  String get wifiOnly => 'Download on Wi-Fi only';
  @override
  String get wifiOnlyHint => 'Saves your mobile data';
  @override
  String get background => 'Background downloads';
  @override
  String get backgroundHint => 'Queue keeps running with the screen off';
  @override
  String get preferAudio => 'Prefer audio';
  @override
  String get preferAudioHint => 'Suggests MP3/M4A when opening a link';
  @override
  String get appearance => 'Appearance';
  @override
  String get darkTheme => 'Dark theme';
  @override
  String get language => 'Language';
  @override
  String get maxConcurrent => 'Concurrent downloads';
  @override
  String get engines => 'Download engines';
  @override
  String get about => 'About';
  @override
  String get legalNotice =>
      'Only download content you have the right to save. Respect platform '
      'terms of service and copyright.';
  @override
  String get version => 'Version';

  @override
  String get invalidLink => 'I could not recognize that link.';
  @override
  String get noEngine => 'No engine available for this link.';
}

/// Acesso pelas telas: `AppStrings.of(context)`.
class Strings {
  const Strings._();

  static AppStrings of(BuildContext context) {
    final AppStrings? found = Localizations.of<AppStrings>(context, AppStrings);
    return found ?? const PtBrStrings();
  }

  static const LocalizationsDelegate<AppStrings> delegate = _StringsDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('pt', 'BR'),
    Locale('en'),
  ];
}

class _StringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _StringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode.toLowerCase().startsWith('pt') ||
      locale.languageCode.toLowerCase().startsWith('en');

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings.forLocale(locale);

  @override
  bool shouldReload(_StringsDelegate old) => false;
}

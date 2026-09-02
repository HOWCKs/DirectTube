import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/app_scope.dart';
import '../../core/app_info.dart';
import '../../core/haptics.dart';
import '../../data/engine/download_engine.dart';
import '../../data/services/settings_store.dart';
import '../../design/neu_palette.dart';
import '../../design/neu_widgets.dart';
import '../../l10n/app_strings.dart';

/// Ajustes: tema, idioma, resposta tátil, rede, concorrência e motores.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings t = Strings.of(context);
    final NeuPalette palette = NeuPalette.of(context);
    final AppScope scope = AppScope.of(context);
    final AppSettings settings = scope.settings;
    final ValueChanged<AppSettings> update = scope.updateSettings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
          child: Text(
            t.settings,
            style: TextStyle(
              fontSize: NeuTokens.textTitle,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: palette.text,
            ),
          ),
        ),
        NeuSectionTitle(t.appearance, padding: const EdgeInsets.fromLTRB(2, 14, 2, 14)),
        _gap(
          NeuListRow(
            title: t.darkTheme,
            subtitle: palette.isDark ? 'Soft UI escuro' : 'Soft UI claro',
            trailing: NeuToggle(
              value: settings.darkTheme,
              onChanged: (bool value) {
                Haptics.fire(HapticStyle.light);
                update(settings.copyWith(darkTheme: value));
              },
            ),
          ),
        ),
        NeuListRow(
          title: t.language,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                t.language,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: palette.text),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  NeuChip(
                    label: 'Português',
                    active: settings.localeCode == 'pt_BR',
                    onTap: () => update(settings.copyWith(localeCode: 'pt_BR')),
                  ),
                  const SizedBox(width: 10),
                  NeuChip(
                    label: 'English',
                    active: settings.localeCode == 'en',
                    onTap: () => update(settings.copyWith(localeCode: 'en')),
                  ),
                ],
              ),
            ],
          ),
        ),
        NeuSectionTitle(t.downloads),
        _gap(
          NeuListRow(
            title: t.wifiOnly,
            subtitle: t.wifiOnlyHint,
            trailing: NeuToggle(
              value: settings.wifiOnly,
              onChanged: (bool value) =>
                  update(settings.copyWith(wifiOnly: value)),
            ),
          ),
        ),
        _gap(
          NeuListRow(
            title: t.background,
            subtitle: t.backgroundHint,
            trailing: NeuToggle(
              value: settings.backgroundDownloads,
              onChanged: (bool value) =>
                  update(settings.copyWith(backgroundDownloads: value)),
            ),
          ),
        ),
        _gap(
          NeuListRow(
            title: t.preferAudio,
            subtitle: t.preferAudioHint,
            trailing: NeuToggle(
              value: settings.preferAudio,
              onChanged: (bool value) =>
                  update(settings.copyWith(preferAudio: value)),
            ),
          ),
        ),
        NeuListRow(
          title: t.maxConcurrent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                t.maxConcurrent,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: palette.text),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  for (final int value in <int>[1, 2, 3, 4]) ...<Widget>[
                    NeuChip(
                      label: '$value',
                      active: settings.maxConcurrent == value,
                      onTap: () =>
                          update(settings.copyWith(maxConcurrent: value)),
                    ),
                    if (value != 4) const SizedBox(width: 10),
                  ],
                ],
              ),
            ],
          ),
        ),
        NeuSectionTitle(t.haptics),
        _gap(
          NeuListRow(
            title: t.haptics,
            subtitle: t.hapticsHint,
            trailing: NeuToggle(
              value: settings.hapticsEnabled,
              onChanged: (bool value) =>
                  update(settings.copyWith(hapticsEnabled: value)),
            ),
          ),
        ),
        NeuSectionTitle(t.storage),
        _gap(
          NeuListRow(
            title: t.storage,
            subtitle: settings.storagePath ?? t.defaultStorage,
            onTap: () => _pickStorage(context, settings, update, t),
            trailing: NeuIconButton(
              icon: Icons.folder_rounded,
              size: 42,
              iconSize: 18,
              onTap: () => _pickStorage(context, settings, update, t),
            ),
          ),
        ),
        NeuSectionTitle(t.engines),
        for (final DownloadEngine engine
            in AppScope.downloads(context).registry.engines)
          _gap(_EngineRow(engine: engine)),
        NeuSectionTitle(t.about),
        NeuSurface(
          elevation: NeuElevation.pressed,
          radius: NeuTokens.radiusL,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${AppInfo.name} · ${t.version} ${AppInfo.version}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.text),
              ),
              const SizedBox(height: 10),
              Text(
                t.legalNotice,
                style: TextStyle(
                    fontSize: 12.5, height: 1.6, color: palette.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickStorage(BuildContext context, AppSettings settings,
      ValueChanged<AppSettings> update, AppStrings t) async {
    final List<Directory>? found = await getExternalStorageDirectories();
    final List<Directory> volumes = found ?? <Directory>[];
    if (!context.mounted) return;

    final String? picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NeuPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(NeuTokens.radiusL)),
      ),
      builder: (BuildContext sheet) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                NeuListRow(
                  title: t.defaultStorage,
                  subtitle: t.storageHint,
                  onTap: () => Navigator.pop(sheet, ''),
                ),
                for (final Directory volume in volumes)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: NeuListRow(
                      title: _volumeLabel(volume.path),
                      subtitle: volume.path,
                      onTap: () => Navigator.pop(sheet, volume.path),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null) return;
    update(settings.copyWith(storagePath: picked.isEmpty ? null : picked));
  }

  String _volumeLabel(String path) {
    final bool sd = path.contains('external') && !path.contains('emulated');
    return sd ? 'Cartão SD' : 'Armazenamento interno';
  }

  Widget _gap(Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: child,
      );
}

class _EngineRow extends StatelessWidget {
  const _EngineRow({required this.engine});

  final DownloadEngine engine;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    return NeuListRow(
      title: engine.displayName,
      subtitle: engine.id,
      trailing: FutureBuilder<bool>(
        future: engine.isAvailable(),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: palette.accent),
            );
          }
          final bool available = snapshot.data ?? false;
          return Icon(
            available ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
            color: available ? palette.accent : palette.textMuted,
            size: 22,
          );
        },
      ),
    );
  }
}

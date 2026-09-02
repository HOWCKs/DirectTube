import 'package:flutter/material.dart';

import '../core/haptics.dart';
import 'neu_palette.dart';

/// Superfície base do sistema neumórfico.
///
/// * `raised` / `soft` / `strong` desenham sombras externas (elemento levantado);
/// * `pressed` / `pressedSoft` desenham sombras internas via [InnerShadowPainter]
///   (estado ativo/afundado), sempre com a MESMA cor da superfície.
class NeuSurface extends StatelessWidget {
  const NeuSurface({
    super.key,
    this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.radius = NeuTokens.radiusM,
    this.elevation = NeuElevation.raised,
    this.color,
  });

  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double radius;
  final NeuElevation elevation;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final List<NeuShadow> shadows = palette.shadowsFor(elevation);
    final bool inset = elevation.isInset;

    Widget body = child ?? const SizedBox.shrink();
    if (padding != null) {
      body = Padding(padding: padding!, child: body);
    }

    if (inset) {
      body = ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: InnerShadowPainter(
                    shadows: shadows,
                    borderRadius: borderRadius,
                  ),
                ),
              ),
            ),
            body,
          ],
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: borderRadius,
        boxShadow: inset
            ? null
            : shadows
                .map((NeuShadow s) => BoxShadow(
                      color: s.color,
                      offset: s.offset,
                      blurRadius: s.blur,
                    ))
                .toList(growable: false),
      ),
      child: body,
    );
  }
}

/// Envolve qualquer widget com o comportamento de toque do DirectTube:
/// estado pressionado + micro-escala + resposta tátil.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.pressHaptic = HapticStyle.selection,
    this.scale = 0.985,
  });

  final Widget Function(BuildContext context, bool pressed) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;
  final HapticStyle pressHaptic;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.enabled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled
          ? (TapDownDetails _) {
              _set(true);
              Haptics.fire(widget.pressHaptic);
            }
          : null,
      onTapUp: enabled ? (TapUpDetails _) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: enabled ? widget.onTap : null,
      onLongPress: enabled ? widget.onLongPress : null,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: NeuTokens.duration,
        curve: NeuTokens.curve,
        child: widget.builder(context, _pressed),
      ),
    );
  }
}

/// Botão textual (opcionalmente com ícone).
class NeuButton extends StatelessWidget {
  const NeuButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.active = false,
    this.enabled = true,
    this.expand = false,
    this.haptic = HapticStyle.light,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool active;
  final bool enabled;
  final bool expand;
  final HapticStyle haptic;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    return Pressable(
      enabled: enabled,
      onTap: () {
        Haptics.fire(haptic);
        onTap?.call();
      },
      builder: (BuildContext context, bool pressed) {
        final bool sunken = pressed || active;
        final Color fg = active ? palette.accent : palette.text;
        return NeuSurface(
          elevation: sunken ? NeuElevation.pressedSoft : NeuElevation.soft,
          radius: NeuTokens.radiusS,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          width: expand ? double.infinity : null,
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: NeuTokens.textBody,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Botão quadrado de ícone (46x46), usado em listas e na barra de busca.
class NeuIconButton extends StatelessWidget {
  const NeuIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.active = false,
    this.enabled = true,
    this.size = 46,
    this.iconSize = 20,
    this.tooltip,
    this.haptic = HapticStyle.light,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final bool enabled;
  final double size;
  final double iconSize;
  final String? tooltip;
  final HapticStyle haptic;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    final Widget button = Pressable(
      enabled: enabled,
      onTap: () {
        Haptics.fire(haptic);
        onTap?.call();
      },
      builder: (BuildContext context, bool pressed) {
        final bool sunken = pressed || active;
        return NeuSurface(
          elevation: sunken ? NeuElevation.pressedSoft : NeuElevation.soft,
          radius: NeuTokens.radiusS,
          width: size,
          height: size,
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: active ? palette.accent : palette.text,
            ),
          ),
        );
      },
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Chip de seleção (formatos, filtros).
class NeuChip extends StatelessWidget {
  const NeuChip({
    super.key,
    required this.label,
    this.onTap,
    this.active = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    return Pressable(
      enabled: enabled,
      scale: 0.96,
      onTap: () {
        Haptics.fire(HapticStyle.selection);
        onTap?.call();
      },
      builder: (BuildContext context, bool pressed) {
        final bool sunken = pressed || active;
        return NeuSurface(
          elevation: sunken ? NeuElevation.pressedSoft : NeuElevation.soft,
          radius: NeuTokens.radiusS,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: NeuTokens.textSmall + 0.5,
              fontWeight: FontWeight.w600,
              color: active ? palette.accent : palette.textMuted,
            ),
          ),
        );
      },
    );
  }
}

/// Interruptor neumórfico: trilho afundado, botão levantado.
class NeuToggle extends StatelessWidget {
  const NeuToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    return Pressable(
      enabled: enabled,
      scale: 0.97,
      pressHaptic: HapticStyle.none,
      onTap: () {
        if (onChanged == null) return;
        Haptics.fire(HapticStyle.light);
        onChanged!(!value);
      },
      builder: (BuildContext context, bool pressed) {
        return NeuSurface(
          elevation: NeuElevation.pressedSoft,
          radius: NeuTokens.radiusS,
          width: 62,
          height: 34,
          padding: const EdgeInsets.all(4),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: NeuTokens.curve,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: value ? palette.accent : palette.surface,
                shape: BoxShape.circle,
                boxShadow: value
                    ? null
                    : palette.soft
                        .map((NeuShadow s) => BoxShadow(
                              color: s.color,
                              offset: s.offset,
                              blurRadius: s.blur,
                            ))
                        .toList(growable: false),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Campo de texto afundado (inset), usado na busca.
class NeuField extends StatelessWidget {
  const NeuField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.prefixIcon,
    this.suffix,
    this.onSubmitted,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    return NeuSurface(
      elevation: NeuElevation.pressed,
      radius: NeuTokens.radiusL,
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
      child: Row(
        children: <Widget>[
          if (prefixIcon != null) ...<Widget>[
            Icon(prefixIcon, size: 19, color: palette.textMuted),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              keyboardType: keyboardType,
              textInputAction: textInputAction ?? TextInputAction.search,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              cursorColor: palette.accent,
              style: TextStyle(
                fontSize: NeuTokens.textBody,
                fontWeight: FontWeight.w500,
                color: palette.text,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: NeuTokens.textBody,
                  color: palette.textMuted,
                ),
              ),
            ),
          ),
          if (suffix != null) ...<Widget>[const SizedBox(width: 8), suffix!],
        ],
      ),
    );
  }
}

/// Barra de progresso: trilho afundado, preenchimento no acento.
class NeuProgressBar extends StatelessWidget {
  const NeuProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.showThumb = false,
  });

  /// 0.0 a 1.0 (valores fora disso são truncados).
  final double value;
  final double height;
  final bool showThumb;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    final double clamped = value.clamp(0.0, 1.0);
    final BorderRadius radius = BorderRadius.circular(NeuTokens.radiusS);

    return SizedBox(
      height: showThumb ? height + 8 : height,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          NeuSurface(
            elevation: NeuElevation.pressedSoft,
            radius: NeuTokens.radiusS,
            height: height,
            width: double.infinity,
          ),
          FractionallySizedBox(
            widthFactor: clamped == 0 ? 0.0001 : clamped,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: radius,
              ),
            ),
          ),
          if (showThumb && clamped > 0.02)
            Align(
              alignment: Alignment(clamped * 2 - 1, 0),
              child: Container(
                width: height + 8,
                height: height + 8,
                decoration: BoxDecoration(
                  color: palette.surface,
                  shape: BoxShape.circle,
                  boxShadow: palette.soft
                      .map((NeuShadow s) => BoxShadow(
                            color: s.color,
                            offset: s.offset,
                            blurRadius: s.blur,
                          ))
                      .toList(growable: false),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Título de seção (caixa alta, espaçado).
class NeuSectionTitle extends StatelessWidget {
  const NeuSectionTitle(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(2, 26, 2, 14),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: NeuTokens.textSmall,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: palette.textMuted,
        ),
      ),
    );
  }
}

/// Item da barra de navegação inferior.
class NeuTabItem {
  const NeuTabItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Barra de navegação inferior neumórfica (levantada, item ativo afundado).
class NeuTabBar extends StatelessWidget {
  const NeuTabBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<NeuTabItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    return NeuSurface(
      elevation: NeuElevation.raised,
      radius: NeuTokens.radiusL,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: Pressable(
                scale: 0.94,
                pressHaptic: HapticStyle.none,
                onTap: () {
                  Haptics.fire(HapticStyle.light);
                  onChanged(i);
                },
                builder: (BuildContext context, bool pressed) {
                  final bool active = i == index;
                  final Color color =
                      active ? palette.accent : palette.textMuted;
                  return NeuSurface(
                    elevation: active || pressed
                        ? NeuElevation.pressedSoft
                        : NeuElevation.soft,
                    radius: NeuTokens.radiusS,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(items[i].icon, size: 21, color: color),
                        const SizedBox(height: 5),
                        Text(
                          items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Linha padrão de listas (biblioteca, ajustes): rótulo + controle à direita.
class NeuListRow extends StatelessWidget {
  const NeuListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;

  /// Conteúdo alternativo ao título/subtítulo (ex.: barra de progresso).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final NeuPalette palette = NeuPalette.of(context);
    final Widget row = NeuSurface(
      elevation: NeuElevation.raised,
      radius: NeuTokens.radiusM,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: 14)],
          Expanded(child: child ?? _labels(palette)),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 14),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Pressable(onTap: onTap, builder: (BuildContext c, bool p) => row);
  }

  Widget _labels(NeuPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: palette.text,
            height: 1.3,
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: palette.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

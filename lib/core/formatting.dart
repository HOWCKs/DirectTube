/// Formatação de bytes, durações e velocidades para a UI.
/// Puro e testável (`test/formatting_test.dart`).
class Fmt {
  const Fmt._();

  static const List<String> _units = <String>['B', 'KB', 'MB', 'GB', 'TB'];

  /// `bytes(1_572_864)` -> `"1,5 MB"`.
  static String bytes(num? value, {int decimals = 1}) {
    if (value == null) return '—';
    if (value <= 0) return '0 B';

    double v = value.toDouble();
    int unit = 0;
    while (v >= 1024 && unit < _units.length - 1) {
      v /= 1024;
      unit++;
    }
    if (unit == 0) return '${v.round()} B';
    return '${v.toStringAsFixed(decimals).replaceAll('.', ',')} ${_units[unit]}';
  }

  /// `duration(Duration(seconds: 4624))` -> `"1:17:04"`.
  static String duration(Duration? value) {
    if (value == null) return '--:--';
    final int hours = value.inHours;
    final int minutes = value.inMinutes.remainder(60);
    final int seconds = value.inSeconds.remainder(60);
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$minutes:$ss';
  }

  /// `speed(4_400_000)` -> `"4,2 MB/s"`.
  static String speed(num bytesPerSecond) => '${bytes(bytesPerSecond)}/s';

  /// Progresso legível: `"42%"`.
  static String percent(double value) =>
      '${(value.clamp(0.0, 1.0) * 100).round()}%';
}

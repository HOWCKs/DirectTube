import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// Conversões de áudio no dispositivo via FFmpeg (mesma família de tecnologia
/// dos grandes baixadores). Falha de forma segura quando o módulo não existe.
class Ffmpeg {
  const Ffmpeg._();

  /// Converte [input] (m4a/webm/…) para MP3 em [output].
  static Future<bool> toMp3(String input, String output) async {
    try {
      final session = await FFmpegKit.execute(
          '-y -i "$input" -c:a libmp3lame -q:a 2 "$output"');
      final ReturnCode? rc = await session.getReturnCode();
      return ReturnCode.isSuccess(rc);
    } catch (_) {
      return false;
    }
  }
}

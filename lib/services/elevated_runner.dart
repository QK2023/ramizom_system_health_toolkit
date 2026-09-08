import 'dart:convert';
import 'dart:io';
import 'windows_paths.dart';

/// Runs only application-owned scripts. UAC cancellation and launcher errors
/// must never be reported as successful system changes.
class ElevatedRunner {
  static String encode(String script) => base64Encode([
    for (final unit in script.codeUnits) ...[unit & 0xff, unit >> 8],
  ]);

  static Future<int> run(String script) async {
    if (!Platform.isWindows || Platform.environment['FLUTTER_TEST'] == 'true') {
      return -1;
    }
    try {
      final encoded = encode("\$ErrorActionPreference = 'Stop'\n$script");
      final result = await Process.run(WindowsPaths.powershell, [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        "\$ErrorActionPreference = 'Stop'; try { "
            "\$powershell = Join-Path \$env:SystemRoot 'System32\\WindowsPowerShell\\v1.0\\powershell.exe'; "
            "\$process = Start-Process -FilePath \$powershell -Verb RunAs "
            "-WindowStyle Hidden -PassThru -Wait -ArgumentList "
            "'-NoLogo','-NoProfile','-NonInteractive','-EncodedCommand','$encoded'; "
            'exit \$process.ExitCode } catch { exit 1 }',
      ]);
      return result.exitCode;
    } catch (_) {
      return -1;
    }
  }
}

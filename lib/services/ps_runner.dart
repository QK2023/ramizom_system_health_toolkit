import 'dart:convert';
import 'dart:io';

import 'windows_paths.dart';

class PsResult {
  final String stdout;
  final String stderr;
  final int exitCode;
  final bool timedOut;

  const PsResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    this.timedOut = false,
  });

  bool get succeeded => !timedOut && exitCode == 0 && stdout.isNotEmpty;
}

/// 共享的 PowerShell 执行工具。
class PsRunner {
  PsRunner._();

  // 这是后台命令的安全上限，不是界面加载动画的时限。
  // 某些机器首次加载 WMI/Defender 模块需要数秒，不能为了 UI 响应直接杀掉。
  static const defaultTimeout = Duration(seconds: 15);

  /// 执行脚本并在超时后终止 PowerShell，避免页面无限等待。
  static Future<PsResult> runResult(
    String script, {
    Duration timeout = defaultTimeout,
  }) async {
    if (!Platform.isWindows || Platform.environment['FLUTTER_TEST'] == 'true') {
      return const PsResult(stdout: '', stderr: '当前环境不执行系统采集', exitCode: -1);
    }

    Process? process;
    try {
      process = await Process.start(WindowsPaths.powershell, [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        _utf8Preamble + script,
      ]);

      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      var timedOut = false;
      final exitCode = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          timedOut = true;
          process?.kill();
          return -1;
        },
      );
      final output = await Future.wait([stdoutFuture, stderrFuture]).timeout(
        const Duration(seconds: 1),
        onTimeout: () => const ['', 'PowerShell 输出流关闭超时'],
      );
      final result = PsResult(
        stdout: output[0].trim(),
        stderr: output[1].trim(),
        exitCode: exitCode,
        timedOut: timedOut,
      );
      if (!result.succeeded && result.stderr.isNotEmpty) {
        debugPrint('PsRunner: ${result.stderr}');
      }
      return result;
    } catch (e) {
      process?.kill();
      debugPrint('PsRunner exception: $e');
      return PsResult(stdout: '', stderr: '$e', exitCode: -1);
    }
  }

  static Future<String> run(
    String script, {
    Duration timeout = defaultTimeout,
  }) async {
    return (await runResult(script, timeout: timeout)).stdout;
  }

  static const _utf8Preamble = r'''
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding
$ProgressPreference = 'SilentlyContinue'
''';

  static void debugPrint(String message) {
    // ignore: avoid_print
    if (!bool.hasEnvironment('dart.vm.product')) print(message);
  }
}

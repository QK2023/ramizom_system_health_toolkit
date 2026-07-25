import 'dart:io';

/// 只返回 Windows 自带程序的绝对路径，避免从当前目录或 PATH 加载同名程序。
class WindowsPaths {
  WindowsPaths._();

  static String get systemRoot {
    final value =
        Platform.environment['SystemRoot'] ?? Platform.environment['WINDIR'];
    return value != null && value.trim().isNotEmpty ? value : r'C:\Windows';
  }

  static String get system32 => '$systemRoot${Platform.pathSeparator}System32';

  static String get powershell =>
      '$system32${Platform.pathSeparator}WindowsPowerShell'
      '${Platform.pathSeparator}v1.0${Platform.pathSeparator}powershell.exe';

  static String systemExecutable(String name) =>
      '$system32${Platform.pathSeparator}$name';
}

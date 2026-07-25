import 'dart:io';

import 'windows_paths.dart';

/// Windows 设置与受信任网页的快捷跳转服务。
class QuickJump {
  QuickJump._();

  static const _allowedWebUrls = {
    'https://ramizom.com',
    'https://ramizom.com/privacy',
  };

  /// 常用 Windows 设置 URI 映射表
  static const _uris = <String, String>{
    'Windows 更新': 'ms-settings:windowsupdate',
    'Windows 安全中心': 'ms-settings:windowsdefender',
    '防火墙': 'ms-settings:windowsdefender-firewall',
    '存储': 'ms-settings:storagesense',
    '磁盘清理': 'ms-settings:storagesense',
    '电源': 'ms-settings:powersleep',
    '节能建议': 'ms-settings:energyrecommendations',
    '电池使用情况': 'ms-settings:batterysaver-usagedetails',
    '图形设置': 'ms-settings:display-advancedgraphics',
    '游戏模式': 'ms-settings:gaming-gamemode',
    '应用': 'ms-settings:appsfeatures',
    '启动项': 'ms-settings:startupapps',
    '隐私': 'ms-settings:privacy',
    '蓝牙': 'ms-settings:bluetooth',
    '网络': 'ms-settings:network-status',
    '显示': 'ms-settings:display',
    '声音': 'ms-settings:sound',
    '账户': 'ms-settings:yourinfo',
    '任务管理器': 'taskmgr',
    '系统信息': 'ms-settings:about',
    '系统版本': 'ms-settings:about',
    '设备管理器': 'devmgmt.msc',
    '控制面板': 'control',
    '定位': 'ms-settings:privacy-location',
    '相机': 'ms-settings:privacy-webcam',
    '麦克风': 'ms-settings:privacy-microphone',
    '屏幕捕获': 'ms-settings:privacy-graphicscaptureprogrammatic',
    '磁盘加密': 'ms-settings:deviceencryption',
  };

  /// 根据名称获取 URI，找不到返回 null。
  static String? uri(String name) => _uris[name];

  /// 打开对应的 Windows 设置页面 / 系统工具。
  /// [name] 为 `_uris` 中的键。
  /// 返回 `true` 表示启动命令已发出（不代表目标窗口已打开）。
  static Future<bool> launch(String name) async {
    final target = uri(name);
    if (target == null || !Platform.isWindows) return false;
    try {
      if (target.contains(':')) {
        // 使用 cmd /c start 处理 ms-settings: 等 URI scheme，
        // 比 explorer.exe 更可靠。
        await Process.run(WindowsPaths.systemExecutable('cmd.exe'), [
          '/c',
          'start',
          '',
          target,
        ]);
        return true;
      } else if (target == 'taskmgr') {
        await Process.start(
          WindowsPaths.systemExecutable('Taskmgr.exe'),
          const [],
          mode: ProcessStartMode.detached,
        );
        return true;
      } else if (target == 'devmgmt.msc') {
        await Process.start(
          WindowsPaths.systemExecutable('mmc.exe'),
          const ['devmgmt.msc'],
          mode: ProcessStartMode.detached,
        );
        return true;
      } else if (target == 'control') {
        await Process.start(
          WindowsPaths.systemExecutable('control.exe'),
          const [],
          mode: ProcessStartMode.detached,
        );
        return true;
      }
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('QuickJump.launch("$name") error: $e');
      return false;
    }
  }

  /// 使用系统默认浏览器打开 HTTPS 页面。
  static Future<bool> launchUrl(String url) async {
    if (!Platform.isWindows || !isAllowedWebUrl(url)) {
      return false;
    }
    try {
      await Process.run(WindowsPaths.systemExecutable('cmd.exe'), [
        '/c',
        'start',
        '',
        url,
      ]);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('QuickJump.launchUrl("$url") error: $e');
      return false;
    }
  }

  static bool isAllowedWebUrl(String url) => _allowedWebUrls.contains(url);
}

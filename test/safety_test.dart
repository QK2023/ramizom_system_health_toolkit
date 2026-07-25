import 'package:flutter_test/flutter_test.dart';
import 'package:system_health_toolkit/services/quick_jump.dart';
import 'package:system_health_toolkit/services/windows_paths.dart';

void main() {
  test('web links allow only the two built-in Ramizom HTTPS pages', () {
    expect(QuickJump.isAllowedWebUrl('https://ramizom.com'), isTrue);
    expect(QuickJump.isAllowedWebUrl('https://ramizom.com/privacy'), isTrue);
    expect(QuickJump.isAllowedWebUrl('http://ramizom.com'), isFalse);
    expect(
      QuickJump.isAllowedWebUrl('https://ramizom.com.example/privacy'),
      isFalse,
    );
    expect(
      QuickJump.isAllowedWebUrl('https://ramizom.com/privacy?next=cmd'),
      isFalse,
    );
  });

  test('system tools resolve below the Windows system directory', () {
    final normalizedSystem32 = WindowsPaths.system32.toLowerCase();
    expect(
      WindowsPaths.powershell.toLowerCase().startsWith(normalizedSystem32),
      isTrue,
    );
    expect(
      WindowsPaths.systemExecutable(
        'powercfg.exe',
      ).toLowerCase().startsWith(normalizedSystem32),
      isTrue,
    );
  });
}

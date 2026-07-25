import 'package:flutter_test/flutter_test.dart';
import 'package:system_health_toolkit/services/power_monitor.dart';

void main() {
  test('parses Windows battery report HTML and historical curves', () {
    final report = PowerMonitor.parseHtml(_fixture);

    expect(report.hasBattery, isTrue);
    expect(report.batteryName, 'TEST BATTERY');
    expect(report.designCapacityMwh, 60000);
    expect(report.fullChargeCapacityMwh, 48000);
    expect(report.currentPercent, 75);
    expect(report.currentCapacityMwh, 36000);
    expect(report.healthPercent, 80);
    expect(report.usageHistory, hasLength(2));
    expect(report.usageHistory.first.percent, 75);
    expect(report.usageHistory.last.percent, 50);
    expect(report.capacityHistory, hasLength(1));
    expect(report.capacityHistory.single.healthPercent, 80);
  });
}

const _fixture = '''
<html><head><script>
drainGraphData = [
  { x0: "2026-07-24T10:00:00", x1: "2026-07-24T12:00:00",
    y0: 0.75, y1: 0.50 }
];
</script></head><body>
<table>
<tr><td class="label">REPORT TIME</td><td>2026-07-25 09:30:00</td></tr>
</table>
<h2>Installed batteries</h2>
<table>
<tr><td><span class="label">NAME</span></td><td>TEST BATTERY</td></tr>
<tr><td><span class="label">MANUFACTURER</span></td><td>TEST</td></tr>
<tr><td><span class="label">DESIGN CAPACITY</span></td><td>60,000 mWh</td></tr>
<tr><td><span class="label">FULL CHARGE CAPACITY</span></td><td>48,000 mWh</td></tr>
<tr><td><span class="label">CYCLE COUNT</span></td><td>200</td></tr>
</table>
<h2>Recent usage</h2>
<table><tr><td>Report generated</td><td class="percent">75 %</td>
<td class="mw">36,000 mWh</td></tr></table>
<h2>Battery usage</h2>
<h2>Battery capacity history</h2>
<table>
<tr><td>PERIOD</td><td>FULL CHARGE CAPACITY</td><td>DESIGN CAPACITY</td></tr>
<tr><td>2026-07-01 - 2026-07-08</td><td>48,000 mWh</td>
<td>60,000 mWh</td></tr>
</table>
<h2>Battery life estimates</h2>
</body></html>
''';

// Runs integration_test/perf_test.dart on a device, and prints the frame
// times of each scenario. See README.md.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:integration_test/integration_test_driver.dart';

/// The time a frame has at 120 Hz, and at 60 Hz, in microseconds.
const _budgets = [8333, 16667];

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final label = Platform.environment['PERF_LABEL'] ?? 'run';
    final file = File('build/perf_$label.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(data));
    stdout
      ..writeln()
      ..writeln('UI thread (build) and raster thread times per frame, in ms:')
      ..writeln(
        '${'scenario'.padRight(13)} frames  build avg/p90/p99/max      '
        'raster avg/p90/p99/max     over 8.3 / 16.7 ms',
      );
    for (final MapEntry(key: scenario, :value) in data!.entries) {
      final summary = value as Map<String, dynamic>;
      final build = _times(summary['frame_build_times']);
      final raster = _times(summary['frame_rasterizer_times']);
      final over = [
        for (final budget in _budgets)
          '${build.where((t) => t > budget).length}'
              '/${raster.where((t) => t > budget).length}',
      ];
      stdout.writeln(
        '${scenario.padRight(13)} ${'${build.length}'.padLeft(6)}  '
        '${_stats(build).padRight(25)} ${_stats(raster).padRight(25)} '
        '${over.join(' / ')} (build/raster)',
      );
    }
    stdout.writeln('Saved to ${file.path}.');
  },
);

List<int> _times(Object? times) => [...(times as List).cast<int>()]..sort();

/// The average, 90th and 99th percentiles and the worst of sorted [times].
String _stats(List<int> times) {
  if (times.isEmpty) return '-';
  String ms(num microseconds) => (microseconds / 1000).toStringAsFixed(2);
  int at(double percentile) =>
      times[math.min(times.length - 1, (percentile * times.length).floor())];
  final average = times.reduce((a, b) => a + b) / times.length;
  return [ms(average), ms(at(0.9)), ms(at(0.99)), ms(times.last)].join('/');
}

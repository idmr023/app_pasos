import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

final outDir = Directory(r'C:\Users\idmr_\AppData\Local\Temp\opencode');

Future<void> main(List<String> args) async {
  final specFile = File(args.first);
  final commands = jsonDecode(await specFile.readAsString()) as List<dynamic>;
  final vmUrl =
      args.length > 1 ? args[1] : 'http://127.0.0.1:49188/PVZBSnjJRR8=/';

  final FlutterDriver driver = await FlutterDriver.connect(
    dartVmServiceUrl: vmUrl,
  );
  await driver.checkHealth();

  final buffer = StringBuffer();
  try {
    for (final raw in commands) {
      final cmd = raw as Map<String, dynamic>;
      final name = cmd['cmd'] as String;
      try {
        switch (name) {
          case 'sleep':
            await Future<void>.delayed(
              Duration(milliseconds: cmd['ms'] as int),
            );
            break;
          case 'dump':
            final label = cmd['label'] as String? ?? 'tree';
            final resp = await driver.serviceClient.callServiceExtension(
              'ext.flutter.inspector.getRootWidgetTree',
              isolateId: driver.appIsolate.id,
            );
            final tree =
                resp.json!['result']; // ignore: unnecessary_non_null_assertion
            final file = File(
              '${outDir.path}${Platform.pathSeparator}tree_$label.json',
            );
            await file.writeAsString(jsonEncode(tree), flush: true);
            buffer.writeln('dumped tree -> ${file.path}');
            break;
          case 'tap':
            await driver.tap(_finder(cmd), timeout: _timeout(cmd));
            break;
          case 'text':
            final t = await driver.getText(
              _finder(cmd),
              timeout: _timeout(cmd),
            );
            buffer.writeln('TEXT[${cmd['label']}] = $t');
            break;
          case 'wait':
            await driver.waitFor(_finder(cmd), timeout: _timeout(cmd));
            buffer.writeln('FOUND ${cmd['finder']}');
            break;
          case 'absent':
            await driver.waitForAbsent(_finder(cmd), timeout: _timeout(cmd));
            buffer.writeln('ABSENT ${cmd['finder']}');
            break;
          case 'req':
            final value = cmd['value'] as String? ?? '';
            final r = await driver.requestData(value);
            buffer.writeln('REQ[${cmd['label']}] = $r');
            break;
          case 'scroll':
            final f = _finder(cmd['finder'] as Map<String, dynamic>);
            final dx = (cmd['dx'] as num).toDouble();
            final dy = (cmd['dy'] as num).toDouble();
            final duration = Duration(
              milliseconds: cmd['duration'] as int? ?? 500,
            );
            await driver.scroll(
              f,
              dx,
              dy,
              duration,
              frequency: cmd['frequency'] as int? ?? 60,
            );
            break;
          default:
            buffer.writeln('UNKNOWN:$name');
        }
        buffer.writeln('>>> ok: $name');
      } catch (e) {
        buffer.writeln('>>> ERROR: $name -> $e');
      }
    }
  } finally {
    await driver.close();
  }

  await File(
    '${outDir.path}${Platform.pathSeparator}discover_out.txt',
  ).writeAsString(buffer.toString(), flush: true);
  stdout.writeln('DISCOVERY FINISHED');
  stdout.writeln(buffer.toString());
}

Duration _timeout(Map<String, dynamic> cmd) =>
    Duration(milliseconds: cmd['timeout'] as int? ?? 10000);

SerializableFinder _finder(Map<String, dynamic> raw) {
  final type = raw['finder'] as String;
  return switch (type) {
    'text' => find.text(raw['value'] as String),
    'tooltip' => find.byTooltip(raw['value'] as String),
    'type' => find.byType(raw['value'] as String),
    'key' => find.byValueKey(raw['value'] as String),
    _ => throw ArgumentError('unknown finder: $type'),
  };
}

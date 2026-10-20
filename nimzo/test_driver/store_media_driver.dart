import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output = Directory('build/premium-store-runtime');
  await output.create(recursive: true);
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          if (bytes.length < 1000) return false;
          final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          await File('${output.path}/$safeName.png')
              .writeAsBytes(bytes, flush: true);
          return true;
        },
    responseDataCallback: (data) async {
      await writeResponseData(
        data,
        testOutputFilename: 'store-native-media',
        destinationDirectory: output.path,
      );
    },
  );
}

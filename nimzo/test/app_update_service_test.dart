import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:nimzo/core/services/app_update_service.dart';

void main() {
  final certificate = List.filled(64, 'a').join();
  final installed = PackageInfo(
      appName: 'Nimzo',
      packageName: 'com.nimzo.app',
      version: '1.0.5',
      buildNumber: '105',
      buildSignature: certificate);
  Map<String, dynamic> manifest(
          {int build = 106, String? url, String? signature}) =>
      {
        'version': '1.0.6',
        'buildNumber': build,
        'packageName': 'com.nimzo.app',
        'signingCertificateSha256': signature ?? certificate,
        'apkSha256': List.filled(64, 'b').join(),
        'apkUrl': url ??
            'https://github.com/adi4ch-cmd/Nimzo/releases/download/v106/app-release.apk',
      };
  const manifestUrl =
      'https://github.com/adi4ch-cmd/Nimzo/releases/download/v106/nimzo-update.json';
  NimzoUpdateChecker checker(Map<String, dynamic> data,
          {bool android = true}) =>
      NimzoUpdateChecker(
        isAndroid: () => android,
        packageInfo: () async => installed,
        fetchJson: (uri) async => uri.host == 'api.github.com'
            ? jsonEncode([
                {
                  'draft': false,
                  'assets': [
                    {
                      'name': 'nimzo-update.json',
                      'browser_download_url': manifestUrl
                    }
                  ]
                }
              ])
            : jsonEncode(data),
      );
  test('offers higher build from compatible manifest', () async {
    final update = await checker(manifest()).check();
    expect(update?.build, 106);
    expect(update?.apkSha256, manifest()['apkSha256']);
    expect(update?.packageName, installed.packageName);
    expect(update?.signingCertificateSha256, certificate);
  });
  test('rejects same and older builds', () async {
    expect(await checker(manifest(build: 105)).check(), isNull);
    expect(await checker(manifest(build: 104)).check(), isNull);
  });
  test('rejects other signing certificate', () async {
    expect(
        await checker(manifest(signature: List.filled(64, 'c').join())).check(),
        isNull);
  });
  test('rejects other repository and HTTP APK URLs', () async {
    for (final url in [
      'https://github.com/evil/Nimzo/releases/download/v106/app-release.apk',
      'http://github.com/adi4ch-cmd/Nimzo/releases/download/v106/app-release.apk'
    ]) {
      expect(await checker(manifest(url: url)).check(), isNull);
    }
  });
  test('unsupported platforms do not fetch metadata', () async {
    expect(await checker(manifest(), android: false).check(), isNull);
  });
  test('concurrent checks share one request sequence', () async {
    var calls = 0;
    final subject = NimzoUpdateChecker(
        isAndroid: () => true,
        packageInfo: () async => installed,
        fetchJson: (uri) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return uri.host == 'api.github.com'
              ? jsonEncode([
                  {
                    'assets': [
                      {
                        'name': 'nimzo-update.json',
                        'browser_download_url': manifestUrl
                      }
                    ]
                  }
                ])
              : jsonEncode(manifest());
        });
    await Future.wait([subject.check(), subject.check()]);
    expect(calls, 2);
  });
  test('different package and invalid checksum cannot be offered', () async {
    final wrongPackage = manifest()..['packageName'] = 'other.app';
    expect(await checker(wrongPackage).check(), isNull);
    final badHash = manifest()..['apkSha256'] = 'invalid';
    expect(await checker(badHash).check(), isNull);
  });
  test('transport failure remains an error and can be retried', () async {
    final subject = NimzoUpdateChecker(
        isAndroid: () => true,
        packageInfo: () async => installed,
        fetchJson: (_) async => throw const FormatException('network failure'));
    await expectLater(subject.check(), throwsFormatException);
    await expectLater(subject.check(), throwsFormatException);
  });
  test('untrusted manifest URL is never fetched', () async {
    final subject = NimzoUpdateChecker(
        isAndroid: () => true,
        packageInfo: () async => installed,
        fetchJson: (uri) async {
          if (uri.host != 'api.github.com') fail('Untrusted metadata fetched');
          return jsonEncode([
            {
              'assets': [
                {
                  'name': 'nimzo-update.json',
                  'browser_download_url':
                      'https://github.com/other/Nimzo/releases/download/v106/nimzo-update.json'
                }
              ]
            }
          ]);
        });
    expect(await subject.check(), isNull);
  });
  test('APK must belong to the manifest release tag', () async {
    expect(
        await checker(manifest(
                url:
                    'https://github.com/adi4ch-cmd/Nimzo/releases/download/other/app-release.apk'))
            .check(),
        isNull);
  });
  test('unknown installed signing certificate cannot be offered updates',
      () async {
    final subject = NimzoUpdateChecker(
        isAndroid: () => true,
        packageInfo: () async => PackageInfo(
            appName: 'Nimzo',
            packageName: 'com.nimzo.app',
            version: '1.0.5',
            buildNumber: '105'),
        fetchJson: (_) async =>
            fail('Unknown certificate fetched release metadata'));
    expect(await subject.check(), isNull);
  });
  testWidgets(
      'navigator context shows one optional dialog and failed verified download is visible',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final subject = NimzoUpdatePrompter(
        isAndroid: () => true,
        checkForUpdate: () async => AppUpdate(
            106, 'NIMZO 1.0.6', Uri.parse(manifest()['apkUrl'] as String)),
        downloadAndInstall: (_) async =>
            throw PlatformException(code: 'DOWNLOAD_FAILED'));
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey, home: const Scaffold(body: Text('Home'))));
    final context = navigatorKey.currentContext!;
    final first = subject.prompt(context);
    final concurrent = subject.prompt(context);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    await Future.wait([first, concurrent]);
    expect(
        find.text('Could not download or verify the update. Try again later.'),
        findsOneWidget);
    await subject.prompt(context);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('manual no-update and failed check have distinct feedback',
      (tester) async {
    late BuildContext context;
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (value) {
      context = value;
      return const Text('Settings');
    }))));
    final empty = NimzoUpdatePrompter(
        isAndroid: () => true, checkForUpdate: () async => null);
    await empty.prompt(context, showUpToDate: true);
    await tester.pumpAndSettle();
    expect(
        find.text('No newer compatible testing update found.'), findsOneWidget);
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    final failed = NimzoUpdatePrompter(
        isAndroid: () => true,
        checkForUpdate: () async => throw const FormatException('Failed'));
    await failed.prompt(context, showUpToDate: true);
    await tester.pumpAndSettle();
    expect(
        find.text('Could not check updates. Try again later.'), findsOneWidget);
  });
  test('unavailable latest manifest still allows compatible earlier release',
      () async {
    final subject = NimzoUpdateChecker(
        isAndroid: () => true,
        packageInfo: () async => installed,
        fetchJson: (uri) async {
          if (uri.host == 'api.github.com')
            return jsonEncode([
              {
                'assets': [
                  {
                    'name': 'nimzo-update.json',
                    'browser_download_url':
                        manifestUrl.replaceAll('v106', 'v107')
                  }
                ]
              },
              {
                'assets': [
                  {
                    'name': 'nimzo-update.json',
                    'browser_download_url': manifestUrl
                  }
                ]
              }
            ]);
          if (uri.path.contains('v107'))
            throw const FormatException('Bad release');
          return jsonEncode(manifest());
        });
    expect((await subject.check())?.build, 106);
  });
  test('native installer receives every verified manifest field', () async {
    const channel = MethodChannel('nimzo/app_update');
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return 'installerOpened';
    });
    final update = AppUpdate(
        106, 'NIMZO', Uri.parse(manifest()['apkUrl'] as String),
        apkSha256: manifest()['apkSha256'] as String,
        packageName: 'com.nimzo.app',
        signingCertificateSha256: certificate);
    expect(await NimzoAppUpdateService.downloadAndInstall(update),
        'installerOpened');
    expect(received!.method, 'downloadAndInstall');
    expect(received!.arguments, {
      'url': update.url.toString(),
      'sha256': update.apkSha256,
      'buildNumber': 106,
      'packageName': 'com.nimzo.app',
      'signingCertificateSha256': certificate,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  testWidgets(
      'verified download shows protected progress and permission instructions',
      (tester) async {
    late BuildContext context;
    final result = Completer<String>();
    final subject = NimzoUpdatePrompter(
        isAndroid: () => true,
        checkForUpdate: () async =>
            AppUpdate(106, 'NIMZO', Uri.parse(manifest()['apkUrl'] as String)),
        downloadAndInstall: (_) => result.future);
    await tester
        .pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (value) {
      context = value;
      return const Text('Home');
    }))));
    final task = subject.prompt(context);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Downloading and verifying update…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await subject.prompt(context, showUpToDate: true);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    result.complete('permissionRequired');
    await tester.pumpAndSettle();
    await task;
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
        find.text(
            'Allow NIMZO to install apps in Android settings. Return to NIMZO to confirm installation.'),
        findsOneWidget);
  });
  test(
      'unexpected native response is rejected rather than claiming installation',
      () async {
    const channel = MethodChannel('nimzo/app_update');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => 'installed');
    final update =
        AppUpdate(106, 'NIMZO', Uri.parse(manifest()['apkUrl'] as String));
    await expectLater(NimzoAppUpdateService.downloadAndInstall(update),
        throwsFormatException);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}

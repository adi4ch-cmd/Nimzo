import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/services.dart';

/// Optional verified Android updates. Installation always requires user consent.
class NimzoAppUpdateService {
  static const _api =
      'https://api.github.com/repos/adi4ch-cmd/Nimzo/releases?per_page=15';

  static const _channel = MethodChannel('nimzo/app_update');
  static Future<String> downloadAndInstall(AppUpdate update) async {
    final result = await _channel.invokeMethod<String>('downloadAndInstall', {
      'url': update.url.toString(),
      'sha256': update.apkSha256,
      'buildNumber': update.build,
      'packageName': update.packageName,
      'signingCertificateSha256': update.signingCertificateSha256,
    });
    if (result != 'installerOpened' && result != 'permissionRequired') {
      throw const FormatException('Unexpected installer response');
    }
    return result!;
  }

  static final _checker = NimzoUpdateChecker();
  static Future<AppUpdate?> check() => _checker.check();
  static final _prompter = NimzoUpdatePrompter(checkForUpdate: check);
  static Future<void> prompt(
    BuildContext context, {
    bool showUpToDate = false,
  }) => _prompter.prompt(context, showUpToDate: showUpToDate);
}

class NimzoUpdatePrompter {
  NimzoUpdatePrompter({
    required this.checkForUpdate,
    bool Function()? isAndroid,
    Future<String> Function(AppUpdate)? downloadAndInstall,
  }) : isAndroid = isAndroid ?? (() => !kIsWeb && Platform.isAndroid),
       downloadAndInstall =
           downloadAndInstall ?? NimzoAppUpdateService.downloadAndInstall;
  final Future<AppUpdate?> Function() checkForUpdate;
  final bool Function() isAndroid;
  final Future<String> Function(AppUpdate) downloadAndInstall;
  bool _promptInFlight = false;
  final Set<int> _promptedBuilds = {};

  Future<void> prompt(BuildContext context, {bool showUpToDate = false}) async {
    if (_promptInFlight) return;
    if (!isAndroid()) {
      if (showUpToDate)
        _message(context, 'APK updates are available on Android only.');
      return;
    }
    _promptInFlight = true;
    try {
      final update = await checkForUpdate();
      if (!context.mounted) return;
      if (update == null) {
        if (showUpToDate) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No newer compatible testing update found.'),
            ),
          );
        }
        return;
      }
      if (!showUpToDate && !_promptedBuilds.add(update.build)) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('NIMZO update available'),
          content: Text(
            '${update.title}\n\nDownload the new APK? Android will ask you to confirm installation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Update'),
            ),
          ],
        ),
      );
      if (accepted == true && context.mounted) await _install(context, update);
    } catch (_) {
      if (showUpToDate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not check updates. Try again later.'),
          ),
        );
      }
    } finally {
      _promptInFlight = false;
    }
  }

  Future<void> _install(BuildContext context, AppUpdate update) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final progress = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('Updating NIMZO'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Downloading and verifying update…'),
            ],
          ),
        ),
      ),
    );
    navigator.push(progress);
    String message;
    try {
      final result = await downloadAndInstall(update);
      message = switch (result) {
        'installerOpened' =>
          'Android installer opened. Confirm installation to update NIMZO.',
        'permissionRequired' => 'Allow NIMZO to install apps in Android settings. Return to NIMZO to confirm installation.',
        _ => 'Could not download or verify the update. Try again later.',
      };
    } catch (_) {
      message = 'Could not download or verify the update. Try again later.';
    } finally {
      if (navigator.mounted && progress.isActive)
        navigator.removeRoute(progress);
    }
    if (context.mounted) _message(context, message);
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }
}

class AppUpdate {
  final int build;
  final String title;
  final Uri url;
  final String apkSha256;
  final String packageName;
  final String signingCertificateSha256;
  const AppUpdate(
    this.build,
    this.title,
    this.url, {
    this.apkSha256 = '',
    this.packageName = '',
    this.signingCertificateSha256 = '',
  });
}

/// Reads only this project's release metadata. Android remains responsible for
/// installation and verifies the APK signature after the user downloads it.
class NimzoUpdateChecker {
  NimzoUpdateChecker({
    bool Function()? isAndroid,
    Future<PackageInfo> Function()? packageInfo,
    Future<String> Function(Uri)? fetchJson,
  }) : _isAndroid = isAndroid ?? (() => !kIsWeb && Platform.isAndroid),
       _packageInfo = packageInfo ?? PackageInfo.fromPlatform,
       _fetchJson = fetchJson ?? _readJson;

  final bool Function() _isAndroid;
  final Future<PackageInfo> Function() _packageInfo;
  final Future<String> Function(Uri) _fetchJson;
  Future<AppUpdate?>? _inFlight;
  static const _timeout = Duration(seconds: 10);
  static final _digest = RegExp(r'^[a-f0-9]{64}$');

  Future<AppUpdate?> check() {
    if (!_isAndroid()) return Future.value();
    return _inFlight ??= _check().whenComplete(() => _inFlight = null);
  }

  Future<AppUpdate?> _check() async {
    return await _compatibleRelease().timeout(const Duration(seconds: 30));
  }

  Future<AppUpdate?> _compatibleRelease() async {
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    final installed = await _packageInfo().timeout(_timeout);
    final current = int.tryParse(installed.buildNumber);
    final signature = _normalize(installed.buildSignature);
    if (current == null || !_digest.hasMatch(signature)) return null;
    final releases = jsonDecode(
      await _fetchJson(Uri.parse(NimzoAppUpdateService._api)).timeout(_timeout),
    );
    if (releases is! List) throw const FormatException('Invalid releases');
    AppUpdate? newest;
    Object? lastFailure;
    var readManifest = false;
    for (final release in releases.take(15)) {
      if (release is! Map || release['draft'] == true) continue;
      final assets = release['assets'];
      if (assets is! List) continue;
      for (final asset in assets) {
        if (asset is! Map || asset['name'] != 'nimzo-update.json') continue;
        final manifestUrl = Uri.tryParse(
          asset['browser_download_url']?.toString() ?? '',
        );
        if (!_trusted(manifestUrl, 'nimzo-update.json')) continue;
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero)
          throw const FormatException('Update check timed out');
        dynamic manifest;
        try {
          manifest = jsonDecode(
            await _fetchJson(manifestUrl!)
                .timeout(remaining < _timeout ? remaining : _timeout),
          );
          if (manifest is! Map)
            throw const FormatException('Invalid update manifest');
          readManifest = true;
        } catch (error) {
          lastFailure = error;
          break;
        }
        final build = manifest['buildNumber'];
        final version = manifest['version'];
        final apk = Uri.tryParse(manifest['apkUrl']?.toString() ?? '');
        if (build is! int ||
            build <= current ||
            version is! String ||
            version.trim().isEmpty ||
            manifest['packageName'] != installed.packageName ||
            _normalize(manifest['signingCertificateSha256']) != signature ||
            !_digest.hasMatch(_normalize(manifest['apkSha256'])) ||
            !_trusted(apk, 'app-release.apk') ||
            apk!.pathSegments[4] != manifestUrl.pathSegments[4])
          continue;
        if (newest == null || build > newest.build)
          newest = AppUpdate(
            build,
            'NIMZO $version (build $build)',
            apk,
            apkSha256: _normalize(manifest['apkSha256']),
            packageName: installed.packageName,
            signingCertificateSha256: signature,
          );
        break;
      }
    }
    if (!readManifest && lastFailure != null) throw lastFailure;
    return newest;
  }

  static String _normalize(Object? value) =>
      value is String ? value.replaceAll(':', '').toLowerCase() : '';
  static bool _trusted(Uri? uri, String name) {
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment)
      return false;
    final parts = uri.pathSegments;
    return parts.length == 6 &&
        parts[0] == 'adi4ch-cmd' &&
        parts[1] == 'Nimzo' &&
        parts[2] == 'releases' &&
        parts[3] == 'download' &&
        parts[4].isNotEmpty &&
        parts[5] == name;
  }

  static Future<String> _readJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      // GitHub release assets redirect to its asset CDN. The public entry URL is
      // strictly repository scoped before reaching this transport.
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Nimzo-Android-Update-Checker',
      );
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != 200)
        throw HttpException('Update metadata HTTP ${response.statusCode}');
      return await (() async {
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 512 * 1024) {
            throw const FormatException('Update metadata too large');
          }
        }
        return utf8.decode(bytes);
      })().timeout(_timeout);
    } finally {
      client.close(force: true);
    }
  }
}

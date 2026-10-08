import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// GitHub testing releases only. Never downloads or installs APKs silently.
class NimzoAppUpdateService {
  static const _api =
      'https://api.github.com/repos/adi4ch-cmd/Nimzo/releases?per_page=15';

  static final _checker = NimzoUpdateChecker();
  static Future<AppUpdate?> check() => _checker.check();
  static final _prompter = NimzoUpdatePrompter(checkForUpdate: check);
  static Future<void> prompt(BuildContext context,
          {bool showUpToDate = false}) =>
      _prompter.prompt(context, showUpToDate: showUpToDate);
}

class NimzoUpdatePrompter {
  NimzoUpdatePrompter(
      {required this.checkForUpdate,
      bool Function()? isAndroid,
      Future<bool> Function(Uri)? openDownload})
      : isAndroid = isAndroid ?? (() => !kIsWeb && Platform.isAndroid),
        openDownload = openDownload ??
            ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));
  final Future<AppUpdate?> Function() checkForUpdate;
  final bool Function() isAndroid;
  final Future<bool> Function(Uri) openDownload;
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
                content: Text('No newer compatible testing update found.')),
          );
        }
        return;
      }
      if (!showUpToDate && !_promptedBuilds.add(update.build)) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('NIMZO update available'),
          content: Text(
              '${update.title}\n\nDownload the new APK? Android will ask you to confirm installation.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Later')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  final opened = await openDownload(update.url);
                  if (!opened && context.mounted)
                    _message(context,
                        'Could not open the APK download. Try again later.');
                } catch (_) {
                  if (context.mounted)
                    _message(context,
                        'Could not open the APK download. Try again later.');
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (showUpToDate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not check updates. Try again later.')),
        );
      }
    } finally {
      _promptInFlight = false;
    }
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
  const AppUpdate(this.build, this.title, this.url);
}

/// Reads only this project's release metadata. Android remains responsible for
/// installation and verifies the APK signature after the user downloads it.
class NimzoUpdateChecker {
  NimzoUpdateChecker({
    bool Function()? isAndroid,
    Future<PackageInfo> Function()? packageInfo,
    Future<String> Function(Uri)? fetchJson,
  })  : _isAndroid = isAndroid ?? (() => !kIsWeb && Platform.isAndroid),
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
        await _fetchJson(Uri.parse(NimzoAppUpdateService._api))
            .timeout(_timeout));
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
        final manifestUrl =
            Uri.tryParse(asset['browser_download_url']?.toString() ?? '');
        if (!_trusted(manifestUrl, 'nimzo-update.json')) continue;
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero)
          throw const FormatException('Update check timed out');
        dynamic manifest;
        try {
          manifest = jsonDecode(await _fetchJson(manifestUrl!)
              .timeout(remaining < _timeout ? remaining : _timeout));
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
            apk!.pathSegments[4] != manifestUrl.pathSegments[4]) continue;
        if (newest == null || build > newest.build)
          newest = AppUpdate(build, 'NIMZO $version (build $build)', apk);
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
        uri.hasFragment) return false;
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
      request.headers
          .set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers
          .set(HttpHeaders.userAgentHeader, 'Nimzo-Android-Update-Checker');
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
      })()
          .timeout(_timeout);
    } finally {
      client.close(force: true);
    }
  }
}

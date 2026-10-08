import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// GitHub testing releases only. Never downloads or installs APKs silently.
class NimzoAppUpdateService {
  static const _api = 'https://api.github.com/repos/adi4ch-cmd/Nimzo/releases?per_page=15';

  static Future<AppUpdate?> check() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final installed = await PackageInfo.fromPlatform();
    final current = int.tryParse(installed.buildNumber);
    if (current == null) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(Uri.parse(_api));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'Nimzo-Android-Update-Checker');
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final releases = jsonDecode(await utf8.decoder.bind(response).join());
      if (releases is! List) return null;
      AppUpdate? newest;
      for (final release in releases) {
        if (release is! Map || release['draft'] == true) continue;
        final body = release['body']?.toString() ?? '';
        final match = RegExp(r'NIMZO_BUILD_NUMBER=(\d+)').firstMatch(body);
        final build = int.tryParse(match?.group(1) ?? '');
        if (build == null || build <= current) continue;
        final assets = release['assets'];
        if (assets is! List) continue;
        for (final asset in assets) {
          if (asset is! Map || asset['name'] != 'app-release.apk') continue;
          final url = Uri.tryParse(asset['browser_download_url']?.toString() ?? '');
          if (url == null || url.scheme != 'https' || url.host != 'github.com') continue;
          if (newest == null || build > newest.build) {
            newest = AppUpdate(build, release['name']?.toString() ?? 'NIMZO update', url);
          }
        }
      }
      return newest;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> prompt(BuildContext context, {bool showUpToDate = false}) async {
    try {
      final update = await check();
      if (!context.mounted) return;
      if (update == null) {
        if (showUpToDate) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No newer compatible testing update found.')),
          );
        }
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('NIMZO update available'),
          content: Text('${update.title}\n\nDownload the new APK? Android will ask you to confirm installation.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Later')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await launchUrl(update.url, mode: LaunchMode.externalApplication);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (showUpToDate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not check updates. Try again later.')),
        );
      }
    }
  }
}

class AppUpdate {
  final int build;
  final String title;
  final Uri url;
  const AppUpdate(this.build, this.title, this.url);
}

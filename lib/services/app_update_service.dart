import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../l10n/app_localizations.dart';

/// Informácia o dostupnej novšej verzii z vzdialeného manifestu.
class AppUpdateInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;

  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
  });

  String get versionKey => '$version+$buildNumber';
}

/// Kontrola aktualizácie oproti JSON manifestu na URL (nie priamo z Gitu).
class AppUpdateService {
  AppUpdateService._();

  static const _prefsDismissedKey = 'app_update_dismissed_for_version';

  static bool _checkedThisSession = false;

  static Future<AppUpdateInfo?> fetchNewerIfAvailable() async {
    final url = AppConfig.appUpdateManifestUrl.trim();
    if (url.isEmpty) return null;

    final connectivity = await Connectivity().checkConnectivity();
    final online = connectivity.isNotEmpty &&
        connectivity.any(
          (r) => r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
        );
    if (!online) return null;

    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;
      final dynamic decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) return null;
      final map = decoded;
      final remoteVer = map['version'] as String?;
      final rawBuild = map['build_number'] ?? map['buildNumber'];
      final remoteBuild = int.tryParse('$rawBuild') ?? 0;
      final downloadUrl =
          map['download_url'] as String? ?? map['downloadUrl'] as String?;
      if (remoteVer == null || downloadUrl == null || downloadUrl.isEmpty) return null;

      final pkg = await PackageInfo.fromPlatform();
      final localVer = pkg.version;
      final localBuild = int.tryParse(pkg.buildNumber) ?? 0;

      if (!_isRemoteNewer(remoteVer, remoteBuild, localVer, localBuild)) return null;

      return AppUpdateInfo(
        version: remoteVer,
        buildNumber: remoteBuild,
        downloadUrl: downloadUrl,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isRemoteNewer(
    String remoteVer,
    int remoteBuild,
    String localVer,
    int localBuild,
  ) {
    try {
      final r = Version.parse(remoteVer);
      final l = Version.parse(localVer);
      if (r > l) return true;
      if (r < l) return false;
      return remoteBuild > localBuild;
    } catch (_) {
      return false;
    }
  }

  /// Zobrazí banner s aktualizáciou najviac raz za beh aplikácie; vyžaduje internet.
  static Future<void> maybeShowUpdateBanner(BuildContext context) async {
    if (_checkedThisSession) return;
    if (AppConfig.appUpdateManifestUrl.trim().isEmpty) {
      _checkedThisSession = true;
      return;
    }

    final info = await fetchNewerIfAvailable();
    _checkedThisSession = true;
    if (info == null || !context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    if (prefs.getString(_prefsDismissedKey) == info.versionKey) return;

    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    final pkg = await PackageInfo.fromPlatform();
    final currentLabel = '${pkg.version}+${pkg.buildNumber}';

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.system_update_alt_rounded),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.updateAvailableTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(l10n.updateAvailableBody(info.versionKey, currentLabel)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              await prefs.setString(_prefsDismissedKey, info.versionKey);
            },
            child: Text(l10n.updateLater),
          ),
          TextButton(
            onPressed: () async {
              final uri = Uri.tryParse(info.downloadUrl);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(l10n.updateDownload),
          ),
        ],
      ),
    );
  }
}

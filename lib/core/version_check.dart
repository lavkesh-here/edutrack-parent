import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';

/// Calls the backend once (after login) to see whether this parent/school
/// has an active force-update policy, and shows the appropriate prompt.
/// Never updates anything itself — the user always does the update via the
/// store listing; this only decides what to show and whether it can be
/// dismissed.
Future<void> checkForForcedUpdate(BuildContext context) async {
  try {
    final data = await ParentApiClient.checkVersionPolicy();
    final updateRequired = data['update_required'] as bool? ?? false;
    if (!updateRequired || !context.mounted) return;

    final force = data['force'] as bool? ?? false;
    final message = data['message'] as String?;
    await showDialog<void>(
      context: context,
      barrierDismissible: !force,
      builder: (ctx) => PopScope(
        canPop: !force,
        child: AlertDialog(
          title: Text(force ? 'Update Required' : 'Update Available'),
          content: Text(
            message?.isNotEmpty == true
                ? message!
                : 'A new version of the app is available. Please update to continue getting the latest fixes and features.',
          ),
          actions: [
            if (!force)
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
            FilledButton(
              onPressed: () async {
                await _openStoreListing();
                if (!force && ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  } catch (_) {
    // Never block app usage on this check failing — fail silent, try again
    // next login.
  }
}

Future<void> _openStoreListing() async {
  final info = await PackageInfo.fromPlatform();
  final uri = Platform.isIOS
      ? Uri.parse('https://apps.apple.com/search?term=${Uri.encodeComponent(info.appName)}')
      : Uri.parse('https://play.google.com/store/apps/details?id=${info.packageName}');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

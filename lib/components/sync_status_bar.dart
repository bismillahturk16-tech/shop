import 'package:flutter/material.dart';

import 'package:for_shop/services/auth_service.dart';
import 'package:for_shop/sync/sync_service.dart';

class SyncStatusBar extends StatelessWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cloudReady = AuthService.instance.isCloudReady;

    return ListenableBuilder(
      listenable: SyncService.instance,
      builder: (context, child) {
        final sync = SyncService.instance;

        // Nothing is confirmed by the phone alone: «همگام» appears only once
        // Firestore has answered, so a Wi-Fi with no internet behind it shows
        // as unverified instead of a healthy green.
        final color = !cloudReady
            ? const Color(0xFF667781)
            : sync.isSyncing
            ? const Color(0xFF513680)
            : !sync.isOnline
            ? Colors.orange.shade700
            : !sync.isCloudVerified
            ? Colors.orange.shade700
            : sync.pendingCount > 0
            ? Colors.amber.shade700
            : Colors.green.shade700;

        final icon = !cloudReady
            ? Icons.cloud_off_rounded
            : sync.isSyncing
            ? Icons.sync_rounded
            : !sync.isOnline
            ? Icons.wifi_off_rounded
            : !sync.isCloudVerified
            ? Icons.cloud_off_rounded
            : sync.pendingCount > 0
            ? Icons.cloud_upload_rounded
            : Icons.cloud_done_rounded;

        final account = AuthService.instance.account;

        final label = account == null
            ? 'بدون حساب — همگام‌سازی ابری غیرفعال'
            : !cloudReady
            ? 'حساب محلی روی این گوشی'
            : sync.lastError != null
            ? 'خطا در همگام‌سازی (${sync.lastError})'
            : sync.statusLabel;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              if (cloudReady)
                IconButton(
                  tooltip: 'همگام‌سازی الآن',
                  onPressed: sync.isSyncing ? null : sync.refresh,
                  icon: Icon(Icons.refresh_rounded, size: 20, color: color),
                ),
            ],
          ),
        );
      },
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

/// Jedna položka notifikácie (pre budúce rozšírenie môže byť model).
class NotificationItem {
  final String id;
  final String title;
  final String? body;
  final DateTime createdAt;
  final bool read;
  final IconData icon;
  final Color iconColor;
  /// Po kliku na položku (context = sheet). Ak null, len zatvorí sheet.
  final void Function(BuildContext context)? onTap;

  const NotificationItem({
    required this.id,
    required this.title,
    this.body,
    required this.createdAt,
    this.read = false,
    this.icon = Icons.notifications_outlined,
    this.iconColor = Colors.orange,
    this.onTap,
  });
}

/// Bottom sheet so zoznamom notifikácií. Po kliku na zvonček v app bare.
class NotificationsSheet extends StatelessWidget {
  final List<NotificationItem>? notifications;
  final VoidCallback? onClearAll;

  const NotificationsSheet({super.key, this.notifications, this.onClearAll});

  static List<NotificationItem> get defaultNotifications => [
    NotificationItem(
      id: '1',
      title: 'Nízky stav skladu',
      body: 'Niektoré položky majú nízke zásoby. Skontrolujte sklad.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      icon: Icons.inventory_2_outlined,
      iconColor: Colors.orange,
    ),
    NotificationItem(
      id: '2',
      title: 'Príjemka čaká na schválenie',
      body: 'Príjemka PR-2025-0003 bola vykázaná a čaká na schválenie.',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      icon: Icons.receipt_long_outlined,
      iconColor: Colors.teal,
    ),
    NotificationItem(
      id: '3',
      title: 'Nový používateľ prihlásený',
      body: 'Systém bol prístupný z nového zariadenia.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      read: true,
      icon: Icons.info_outline,
      iconColor: Colors.blue,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _buildGlassNotificationsModal(context);
  }

  Widget _buildGlassNotificationsModal(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final list = notifications ?? defaultNotifications;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 30),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: 500,
          ),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: -5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            l10n.notifications,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (list.isNotEmpty && onClearAll != null)
                            TextButton(
                              onPressed: () {
                                onClearAll?.call();
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withOpacity(0.8),
                              ),
                              child: const Text('Vymazať všetko'),
                            ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    // Content
                    Flexible(
                      child: list.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    size: 56,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Žiadne notifikácie',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: list.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Colors.white12,
                                height: 1,
                                indent: 72,
                              ),
                              itemBuilder: (context, index) {
                                final n = list[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: n.iconColor.withOpacity(
                                      0.2,
                                    ),
                                    child: Icon(
                                      n.icon,
                                      color: n.iconColor,
                                      size: 22,
                                    ),
                                  ),
                                  title: Text(
                                    n.title,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: n.read
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: n.body != null
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Text(
                                            n.body!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white.withOpacity(
                                                0.6,
                                              ),
                                            ),
                                          ),
                                        )
                                      : null,
                                  trailing: Text(
                                    _formatTime(n.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                  onTap: () {
                                    if (n.onTap != null) {
                                      n.onTap!(context);
                                    } else {
                                      Navigator.pop(context);
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return 'pred ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'pred ${diff.inHours} h';
    if (diff.inDays < 7) return 'pred ${diff.inDays} d';
    return '${d.day}.${d.month}.${d.year}';
  }
}

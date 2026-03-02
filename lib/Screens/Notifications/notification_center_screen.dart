import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_notification.dart';
import '../../services/Notifications/notification_service.dart';
import '../goods_receipt/goods_receipt_screen.dart';

/// Plnoobrazovkový stred notifikácií: zoznam, filtre, označiť všetky ako prečítané, tap → príjemka.
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final NotificationService _notificationService = NotificationService();
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _currentUsername;
  String _filter = 'all'; // all | unread | receipt | stock

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadNotifications();
    _notificationService.archiveOld();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _currentUsername = prefs.getString('current_user_username'));
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final unreadOnly = _filter == 'unread';
    final typeFilter = _filter == 'receipt' ? 'receipt' : (_filter == 'stock' ? 'stock' : null);
    final list = await _notificationService.getNotifications(
      username: _currentUsername,
      unreadOnly: unreadOnly,
      typeFilter: typeFilter,
      limit: 200,
    );
    if (mounted) setState(() {
      _notifications = list;
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    await _notificationService.markAllRead(_currentUsername);
    await _loadNotifications();
  }

  void _onTapNotification(AppNotification n) {
    if (n.id != null) _notificationService.markRead(n.id!);
    if (n.receiptId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const GoodsReceiptScreen(),
        ),
      );
    } else {
      setState(() => _loading = true);
      _loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111114),
      appBar: AppBar(
        backgroundColor: const Color(0xFF212124),
        title: const Text(
          'Notifikácie',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_notifications.any((n) => !n.read))
            TextButton(
              onPressed: _loading ? null : _markAllRead,
              child: const Text('Označiť všetky ako prečítané', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadNotifications,
              color: const Color(0xFFFFC107),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFC107)))
                  : _notifications.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final n = _notifications[index];
                            return _NotificationTile(
                              notification: n,
                              onTap: () => _onTapNotification(n),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _FilterChip(
            label: 'Všetky',
            selected: _filter == 'all',
            onTap: () => setState(() { _filter = 'all'; _loadNotifications(); }),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Neprečítané',
            selected: _filter == 'unread',
            onTap: () => setState(() { _filter = 'unread'; _loadNotifications(); }),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Príjemky',
            selected: _filter == 'receipt',
            onTap: () => setState(() { _filter = 'receipt'; _loadNotifications(); }),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Zásoby',
            selected: _filter == 'stock',
            onTap: () => setState(() { _filter = 'stock'; _loadNotifications(); }),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'Žiadne notifikácie',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFFFC107).withOpacity(0.3),
      checkmarkColor: const Color(0xFFFFC107),
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final iconData = _iconForType(n.type);
    final iconColor = _colorForType(n.type);
    return Material(
      color: n.read ? const Color(0xFF1A1A1A) : const Color(0xFF252528),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(iconData, color: iconColor, size: 22),
        ),
        title: Text(
          n.title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: n.read ? FontWeight.normal : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: n.body.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  n.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              )
            : null,
        trailing: Text(
          _formatTime(n.createdAt),
          style: const TextStyle(fontSize: 11, color: Colors.white38),
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'RECEIPT_SUBMITTED':
      case 'RECEIPT_PENDING_LONG':
        return Icons.receipt_long_outlined;
      case 'RECEIPT_APPROVED':
        return Icons.check_circle_outline;
      case 'RECEIPT_REJECTED':
        return Icons.cancel_outlined;
      case 'RECEIPT_RECALLED':
      case 'RECEIPT_REVERSED':
        return Icons.undo_outlined;
      case 'STOCK_LOW':
        return Icons.inventory_2_outlined;
      case 'PRICE_CHANGE':
        return Icons.trending_up;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'RECEIPT_APPROVED':
        return Colors.green;
      case 'RECEIPT_REJECTED':
        return Colors.red;
      case 'STOCK_LOW':
        return Colors.orange;
      case 'PRICE_CHANGE':
        return Colors.amber;
      default:
        return Colors.teal;
    }
  }

  String _formatTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return 'pred ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'pred ${diff.inHours} h';
    if (diff.inDays < 7) return 'pred ${diff.inDays} d';
    return '${d.day}.${d.month}.${d.year}';
  }
}

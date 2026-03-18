import 'package:flutter/material.dart';
import '../../services/sync/sync_manager.dart';

/// Malý indikátor stavu sync – pridaj ho do AppBar alebo Drawer.
class SyncStatusBadge extends StatelessWidget {
  final SyncStatus status;
  const SyncStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Tooltip(
        message: _tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _color.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 14, color: _color),
              const SizedBox(width: 4),
              Text(
                _label,
                style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _color {
    switch (status) {
      case SyncStatus.idle:
        return Colors.green.shade600;
      case SyncStatus.syncing:
        return Colors.blue.shade600;
      case SyncStatus.pending:
        return Colors.orange.shade600;
      case SyncStatus.conflict:
        return Colors.red.shade600;
      case SyncStatus.error:
        return Colors.red.shade400;
    }
  }

  IconData get _icon {
    switch (status) {
      case SyncStatus.idle:
        return Icons.cloud_done_outlined;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.pending:
        return Icons.upload_outlined;
      case SyncStatus.conflict:
        return Icons.warning_amber_rounded;
      case SyncStatus.error:
        return Icons.cloud_off_outlined;
    }
  }

  String get _label {
    switch (status) {
      case SyncStatus.idle:
        return 'Synced';
      case SyncStatus.syncing:
        return 'Sync...';
      case SyncStatus.pending:
        return 'Čakajúce';
      case SyncStatus.conflict:
        return 'Konflikt';
      case SyncStatus.error:
        return 'Chyba sync';
    }
  }

  String get _tooltip {
    switch (status) {
      case SyncStatus.idle:
        return 'Všetky zmeny sú synchronizované';
      case SyncStatus.syncing:
        return 'Prebieha synchronizácia...';
      case SyncStatus.pending:
        return 'Čakajúce zmeny – budú odoslané po pripojení';
      case SyncStatus.conflict:
        return 'Existujú konflikty vyžadujúce riešenie';
      case SyncStatus.error:
        return 'Posledná synchronizácia zlyhala';
    }
  }
}


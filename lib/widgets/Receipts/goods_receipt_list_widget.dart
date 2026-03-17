import 'package:flutter/material.dart';
import '../../models/receipt.dart';
import '../../models/warehouse.dart';

/// Widget zobrazujúci zoznam príjemok alebo prázdny stav.
class GoodsReceiptList extends StatelessWidget {
  final List<InboundReceipt> receipts;
  final List<Warehouse> warehouses;
  final Map<String, String> movementTypeNames;
  final VoidCallback onAddTap;
  final void Function(InboundReceipt receipt)? onApprove;
  final void Function(InboundReceipt receipt)? onEdit;
  final void Function(InboundReceipt receipt)? onPrintPdf;
  final void Function(InboundReceipt receipt)? onSubmit;
  final void Function(InboundReceipt receipt)? onRecall;
  final void Function(InboundReceipt receipt)? onReject;
  final void Function(InboundReceipt receipt)? onReverse;
  final String? currentUserUsername;
  final String? currentUserRole;

  const GoodsReceiptList({
    super.key,
    required this.receipts,
    this.warehouses = const [],
    this.movementTypeNames = const {},
    required this.onAddTap,
    this.onApprove,
    this.onEdit,
    this.onPrintPdf,
    this.onSubmit,
    this.onRecall,
    this.onReject,
    this.onReverse,
    this.currentUserUsername,
    this.currentUserRole,
  });

  @override
  Widget build(BuildContext context) {
    if (receipts.isEmpty) {
      return _GoodsReceiptEmptyState(onAddTap: onAddTap);
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: receipts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => GoodsReceiptCard(
                receipt: receipts[index],
                warehouses: warehouses,
                movementTypeNames: movementTypeNames,
                onApprove: onApprove,
                onEdit: onEdit,
                onPrintPdf: onPrintPdf,
                onSubmit: onSubmit,
                onRecall: onRecall,
                onReject: onReject,
                onReverse: onReverse,
                currentUserUsername: currentUserUsername,
                currentUserRole: currentUserRole,
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

/// Prázdny stav – žiadne príjemky.
class _GoodsReceiptEmptyState extends StatelessWidget {
  final VoidCallback onAddTap;

  const _GoodsReceiptEmptyState({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 20, 32, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(Icons.inbox_rounded, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Zatiaľ nemáte žiadne príjemky',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Kliknite na tlačidlo nižšie a vytvorte prvý príjem tovaru.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add),
              label: const Text('Nový príjem'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Premium karta jednej príjemky.
class GoodsReceiptCard extends StatelessWidget {
  final InboundReceipt receipt;
  final List<Warehouse> warehouses;
  final Map<String, String> movementTypeNames;
  final void Function(InboundReceipt receipt)? onApprove;
  final void Function(InboundReceipt receipt)? onEdit;
  final void Function(InboundReceipt receipt)? onPrintPdf;
  final void Function(InboundReceipt receipt)? onSubmit;
  final void Function(InboundReceipt receipt)? onRecall;
  final void Function(InboundReceipt receipt)? onReject;
  final void Function(InboundReceipt receipt)? onReverse;
  final String? currentUserUsername;
  final String? currentUserRole;

  const GoodsReceiptCard({
    super.key,
    required this.receipt,
    this.warehouses = const [],
    this.movementTypeNames = const {},
    this.onApprove,
    this.onEdit,
    this.onPrintPdf,
    this.onSubmit,
    this.onRecall,
    this.onReject,
    this.onReverse,
    this.currentUserUsername,
    this.currentUserRole,
  });

  // --- helpers ---

  Color get _accentColor {
    if (receipt.isApproved) return const Color(0xFF10B981);
    if (receipt.isPendingApproval) return const Color(0xFFF59E0B);
    if (receipt.isRejected) return const Color(0xFFEF4444);
    if (receipt.isReversed) return const Color(0xFF9CA3AF);
    if (receipt.isDraft) return const Color(0xFF6366F1);
    return const Color(0xFF3B82F6);
  }

  Color get _statusColor {
    if (receipt.isApproved) return const Color(0xFF10B981);
    if (receipt.isPendingApproval) return const Color(0xFFF59E0B);
    if (receipt.isRejected) return const Color(0xFFEF4444);
    if (receipt.isReversed) return const Color(0xFF9CA3AF);
    if (receipt.isDraft) return const Color(0xFF6366F1);
    return const Color(0xFF3B82F6);
  }

  String get _statusLabel {
    if (receipt.isDraft) return 'Rozpracovaný';
    if (receipt.isPendingApproval) return 'Čaká na schválenie';
    if (receipt.isRejected) return 'Zamietnutá';
    if (receipt.isReversed) return 'Stornovaná';
    if (receipt.isApproved) return 'Schválená';
    return 'Vykázaná';
  }

  IconData get _statusIcon {
    if (receipt.isApproved) return Icons.check_circle_rounded;
    if (receipt.isPendingApproval) return Icons.hourglass_top_rounded;
    if (receipt.isRejected) return Icons.cancel_rounded;
    if (receipt.isReversed) return Icons.replay_rounded;
    if (receipt.isDraft) return Icons.edit_rounded;
    return Icons.receipt_long_rounded;
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  // --- build ---

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(receipt.createdAt);
    final isVykazana = receipt.isEditable;
    final warehouseName = _resolveWarehouse();
    final movTypeName = movementTypeNames[receipt.movementTypeCode] ?? receipt.movementTypeCode;
    final hasActions = (isVykazana && (onApprove != null || onEdit != null)) ||
        onPrintPdf != null ||
        onSubmit != null ||
        onRecall != null ||
        onReject != null ||
        onReverse != null;
    final hasExtra = receipt.vatAppliesToAll ||
        (receipt.deliveryNoteNumber?.isNotEmpty == true) ||
        (receipt.poNumber?.isNotEmpty == true) ||
        receipt.isSettled;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.10), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(
                width: 4,
                color: _accentColor,
              ),

              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row: icon + number + status badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.south_west_rounded,
                              color: _accentColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  receipt.receiptNumber,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: -0.2,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_outlined,
                                        size: 11, color: Colors.grey[500]),
                                    const SizedBox(width: 3),
                                    Text(
                                      dateStr,
                                      style: TextStyle(
                                          color: Colors.grey[500], fontSize: 11),
                                    ),
                                    if (movTypeName.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 3,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[400],
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        movTypeName,
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status badge top-right
                          _StatusBadge(
                            label: _statusLabel,
                            color: _statusColor,
                            icon: _statusIcon,
                          ),
                        ],
                      ),

                      // Supplier / warehouse row
                      if ((receipt.supplierName?.isNotEmpty == true) || warehouseName != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (receipt.supplierName?.isNotEmpty == true) ...[
                              Icon(Icons.business_outlined,
                                  size: 12, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  receipt.supplierName!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF374151),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (warehouseName != null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.warehouse_outlined,
                                  size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 3),
                              Text(
                                warehouseName,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[500]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ],

                      // Invoice / delivery note
                      if ((receipt.invoiceNumber?.isNotEmpty == true) ||
                          (receipt.deliveryNoteNumber?.isNotEmpty == true) ||
                          (receipt.poNumber?.isNotEmpty == true)) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 10,
                          children: [
                            if (receipt.invoiceNumber?.isNotEmpty == true)
                              _MetaLabel(
                                  icon: Icons.receipt_outlined,
                                  text: receipt.invoiceNumber!),
                            if (receipt.deliveryNoteNumber?.isNotEmpty == true)
                              _MetaLabel(
                                  icon: Icons.local_shipping_outlined,
                                  text: receipt.deliveryNoteNumber!),
                            if (receipt.poNumber?.isNotEmpty == true)
                              _MetaLabel(
                                  icon: Icons.assignment_outlined,
                                  text: receipt.poNumber!),
                          ],
                        ),
                      ],

                      // Chips row
                      if (hasExtra || receipt.pricesIncludeVat != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            _buildChip(
                              receipt.pricesIncludeVat ? 'S DPH' : 'Bez DPH',
                              receipt.pricesIncludeVat
                                  ? const Color(0xFF10B981)
                                  : Colors.orange,
                            ),
                            if (receipt.vatAppliesToAll && receipt.vatRate != null)
                              _buildChip(
                                  'DPH ${receipt.vatRate}% pre všetky',
                                  Colors.indigo),
                            if (movementTypeNames.isNotEmpty &&
                                receipt.movementTypeCode.isNotEmpty)
                              _buildChip(
                                movementTypeNames[receipt.movementTypeCode] ??
                                    receipt.movementTypeCode,
                                Colors.purple,
                              ),
                            if (receipt.isSettled)
                              _buildChip('Vysporiadané', Colors.brown),
                          ],
                        ),
                      ],

                      // Action buttons
                      if (hasActions) ...[
                        const SizedBox(height: 10),
                        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (onPrintPdf != null)
                                _ActionButton(
                                  icon: Icons.picture_as_pdf_outlined,
                                  label: 'Tlačiť PDF',
                                  color: Colors.grey[700]!,
                                  onTap: () => onPrintPdf!(receipt),
                                ),
                              if (isVykazana && onEdit != null) ...[
                                if (onPrintPdf != null) const SizedBox(width: 6),
                                _ActionButton(
                                  icon: Icons.edit_outlined,
                                  label: receipt.isRejected
                                      ? 'Upraviť a znovu odoslať'
                                      : 'Upraviť',
                                  color: const Color(0xFF6366F1),
                                  onTap: () => onEdit!(receipt),
                                ),
                              ],
                              if (receipt.isPendingApproval &&
                                  (currentUserRole == null ||
                                      currentUserRole == 'manager' ||
                                      currentUserRole == 'admin') &&
                                  onApprove != null) ...[
                                const SizedBox(width: 6),
                                _ActionButton(
                                  icon: Icons.check_circle_outline,
                                  label: 'Schváliť',
                                  color: const Color(0xFF10B981),
                                  filled: true,
                                  onTap: () => onApprove!(receipt),
                                ),
                              ],
                              if (receipt.isPendingApproval &&
                                  (currentUserRole == null ||
                                      currentUserRole == 'manager' ||
                                      currentUserRole == 'admin') &&
                                  onReject != null) ...[
                                const SizedBox(width: 6),
                                _ActionButton(
                                  icon: Icons.cancel_outlined,
                                  label: 'Zamietnuť',
                                  color: const Color(0xFFEF4444),
                                  onTap: () => onReject!(receipt),
                                ),
                              ],
                              if ((receipt.isDraft ||
                                      receipt.status ==
                                          InboundReceiptStatus.vykazana) &&
                                  (receipt.username == null ||
                                      receipt.username ==
                                          currentUserUsername) &&
                                  onSubmit != null) ...[
                                const SizedBox(width: 6),
                                _ActionButton(
                                  icon: Icons.send_outlined,
                                  label: 'Odoslať na schválenie',
                                  color: const Color(0xFF3B82F6),
                                  filled: true,
                                  onTap: () => onSubmit!(receipt),
                                ),
                              ],
                              if (receipt.isDraft && onApprove != null) ...[
                                const SizedBox(width: 6),
                                _ActionButton(
                                  icon: Icons.check_circle_outline,
                                  label: 'Vykázať príjem',
                                  color: const Color(0xFF10B981),
                                  filled: true,
                                  onTap: () => onApprove!(receipt),
                                ),
                              ],
                              if (receipt.isPendingApproval &&
                                  (receipt.username == null ||
                                      receipt.username ==
                                          currentUserUsername) &&
                                  onRecall != null) ...[
                                const SizedBox(width: 6),
                                _ActionButton(
                                  icon: Icons.undo_outlined,
                                  label: 'Stiahnuť',
                                  color: Colors.grey[600]!,
                                  onTap: () => onRecall!(receipt),
                                ),
                              ],
                              if (receipt.status !=
                                      InboundReceiptStatus.reversed &&
                                  receipt.status !=
                                      InboundReceiptStatus.cancelled &&
                                  onReverse != null) ...[
                                const SizedBox(width: 6),
                                _ActionButton(
                                  icon: Icons.replay_outlined,
                                  label: receipt.stockApplied ||
                                          receipt.isApproved ||
                                          receipt.status ==
                                              InboundReceiptStatus.vykazana
                                      ? 'Stornovať'
                                      : 'Zrušiť',
                                  color: const Color(0xFFF97316),
                                  onTap: () => onReverse!(receipt),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _resolveWarehouse() {
    if (receipt.warehouseId == null) return null;
    for (final w in warehouses) {
      if (w.id == receipt.warehouseId) return w.name;
    }
    return 'Sklad #${receipt.warehouseId}';
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// --- Sub-widgets ---

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.30), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.grey[400]),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

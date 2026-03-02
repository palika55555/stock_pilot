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
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: receipts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Karta jednej príjemky v zozname. Stav vykázaná = editovateľná, schválená = uzamknutá.
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

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(receipt.createdAt);
    final isVykazana = receipt.isEditable;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.south_west_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      receipt.receiptNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      dateStr,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                    if (receipt.invoiceNumber != null &&
                        receipt.invoiceNumber!.isNotEmpty)
                      Text(
                        'Faktúra: ${receipt.invoiceNumber}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                      ),
                    if (receipt.supplierName != null &&
                        receipt.supplierName!.isNotEmpty)
                      Text(
                        receipt.supplierName!,
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (receipt.warehouseId != null) ...[
                      Builder(
                        builder: (context) {
                          String name = 'Sklad #${receipt.warehouseId}';
                          for (final w in warehouses) {
                            if (w.id == receipt.warehouseId) {
                              name = w.name;
                              break;
                            }
                          }
                          return Text(
                            name,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFE0E0E0),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: [
              _buildChip(
                receipt.pricesIncludeVat ? 'S DPH' : 'Bez DPH',
                receipt.pricesIncludeVat
                    ? const Color(0xFF10B981)
                    : Colors.orange,
              ),
              if (receipt.vatAppliesToAll && receipt.vatRate != null)
                _buildChip('DPH ${receipt.vatRate}% pre všetky', Colors.indigo),
              _buildChip(
                receipt.isDraft
                    ? 'Rozpracovaný'
                    : receipt.isPendingApproval
                        ? 'Čaká na schválenie'
                        : receipt.isRejected
                            ? 'Zamietnutá'
                            : receipt.isReversed
                                ? 'Stornovaná'
                                : (receipt.isApproved ? 'Schválená' : 'Vykázaná'),
                receipt.isDraft
                    ? Colors.orange
                    : receipt.isPendingApproval
                        ? Colors.amber
                        : receipt.isRejected
                            ? Colors.red
                            : receipt.isReversed
                                ? Colors.grey
                                : (receipt.isApproved ? Colors.teal : Colors.blue),
              ),
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
          if ((isVykazana && (onApprove != null || onEdit != null)) ||
              onPrintPdf != null ||
              onSubmit != null ||
              onRecall != null ||
              onReject != null ||
              onReverse != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                if (onPrintPdf != null)
                  TextButton.icon(
                    onPressed: () => onPrintPdf!(receipt),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: const Text('Tlačiť PDF', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (isVykazana && onEdit != null)
                  TextButton.icon(
                    onPressed: () => onEdit!(receipt),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(
                      receipt.isRejected ? 'Upraviť a znovu odoslať' : 'Upraviť',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (receipt.isPendingApproval &&
                    (currentUserRole == null || currentUserRole == 'manager' || currentUserRole == 'admin') &&
                    onApprove != null)
                  FilledButton.icon(
                    onPressed: () => onApprove!(receipt),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Schváliť', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (receipt.isPendingApproval &&
                    (currentUserRole == null || currentUserRole == 'manager' || currentUserRole == 'admin') &&
                    onReject != null)
                  TextButton.icon(
                    onPressed: () => onReject!(receipt),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Zamietnuť', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if ((receipt.isDraft || receipt.status == InboundReceiptStatus.vykazana) &&
                    (receipt.username == null || receipt.username == currentUserUsername) &&
                    onSubmit != null)
                  FilledButton.icon(
                    onPressed: () => onSubmit!(receipt),
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text('Odoslať na schválenie', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (receipt.isDraft && onApprove != null)
                  FilledButton.icon(
                    onPressed: () => onApprove!(receipt),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Vykázať príjem', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (receipt.isPendingApproval &&
                    (receipt.username == null || receipt.username == currentUserUsername) &&
                    onRecall != null)
                  TextButton.icon(
                    onPressed: () => onRecall!(receipt),
                    icon: const Icon(Icons.undo_outlined, size: 16),
                    label: const Text('Stiahnuť', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (receipt.status != InboundReceiptStatus.reversed &&
                    receipt.status != InboundReceiptStatus.cancelled &&
                    onReverse != null)
                  TextButton.icon(
                    onPressed: () => onReverse!(receipt),
                    icon: const Icon(Icons.replay_outlined, size: 16),
                    label: Text(
                      receipt.stockApplied || receipt.isApproved || receipt.status == InboundReceiptStatus.vykazana
                          ? 'Stornovať'
                          : 'Zrušiť',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
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

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
}

import 'package:flutter/material.dart';
import '../../models/stock_out.dart';
import '../../theme/app_theme.dart';

class StockOutList extends StatelessWidget {
  final List<StockOut> stockOuts;
  final bool canEditApproved;
  final VoidCallback onAddTap;
  final void Function(StockOut stockOut)? onApprove;
  final void Function(StockOut stockOut)? onEdit;
  final void Function(StockOut stockOut)? onStorno;
  final void Function(StockOut stockOut)? onExportPdf;

  const StockOutList({
    super.key,
    required this.stockOuts,
    this.canEditApproved = false,
    required this.onAddTap,
    this.onApprove,
    this.onEdit,
    this.onStorno,
    this.onExportPdf,
  });

  static List<StockOut> _byDraft(List<StockOut> list) =>
      list.where((s) => s.isDraft).toList();
  static List<StockOut> _byPendingApproval(List<StockOut> list) =>
      list.where((s) => !s.isDraft && !s.isApproved && !s.isStorned).toList();
  static List<StockOut> _byApproved(List<StockOut> list) =>
      list.where((s) => s.isApproved).toList();
  static List<StockOut> _byStorned(List<StockOut> list) =>
      list.where((s) => s.isStorned).toList();

  @override
  Widget build(BuildContext context) {
    if (stockOuts.isEmpty) {
      return _StockOutEmptyState(onAddTap: onAddTap);
    }
    final draft = _byDraft(stockOuts);
    final pending = _byPendingApproval(stockOuts);
    final approved = _byApproved(stockOuts);
    final storned = _byStorned(stockOuts);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: kToolbarHeight + 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (draft.isNotEmpty) ...[
                  _SectionHeader(title: 'Rozpracované', count: draft.length, color: Colors.orange),
                  const SizedBox(height: 6),
                  ...draft.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: StockOutCard(
                      stockOut: s,
                      canEditApproved: canEditApproved,
                      onApprove: onApprove,
                      onEdit: onEdit,
                      onStorno: onStorno,
                      onExportPdf: onExportPdf,
                    ),
                  )),
                  const SizedBox(height: 16),
                ],
                if (pending.isNotEmpty) ...[
                  _SectionHeader(title: 'Na schválenie', count: pending.length, color: Colors.blue),
                  const SizedBox(height: 6),
                  ...pending.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: StockOutCard(
                      stockOut: s,
                      canEditApproved: canEditApproved,
                      onApprove: onApprove,
                      onEdit: onEdit,
                      onStorno: onStorno,
                      onExportPdf: onExportPdf,
                    ),
                  )),
                  const SizedBox(height: 16),
                ],
                if (approved.isNotEmpty) ...[
                  _SectionHeader(title: 'Schválené', count: approved.length, color: Colors.teal),
                  const SizedBox(height: 6),
                  ...approved.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: StockOutCard(
                      stockOut: s,
                      canEditApproved: canEditApproved,
                      onApprove: onApprove,
                      onEdit: onEdit,
                      onStorno: onStorno,
                      onExportPdf: onExportPdf,
                    ),
                  )),
                  const SizedBox(height: 16),
                ],
                if (storned.isNotEmpty) ...[
                  _SectionHeader(title: 'Stornované', count: storned.length, color: Colors.grey),
                  const SizedBox(height: 6),
                  ...storned.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: StockOutCard(
                      stockOut: s,
                      canEditApproved: canEditApproved,
                      onApprove: onApprove,
                      onEdit: onEdit,
                      onStorno: onStorno,
                      onExportPdf: onExportPdf,
                    ),
                  )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockOutEmptyState extends StatelessWidget {
  final VoidCallback onAddTap;

  const _StockOutEmptyState({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Zatiaľ nemáte žiadne výdajky',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Kliknite na tlačidlo nižšie a vytvorte prvú výdajku tovaru.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddTap,
              icon: const Icon(Icons.add),
              label: const Text('Nová výdajka'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
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

class StockOutCard extends StatelessWidget {
  final StockOut stockOut;
  final bool canEditApproved;
  final void Function(StockOut stockOut)? onApprove;
  final void Function(StockOut stockOut)? onEdit;
  final void Function(StockOut stockOut)? onStorno;
  final void Function(StockOut stockOut)? onExportPdf;

  const StockOutCard({
    super.key,
    required this.stockOut,
    this.canEditApproved = false,
    this.onApprove,
    this.onEdit,
    this.onStorno,
    this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(stockOut.createdAt);
    final isEditable = stockOut.isEditable;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppColors.cardDecorationSmall(12),
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
                  color: AppColors.dangerSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.north_east_rounded,
                  color: AppColors.danger,
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
                      stockOut.documentNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      dateStr,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    if (stockOut.recipientName != null &&
                        stockOut.recipientName!.isNotEmpty)
                      Text(
                        stockOut.recipientName!,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
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
                stockOut.issueType.label,
                _colorForIssueType(stockOut.issueType),
              ),
              _buildChip(
                stockOut.isDraft
                    ? 'Rozpracovaný'
                    : (stockOut.isStorned
                        ? 'Stornovaná'
                        : (stockOut.isApproved ? 'Schválená' : 'Vykázaná')),
                stockOut.isDraft
                    ? AppColors.warning
                    : (stockOut.isStorned
                        ? AppColors.textMuted
                        : (stockOut.isApproved ? AppColors.success : AppColors.info)),
              ),
              if (stockOut.isZeroVat)
                _buildChip('0 % DPH', Colors.deepPurple),
            ],
          ),
          if ((isEditable && (onApprove != null || onEdit != null || onStorno != null)) ||
              (stockOut.isApproved && ((onEdit != null && canEditApproved) || onStorno != null)) ||
              onExportPdf != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onEdit != null && (isEditable || (stockOut.isApproved && canEditApproved)))
                  TextButton.icon(
                    onPressed: () => onEdit!(stockOut),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text(
                      'Upraviť',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (onApprove != null && !stockOut.isDraft && !stockOut.isApproved && !stockOut.isStorned) ...[
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: () => onApprove!(stockOut),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text(
                      'Schváliť',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentGold,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
                if (onStorno != null && !stockOut.isStorned) ...[
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () => onStorno!(stockOut),
                    icon: Icon(
                      stockOut.isApproved ? Icons.block : Icons.cancel_outlined,
                      size: 16,
                      color: AppColors.danger,
                    ),
                    label: Text(
                      stockOut.isApproved ? 'Stornovať' : 'Zrušiť',
                      style: TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
                if (onExportPdf != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => onExportPdf!(stockOut),
                    icon: Icon(Icons.picture_as_pdf, size: 20, color: AppColors.danger),
                    tooltip: 'Export do PDF',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
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

  Color _colorForIssueType(StockOutIssueType t) {
    switch (t) {
      case StockOutIssueType.sale:
        return const Color(0xFFDC2626);
      case StockOutIssueType.consumption:
        return Colors.brown;
      case StockOutIssueType.production:
        return Colors.indigo;
      case StockOutIssueType.writeOff:
        return Colors.deepOrange;
      case StockOutIssueType.returnToSupplier:
        return Colors.amber;
      case StockOutIssueType.transfer:
        return const Color(0xFF0D9488);
    }
  }
}

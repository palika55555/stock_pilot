import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'warehouse_supplies_constants.dart';

const _sectionPredaj = [
  'predaj_bez_dph',
  'predaj_s_dph',
  'marza',
  'dph',
  'dph_eur',
  'zlava',
];

const _sectionNakup = [
  'nakup_bez_dph',
  'nakup_s_dph',
  'nakup_dph',
  'recykl',
  'posl_datum',
  'posl_nakup_bez_dph',
];

/// Dialóg výberu viditeľných stĺpcov tabuľky skladových zásob.
Future<void> showWarehouseSuppliesColumnSelector(
  BuildContext context, {
  required Map<String, bool> initialVisibility,
  required void Function(Map<String, bool> visibility) onApply,
  required Future<void> Function() onSave,
}) {
  final localVisibility = Map<String, bool>.from(initialVisibility);
  final sectionOstatne = warehouseSupplyTableColumns
      .map((c) => c.id)
      .where(
        (id) => !_sectionPredaj.contains(id) && !_sectionNakup.contains(id),
      )
      .toList();

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  decoration: BoxDecoration(
                    color: AppColors.accentGoldSubtle,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.view_column_rounded,
                        size: 28,
                        color: AppColors.accentGold,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Zobrazenie stĺpcov',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _WarehouseColumnSection(
                          title: 'Predaj',
                          columnIds: _sectionPredaj,
                          localVisibility: localVisibility,
                          setModalState: setModalState,
                        ),
                        const SizedBox(height: 16),
                        _WarehouseColumnSection(
                          title: 'Nákup',
                          columnIds: _sectionNakup,
                          localVisibility: localVisibility,
                          setModalState: setModalState,
                        ),
                        const SizedBox(height: 16),
                        _WarehouseColumnSection(
                          title: 'Sklad a ostatné',
                          columnIds: sectionOstatne,
                          localVisibility: localVisibility,
                          setModalState: setModalState,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          for (final c in warehouseSupplyTableColumns) {
                            localVisibility[c.id] = true;
                          }
                          setModalState(() {});
                        },
                        icon: Icon(
                          Icons.restore_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        label: Text(
                          'Obnoviť predvolené',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          onApply(Map<String, bool>.from(localVisibility));
                          await onSave();
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentGold,
                          foregroundColor: AppColors.bgPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Hotovo'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _WarehouseColumnSection extends StatelessWidget {
  final String title;
  final List<String> columnIds;
  final Map<String, bool> localVisibility;
  final void Function(void Function()) setModalState;

  const _WarehouseColumnSection({
    required this.title,
    required this.columnIds,
    required this.localVisibility,
    required this.setModalState,
  });

  @override
  Widget build(BuildContext context) {
    final columns = columnIds
        .map(
          (id) => warehouseSupplyTableColumns.firstWhere((c) => c.id == id),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: columns.map((col) {
            final isChecked = localVisibility[col.id] ?? true;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setModalState(() => localVisibility[col.id] = !isChecked);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isChecked
                        ? AppColors.accentGoldSubtle
                        : AppColors.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isChecked
                          ? AppColors.accentGold.withValues(alpha: 0.5)
                          : AppColors.borderDefault,
                      width: isChecked ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isChecked
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 22,
                        color: isChecked
                            ? AppColors.accentGold
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        col.id == 'marza'
                            ? AppLocalizations.of(context)!.margin
                            : col.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isChecked
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isChecked
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

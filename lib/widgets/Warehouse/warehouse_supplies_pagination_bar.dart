import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Panel stránkovania pod tabuľkou / kartami skladových zásob.
class WarehouseSuppliesPaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalFilteredCount;
  final int pageSize;
  final int loadedOnPageCount;
  final bool isLoading;
  final bool countAndStatsPending;
  final void Function(int page) onGoToPage;

  const WarehouseSuppliesPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalFilteredCount,
    required this.pageSize,
    required this.loadedOnPageCount,
    required this.isLoading,
    required this.countAndStatsPending,
    required this.onGoToPage,
  });

  @override
  Widget build(BuildContext context) {
    final start = totalFilteredCount == 0
        ? 0
        : (currentPage - 1) * pageSize + 1;
    final end = totalFilteredCount == 0
        ? 0
        : (currentPage - 1) * pageSize + loadedOnPageCount;

    String paginationText;
    if (countAndStatsPending) {
      paginationText = loadedOnPageCount > 0
          ? 'Zobrazených $loadedOnPageCount na stránke · načítavam celkový počet…'
          : 'Kontrolujem počet záznamov…';
    } else if (totalFilteredCount == 0) {
      paginationText = 'Žiadne záznamy';
    } else {
      paginationText =
          'Záznamy $start–$end z $totalFilteredCount · stránka $currentPage / $totalPages';
    }

    return Material(
      color: AppColors.bgElevated,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              paginationText,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Predchádzajúca stránka',
                    onPressed: currentPage <= 1 ||
                            isLoading ||
                            countAndStatsPending
                        ? null
                        : () => onGoToPage(currentPage - 1),
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      color: currentPage <= 1
                          ? AppColors.textMuted
                          : AppColors.accentGold,
                    ),
                  ),
                  for (int p = 1; p <= totalPages; p++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: p == currentPage
                          ? FilledButton.tonal(
                              onPressed: null,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(40, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                backgroundColor: AppColors.accentGoldSubtle,
                              ),
                              child: Text(
                                '$p',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : TextButton(
                              onPressed: isLoading || countAndStatsPending
                                  ? null
                                  : () => onGoToPage(p),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(40, 36),
                              ),
                              child: Text(
                                '$p',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                    ),
                  IconButton(
                    tooltip: 'Ďalšia stránka',
                    onPressed: currentPage >= totalPages ||
                            isLoading ||
                            countAndStatsPending ||
                            totalFilteredCount == 0
                        ? null
                        : () => onGoToPage(currentPage + 1),
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: currentPage >= totalPages ||
                              totalFilteredCount == 0
                          ? AppColors.textMuted
                          : AppColors.accentGold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

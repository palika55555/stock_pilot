import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/company.dart';
import '../../models/customer.dart';
import '../../models/quote.dart';
import '../../theme/app_theme.dart';

/// Karta s hlavičkou a telom cenovej ponuky (firma, zákazník, položky, súhrn).
class QuoteDocumentCard extends StatelessWidget {
  final Company? company;
  final Customer customer;
  final String quoteNumber;
  final String validUntilText;
  final DateTime createdAt;
  final DateTime? validUntil;
  final String notesText;
  final List<QuoteItem> items;
  final bool pricesIncludeVat;
  final AppLocalizations l10n;
  final double subtotalWithoutVat;
  final double totalVat;
  final double totalWithVat;
  final VoidCallback onEditCompany;
  final bool customerVatPayer;

  const QuoteDocumentCard({
    super.key,
    required this.company,
    required this.customer,
    required this.quoteNumber,
    required this.validUntilText,
    required this.createdAt,
    this.validUntil,
    required this.notesText,
    required this.items,
    required this.pricesIncludeVat,
    required this.l10n,
    required this.subtotalWithoutVat,
    required this.totalVat,
    required this.totalWithVat,
    required this.onEditCompany,
    this.customerVatPayer = true,
  });

  static String formatDate(DateTime d) => '${d.day}.${d.month}.${d.year}';

  static String formatPrice(double v) =>
      v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final border = TableBorder.all(color: AppColors.borderDefault, width: 0.5);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CENOVÁ PONUKA',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  quoteNumber.isEmpty ? '—' : quoteNumber,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentGold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (company != null) ...[
                        Text(
                          company!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (company!.fullAddress.isNotEmpty)
                          Text(
                            company!.fullAddress,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (company!.registerInfo != null &&
                            company!.registerInfo!.isNotEmpty)
                          Text(
                            company!.registerInfo!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (company!.ico != null && company!.ico!.isNotEmpty)
                          Text(
                            'IČO: ${company!.ico}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (company!.dic != null && company!.dic!.isNotEmpty)
                          Text(
                            'DIČ: ${company!.dic}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (company!.icDph != null &&
                            company!.icDph!.isNotEmpty)
                          Text(
                            'IČ DPH: ${company!.icDph}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (company!.vatPayer)
                          Text(
                            l10n.vatPayer,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (company!.phone != null &&
                            company!.phone!.isNotEmpty)
                          Text(
                            'Tel: ${company!.phone}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (company!.email != null &&
                            company!.email!.isNotEmpty)
                          Text(
                            'Email: ${company!.email}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (company!.iban != null && company!.iban!.isNotEmpty)
                          Text(
                            'IBAN: ${company!.iban}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: Text(
                            l10n.editCompany,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: onEditCompany,
                        ),
                      ] else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.ourCompany,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.add_business, size: 18),
                              label: Text(l10n.editCompany),
                              onPressed: onEditCompany,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.teal.withValues(alpha: 0.15),
                                foregroundColor: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.offerFor,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (customer.address != null &&
                          customer.address!.isNotEmpty)
                        Text(
                          customer.address!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (customer.city != null && customer.city!.isNotEmpty)
                        Text(
                          '${customer.postalCode ?? ''} ${customer.city}'.trim(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '${l10n.dateOfIssue}: ',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  formatDate(createdAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 24),
                Text(
                  '${l10n.validUntil}: ',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  validUntil != null ? formatDate(validUntil!) : '—',
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
              ],
            ),
            if (notesText.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.notes,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notesText.trim(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Table(
              border: border,
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(0.5),
                2: FlexColumnWidth(0.4),
                3: FlexColumnWidth(0.8),
                4: FlexColumnWidth(0.8),
                5: FlexColumnWidth(0.4),
                6: FlexColumnWidth(0.8),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: AppColors.bgElevated),
                  children: [
                    _tableCell(l10n.itemDescription, bold: true),
                    _tableCell(l10n.quantity, bold: true),
                    _tableCell(l10n.unitShort, bold: true),
                    _tableCell(l10n.pricePerUnit, bold: true),
                    _tableCell(l10n.totalWithoutVatShort, bold: true),
                    _tableCell(l10n.vatShort, bold: true),
                    _tableCell(l10n.totalWithVatShort, bold: true),
                  ],
                ),
                ...items.map((item) {
                  final withoutVat = item.getLineTotalWithoutVat(pricesIncludeVat);
                  final withVat = item.getLineTotalWithVat(pricesIncludeVat);
                  return TableRow(
                    children: [
                      _tableCell(item.productName ?? item.productUniqueId),
                      _tableCell('${item.qty}'),
                      _tableCell(item.unit),
                      _tableCell(formatPrice(item.unitPrice)),
                      _tableCell(formatPrice(withoutVat)),
                      _tableCell('${item.vatPercent}%'),
                      _tableCell(formatPrice(withVat)),
                    ],
                  );
                }),
              ],
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l10n.totalLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.totalWithoutVatShort}: ${formatPrice(subtotalWithoutVat)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${l10n.vatShort}: ${formatPrice(totalVat)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${l10n.totalWithVatShort}: ${formatPrice(totalWithVat)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (!customerVatPayer) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Zákazník nie je platcom DPH',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _tableCell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : null,
          color: bold ? AppColors.textPrimary : AppColors.textSecondary,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

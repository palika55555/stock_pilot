import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/company.dart';
import '../../models/customer.dart';
import '../../models/quote.dart';

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
  });

  static String formatDate(DateTime d) => '${d.day}.${d.month}.${d.year}';

  static String formatPrice(double v) =>
      v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final border = TableBorder.all(color: Colors.grey.shade300, width: 0.5);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
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
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  quoteNumber.isEmpty ? '—' : quoteNumber,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
                          ),
                        ),
                        if (company!.fullAddress.isNotEmpty)
                          Text(
                            company!.fullAddress,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        if (company!.registerInfo != null &&
                            company!.registerInfo!.isNotEmpty)
                          Text(
                            company!.registerInfo!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (company!.ico != null && company!.ico!.isNotEmpty)
                          Text(
                            'IČO: ${company!.ico}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        if (company!.icDph != null &&
                            company!.icDph!.isNotEmpty)
                          Text(
                            'IČ DPH: ${company!.icDph}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        if (company!.vatPayer)
                          Text(
                            l10n.vatPayer,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (company!.phone != null &&
                            company!.phone!.isNotEmpty)
                          Text(
                            'TELEFÓN: ${company!.phone}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (company!.email != null &&
                            company!.email!.isNotEmpty)
                          Text(
                            'EMAIL: ${company!.email}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (company!.web != null && company!.web!.isNotEmpty)
                          Text(
                            'WEB: ${company!.web}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (company!.iban != null &&
                            company!.iban!.isNotEmpty)
                          Text(
                            'IBAN: ${company!.iban}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (company!.swift != null &&
                            company!.swift!.isNotEmpty)
                          Text(
                            'SWIFT: ${company!.swift}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (company!.bankName != null &&
                            company!.bankName!.isNotEmpty)
                          Text(
                            'BANKA: ${company!.bankName}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        if (company!.account != null &&
                            company!.account!.isNotEmpty)
                          Text(
                            'ÚČET: ${company!.account}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
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
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              icon: const Icon(Icons.add_business, size: 18),
                              label: Text(l10n.editCompany),
                              onPressed: onEditCompany,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.teal.withValues(
                                  alpha: 0.15,
                                ),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (customer.address != null &&
                          customer.address!.isNotEmpty)
                        Text(
                          customer.address!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      if (customer.city != null && customer.city!.isNotEmpty)
                        Text(
                          '${customer.postalCode ?? ''} ${customer.city}'
                              .trim(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
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
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                Text(
                  formatDate(createdAt),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 24),
                Text(
                  '${l10n.validUntil}: ',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                Text(
                  validUntil != null ? formatDate(validUntil!) : '—',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            if (notesText.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.notes,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notesText.trim(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade800,
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
                  decoration: BoxDecoration(color: Colors.grey.shade200),
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
                  final withoutVat =
                      item.getLineTotalWithoutVat(pricesIncludeVat);
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l10n.totalWithoutVatShort}: ${formatPrice(subtotalWithoutVat)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${l10n.vatShort}: ${formatPrice(totalVat)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${l10n.totalWithVatShort}: ${formatPrice(totalWithVat)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

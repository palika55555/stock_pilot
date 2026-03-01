import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:stock_pilot/models/pallet.dart';

/// Štítok palety na tlač/zobrazenie: firma (placeholder), produkt, dátum, počet kusov, QR.
class PalletLabelWidget extends StatelessWidget {
  final Pallet pallet;
  final String productName;
  final String productionDate;
  final String? companyName;

  const PalletLabelWidget({
    super.key,
    required this.pallet,
    required this.productName,
    required this.productionDate,
    this.companyName,
  });

  @override
  Widget build(BuildContext context) {
    final payload = Pallet.qrPayload(pallet.id!);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Placeholder pre logo + názov firmy
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    companyName ?? 'Názov firmy',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              productName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dátum výroby: $productionDate',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Počet kusov na palete: ${pallet.quantity}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 16),
            Center(
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Paleta #${pallet.id}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

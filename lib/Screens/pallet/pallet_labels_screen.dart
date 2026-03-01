import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock_pilot/models/pallet.dart';
import 'package:stock_pilot/screens/pallet/pallet_label_widget.dart';

/// Zoznam štítkov paliet po vytvorení z šarže.
class PalletLabelsScreen extends StatelessWidget {
  final List<Pallet> pallets;
  final String productName;
  final String productionDate;
  final String? companyName;

  const PalletLabelsScreen({
    super.key,
    required this.pallets,
    required this.productName,
    required this.productionDate,
    this.companyName,
  });

  String _formatDate(String isoDate) {
    try {
      return DateFormat('d. M. yyyy', 'sk').format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Štítky paliet'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: pallets.length,
        itemBuilder: (context, index) {
          final pallet = pallets[index];
          return PalletLabelWidget(
            pallet: pallet,
            productName: productName,
            productionDate: _formatDate(productionDate),
            companyName: companyName ?? 'Názov firmy',
          );
        },
      ),
    );
  }
}

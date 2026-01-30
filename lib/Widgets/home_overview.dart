import 'package:flutter/material.dart';
import 'dashboard_stats.dart';
import 'receipts_widget.dart';

class HomeOverview extends StatelessWidget {
  const HomeOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prehľad',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            DashboardStats(
              products: 150,
              orders: 23,
              customers: 89,
              revenue: 12450.0,
              onCardTap: (cardType) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Detail: $cardType')),
                );
              },
            ),
            const SizedBox(height: 24),
            ReceiptsWidget(
              inboundCount: 45,
              outboundCount: 32,
              onReceiptTap: (receiptType) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Pohyby: $receiptType')),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}





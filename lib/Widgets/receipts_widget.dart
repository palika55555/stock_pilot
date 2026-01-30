// lib/widgets/receipts_widget.dart
import 'package:flutter/material.dart';

class ReceiptsWidget extends StatelessWidget {
  final int inboundCount;
  final int outboundCount;
  final Function(String)? onReceiptTap;

  const ReceiptsWidget({
    super.key,
    required this.inboundCount,
    required this.outboundCount,
    this.onReceiptTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pohyby zásob', 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildReceiptCard(
                'Príjemky', 'Príjem tovaru', Icons.south_west_rounded, 
                const Color(0xFF10B981), inboundCount.toString(), () => onReceiptTap?.call('inbound')
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildReceiptCard(
                'Výdajky', 'Výdaj tovaru', Icons.north_east_rounded, 
                const Color(0xFFEF4444), outboundCount.toString(), () => onReceiptTap?.call('outbound')
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReceiptCard(String title, String sub, IconData icon, Color color, String count, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
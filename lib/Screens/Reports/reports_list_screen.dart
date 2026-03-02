import 'package:flutter/material.dart';
import 'receipt_summary_report_screen.dart';

/// Sekcia Reporty – zoznam typov reportov.
class ReportsListScreen extends StatelessWidget {
  const ReportsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('Reporty'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportTile(
            icon: Icons.receipt_long_rounded,
            title: 'Prehľad príjemiek',
            subtitle: 'Filtre: dátum, status, sklad, dodávateľ',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ReceiptSummaryReportScreen(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _ReportTile(
            icon: Icons.swap_horiz_rounded,
            title: 'Pohyby skladu',
            subtitle: 'Dátum, sklad, produkt, typ pohybu',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _ReportTile(
            icon: Icons.local_shipping_rounded,
            title: 'Dodávatelia',
            subtitle: 'Prehľad podľa dodávateľov',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _ReportTile(
            icon: Icons.how_to_reg_rounded,
            title: 'Výkon schvaľovania',
            subtitle: 'Len pre admin – priemerný čas, % zamietnutých',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _ReportTile(
            icon: Icons.trending_up_rounded,
            title: 'Vývoj cien',
            subtitle: 'Ceny produktov v čase',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _ReportTile(
            icon: Icons.euro_rounded,
            title: 'Obstarávacie náklady',
            subtitle: 'Doprava, clo, balné – rozpis',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
          child: Icon(icon, color: const Color(0xFF10B981)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

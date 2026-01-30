import 'package:flutter/material.dart';
import 'responsive_layout.dart';

class DashboardStats extends StatelessWidget {
  final int products;
  final int orders;
  final int customers;
  final double revenue;
  final Function(String)? onCardTap;

  const DashboardStats({
    super.key,
    required this.products,
    required this.orders,
    required this.customers,
    required this.revenue,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(context),
      desktop: _buildDesktopLayout(context),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(context, 'Produkty', Icons.inventory_2_rounded, const Color(0xFF6366F1), products.toString(), 'products'),
        _buildStatCard(context, 'Objednávky', Icons.shopping_bag_rounded, const Color(0xFFF59E0B), orders.toString(), 'orders'),
        _buildStatCard(context, 'Zákazníci', Icons.people_alt_rounded, const Color(0xFF10B981), customers.toString(), 'customers'),
        _buildStatCard(context, 'Tržby', Icons.euro_symbol_rounded, const Color(0xFF3B82F6), '€${revenue.toStringAsFixed(0)}', 'revenue'),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildStatCard(context, 'Produkty', Icons.inventory_2_rounded, const Color(0xFF6366F1), products.toString(), 'products'),
          const SizedBox(width: 16),
          _buildStatCard(context, 'Objednávky', Icons.shopping_bag_rounded, const Color(0xFFF59E0B), orders.toString(), 'orders'),
          const SizedBox(width:  16),
          _buildStatCard(context, 'Zákazníci', Icons.people_alt_rounded, const Color(0xFF10B981), customers.toString(), 'customers'),
          const SizedBox(width: 16),
          _buildStatCard(context, 'Tržby', Icons.euro_symbol_rounded, const Color(0xFF3B82F6), '€${revenue.toStringAsFixed(0)}', 'revenue'),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, IconData icon, Color color, String value, String cardType) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      width: isMobile ? null : 150,
      height: isMobile ? 100 : 140,
      constraints: isMobile ? null : const BoxConstraints(minWidth: 150, maxWidth: 150),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.08), blurRadius: isMobile ? 12 : 20, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onCardTap?.call(cardType),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(isMobile ? 8 : 12)),
                    child: Icon(icon, color: color, size: isMobile ? 18 : 22),
                  ),
                  const Spacer(),
                  Text(title, style: TextStyle(fontSize: isMobile ? 10 : 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

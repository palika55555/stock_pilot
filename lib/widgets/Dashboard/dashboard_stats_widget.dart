import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../common/responsive_layout_widget.dart';

class DashboardStats extends StatefulWidget {
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
  State<DashboardStats> createState() => _DashboardStatsState();
}

class _DashboardStatsState extends State<DashboardStats>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        _AnimatedStatCard(
          delay: 0,
          controller: _controller,
          title: 'Produkty',
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFF6366F1),
          value: widget.products.toString(),
          cardType: 'products',
          onTap: widget.onCardTap,
        ),
        _AnimatedStatCard(
          delay: 100,
          controller: _controller,
          title: 'Objednávky',
          icon: Icons.shopping_bag_rounded,
          color: const Color(0xFFF59E0B),
          value: widget.orders.toString(),
          cardType: 'orders',
          onTap: widget.onCardTap,
        ),
        _AnimatedStatCard(
          delay: 200,
          controller: _controller,
          title: 'Zákazníci',
          icon: Icons.people_alt_rounded,
          color: const Color(0xFF10B981),
          value: widget.customers.toString(),
          cardType: 'customers',
          onTap: widget.onCardTap,
        ),
        _AnimatedStatCard(
          delay: 300,
          controller: _controller,
          title: 'Tržby',
          icon: Icons.euro_symbol_rounded,
          color: const Color(0xFF3B82F6),
          value: '€${widget.revenue.toStringAsFixed(0)}',
          cardType: 'revenue',
          onTap: widget.onCardTap,
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _AnimatedStatCard(
            delay: 0,
            controller: _controller,
            title: 'Produkty',
            icon: Icons.inventory_2_rounded,
            color: const Color(0xFF6366F1),
            value: widget.products.toString(),
            cardType: 'products',
            onTap: widget.onCardTap,
            isMobile: false,
          ),
          const SizedBox(width: 16),
          _AnimatedStatCard(
            delay: 100,
            controller: _controller,
            title: 'Objednávky',
            icon: Icons.shopping_bag_rounded,
            color: const Color(0xFFF59E0B),
            value: widget.orders.toString(),
            cardType: 'orders',
            onTap: widget.onCardTap,
            isMobile: false,
          ),
          const SizedBox(width: 16),
          _AnimatedStatCard(
            delay: 200,
            controller: _controller,
            title: 'Zákazníci',
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF10B981),
            value: widget.customers.toString(),
            cardType: 'customers',
            onTap: widget.onCardTap,
            isMobile: false,
          ),
          const SizedBox(width: 16),
          _AnimatedStatCard(
            delay: 300,
            controller: _controller,
            title: 'Tržby',
            icon: Icons.euro_symbol_rounded,
            color: const Color(0xFF3B82F6),
            value: '€${widget.revenue.toStringAsFixed(0)}',
            cardType: 'revenue',
            onTap: widget.onCardTap,
            isMobile: false,
          ),
        ],
      ),
    );
  }
}

class _AnimatedStatCard extends StatelessWidget {
  final int delay;
  final AnimationController controller;
  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String cardType;
  final Function(String)? onTap;
  final bool isMobile;

  const _AnimatedStatCard({
    required this.delay,
    required this.controller,
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.cardType,
    this.onTap,
    this.isMobile = true,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Interval(
        (delay / 1000).clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, animValue, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animValue)),
          child: Opacity(
            opacity: animValue,
            child: Transform.scale(
              scale: 0.9 + (0.1 * animValue),
              child: _buildStatCard(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context) {
    final radius = isMobile ? 16.0 : 24.0;
    return Container(
      width: isMobile ? null : 150,
      height: isMobile ? 100 : 140,
      constraints: isMobile
          ? null
          : const BoxConstraints(minWidth: 150, maxWidth: 150),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12 * (isMobile ? 1 : 1.2)),
            blurRadius: isMobile ? 12 : 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          const BoxShadow(
            color: Colors.black45,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTap?.call(cardType),
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(
                              isMobile ? 8 : 12,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: color,
                            size: isMobile ? 18 : 22,
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _AnimatedValueText(
                    value: value,
                    isMobile: isMobile,
                    color: color,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedValueText extends StatefulWidget {
  final String value;
  final bool isMobile;
  final Color color;

  const _AnimatedValueText({
    required this.value,
    required this.isMobile,
    required this.color,
  });

  @override
  State<_AnimatedValueText> createState() => _AnimatedValueTextState();
}

class _AnimatedValueTextState extends State<_AnimatedValueText> {
  @override
  Widget build(BuildContext context) {
    // Extrahujeme číselnú hodnotu
    final numericValue =
        int.tryParse(widget.value.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: numericValue),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        String displayValue;
        if (widget.value.contains('€')) {
          displayValue = '€${animatedValue.toString()}';
        } else {
          displayValue = animatedValue.toString();
        }
        return Text(
          displayValue,
          style: TextStyle(
            fontSize: widget.isMobile ? 16 : 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: widget.color.withOpacity(0.9),
          ),
        );
      },
    );
  }
}

// lib/widgets/receipts_widget.dart
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class ReceiptsWidget extends StatefulWidget {
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
  State<ReceiptsWidget> createState() => _ReceiptsWidgetState();
}

class _ReceiptsWidgetState extends State<ReceiptsWidget>
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.stockMovements,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _AnimatedReceiptCard(
                delay: 0,
                controller: _controller,
                title: l10n.inboundReceipts,
                sub: l10n.inboundGoods,
                icon: Icons.south_west_rounded,
                color: const Color(0xFF10B981),
                count: widget.inboundCount,
                onTap: () => widget.onReceiptTap?.call('inbound'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _AnimatedReceiptCard(
                delay: 150,
                controller: _controller,
                title: l10n.outboundReceipts,
                sub: l10n.outboundGoods,
                icon: Icons.north_east_rounded,
                color: const Color(0xFFEF4444),
                count: widget.outboundCount,
                onTap: () => widget.onReceiptTap?.call('outbound'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnimatedReceiptCard extends StatelessWidget {
  final int delay;
  final AnimationController controller;
  final String title;
  final String sub;
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;

  const _AnimatedReceiptCard({
    required this.delay,
    required this.controller,
    required this.title,
    required this.sub,
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
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
              scale: 0.95 + (0.05 * animValue),
              child: _buildReceiptCard(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptCard() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
              spreadRadius: 0,
            ),
          ],
          border: Border.all(color: color.withOpacity(0.1), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                    );
                  },
                ),
                _AnimatedCountText(count: count, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCountText extends StatelessWidget {
  final int count;
  final Color color;

  const _AnimatedCountText({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: count),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          animatedValue.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        );
      },
    );
  }
}

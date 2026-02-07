import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../dashboard/dashboard_stats_widget.dart';
import '../receipts/receipts_widget.dart';
import '../../screens/goods_receipt/goods_receipt_screen.dart';
import '../../screens/price_quote/price_quotes_list_screen.dart';
import '../../services/dashboard/dashboard_service.dart';
import '../../l10n/app_localizations.dart';

class HomeOverview extends StatefulWidget {
  const HomeOverview({super.key});

  @override
  State<HomeOverview> createState() => _HomeOverviewState();
}

class _HomeOverviewState extends State<HomeOverview>
    with SingleTickerProviderStateMixin {
  final DashboardService _dashboardService = DashboardService();
  late AnimationController _backgroundController;
  Map<String, dynamic> _stats = {
    'products': 0,
    'orders': 0,
    'customers': 0,
    'revenue': 0.0,
    'inboundCount': 0,
    'outboundCount': 0,
    'quotesCount': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _loadStats();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await _dashboardService.getOverviewStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667EEA),
              const Color(0xFF764BA2),
              const Color(0xFFF093FB),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animované dekoratívne kruhy v pozadí
            AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return Stack(
                  children: [
                    // Veľký kruh vpravo hore - pomaly sa pohybuje
                    Positioned(
                      top:
                          -100 +
                          (math.sin(_backgroundController.value * 2 * math.pi) *
                              30),
                      right:
                          -100 +
                          (math.cos(_backgroundController.value * 2 * math.pi) *
                              20),
                      child: Transform.scale(
                        scale:
                            1.0 +
                            (math.sin(
                                  _backgroundController.value * 2 * math.pi,
                                ) *
                                0.1),
                        child: Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.08),
                                Colors.white.withOpacity(0.02),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Veľký kruh vľavo dole - pomaly sa pohybuje
                    Positioned(
                      bottom:
                          -150 +
                          (math.cos(_backgroundController.value * 2 * math.pi) *
                              40),
                      left:
                          -150 +
                          (math.sin(_backgroundController.value * 2 * math.pi) *
                              30),
                      child: Transform.scale(
                        scale:
                            1.0 +
                            (math.cos(
                                  _backgroundController.value * 2 * math.pi,
                                ) *
                                0.15),
                        child: Container(
                          width: 400,
                          height: 400,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.06),
                                Colors.white.withOpacity(0.01),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Stredný kruh vľavo - pomaly sa pohybuje
                    Positioned(
                      top:
                          200 +
                          (math.sin(
                                _backgroundController.value * 2 * math.pi +
                                    math.pi / 2,
                              ) *
                              25),
                      left:
                          -50 +
                          (math.cos(
                                _backgroundController.value * 2 * math.pi +
                                    math.pi / 2,
                              ) *
                              20),
                      child: Transform.scale(
                        scale:
                            1.0 +
                            (math.sin(
                                  _backgroundController.value * 2 * math.pi +
                                      math.pi / 2,
                                ) *
                                0.1),
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.07),
                                Colors.white.withOpacity(0.02),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Malý kruh vpravo dole
                    Positioned(
                      bottom:
                          100 +
                          (math.cos(
                                _backgroundController.value * 2 * math.pi +
                                    math.pi,
                              ) *
                              20),
                      right:
                          50 +
                          (math.sin(
                                _backgroundController.value * 2 * math.pi +
                                    math.pi,
                              ) *
                              15),
                      child: Transform.scale(
                        scale:
                            1.0 +
                            (math.cos(
                                  _backgroundController.value * 2 * math.pi +
                                      math.pi,
                                ) *
                                0.1),
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withOpacity(0.06),
                                Colors.white.withOpacity(0.01),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            // Hlavný obsah
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  top:
                      MediaQuery.of(context).padding.top +
                      96, // SafeArea + AppBar výška (80) + padding (16)
                  left: 16.0,
                  right: 16.0,
                  bottom: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.overview,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    DashboardStats(
                      products: _stats['products'],
                      orders: _stats['orders'],
                      customers: _stats['customers'],
                      revenue: _stats['revenue'],
                      onCardTap: (cardType) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${l10n.detail}: $cardType')),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    ReceiptsWidget(
                      inboundCount: _stats['inboundCount'],
                      outboundCount: _stats['outboundCount'],
                      onReceiptTap: (receiptType) {
                        if (receiptType == 'inbound') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GoodsReceiptScreen(),
                            ),
                          ).then((_) => _loadStats());
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${l10n.warehouseMovements}: $receiptType',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildQuotesCard(context, l10n),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotesCard(BuildContext context, AppLocalizations l10n) {
    final count = _stats['quotesCount'] ?? 0;
    const color = Color(0xFF0D9488); // teal
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.priceQuote,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PriceQuotesListScreen()),
            ).then((_) => _loadStats());
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.request_quote,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.priceQuote,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count == 0
                            ? l10n.noSavedQuotes
                            : (count == 1
                                  ? l10n.oneSavedQuote
                                  : l10n.savedQuotesCount(count)),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0D9488),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

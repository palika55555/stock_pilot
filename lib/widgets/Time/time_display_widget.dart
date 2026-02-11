import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import '../../services/Dashboard/dashboard_service.dart';
import '../../screens/price_quote/price_quotes_list_screen.dart';

class TimeDisplayWidget extends StatefulWidget {
  final RouteObserver<ModalRoute<void>>? routeObserver;

  const TimeDisplayWidget({super.key, this.routeObserver});

  @override
  State<TimeDisplayWidget> createState() => _TimeDisplayWidgetState();
}

class _TimeDisplayWidgetState extends State<TimeDisplayWidget>
    with RouteAware {
  late DateTime _now;
  Timer? _timer;
  final DashboardService _dashboardService = DashboardService();
  int _pendingTasks = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadQuickStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (widget.routeObserver != null && route is ModalRoute<void>) {
      widget.routeObserver!.unsubscribe(this);
      widget.routeObserver!.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.routeObserver?.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadQuickStats();
  }

  Future<void> _loadQuickStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _dashboardService.getOverviewStats();
      if (mounted) {
        setState(() {
          // Počítame "pending tasks" ako nevybavené quotes
          _pendingTasks = stats['quotesCount'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String hour = _now.hour.toString().padLeft(2, '0');
    final String minute = _now.minute.toString().padLeft(2, '0');
    final String second = _now.second.toString().padLeft(2, '0');

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: const BoxConstraints(minHeight: 50),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Čas v jednom riadku
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "$hour:$minute",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        second,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.7),
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getDayName(_now.weekday),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Vertikálna čiara
              Container(
                width: 1,
                height: 30,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(width: 12),
              // Rýchle štatistiky – Ponuky (kliknutím na obrazovku ponúk)
              _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) =>
                                  const PriceQuotesListScreen(),
                            ),
                          ).then((_) {
                            if (mounted) _loadQuickStats();
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.pending_actions_rounded,
                                  size: 14,
                                  color: _pendingTasks > 0
                                      ? Colors.orange[300]
                                      : Colors.white.withOpacity(0.5),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _pendingTasks.toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _pendingTasks > 0
                                        ? Colors.orange[300]
                                        : Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Ponuky',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = ['Ne', 'Pon', 'Ut', 'St', 'Št', 'Pi', 'So'];
    return days[weekday % 7];
  }
}

import 'package:flutter/material.dart';
import '../../widgets/dashboard/dashboard_header_widget.dart';
import '../../widgets/dashboard/mobile_dashboard_header_widget.dart';
import '../../widgets/dashboard/dashboard_stats_widget.dart';
import '../../widgets/notifications/notifications_sheet_widget.dart';
import '../../widgets/common/responsive_layout_widget.dart';
import '../../services/database/database_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseService _dbService = DatabaseService();
  Map<String, dynamic> _stats = {
    'products': 0,
    'orders': 0,
    'customers': 0,
    'revenue': 0.0,
  };
  bool _isLoading = true;
  String _currentRole = 'Skladník';

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await _dbService.getDashboardStats();
    setState(() {
      _stats = stats;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Container(
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
            )
          : RefreshIndicator(
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
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ResponsiveLayout(
                          mobile: MobileDashboardHeader(
                            title: 'Prehľad',
                            subtitle: 'Štatistiky a metriky',
                            userName: 'Ján Novák',
                            userRole: _currentRole,
                            notificationCount: 3,
                            onNotificationTap: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withOpacity(0.5),
                                builder: (context) =>
                                    const NotificationsSheet(),
                              );
                            },
                            onRoleSwitch: (newRole) {
                              setState(() {
                                _currentRole = newRole == 'admin'
                                    ? 'Admin'
                                    : 'Skladník';
                              });
                            },
                          ),
                          desktop: DashboardHeader(
                            title: 'Prehľad',
                            subtitle: 'Štatistiky a metriky',
                            userName: 'Ján Novák',
                            userRole: _currentRole,
                            notificationCount: 3,
                            onRoleSwitch: (newRole) {
                              setState(() {
                                _currentRole = newRole == 'admin'
                                    ? 'Admin'
                                    : 'Skladník';
                              });
                            },
                            onProfileTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profil používateľa'),
                                ),
                              );
                            },
                            onNotificationTap: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black.withOpacity(0.5),
                                builder: (context) =>
                                    const NotificationsSheet(),
                              );
                            },
                            onSettingsTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nastavenia')),
                              );
                            },
                            onSearchTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Hľadanie')),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        DashboardStats(
                          products: _stats['products'],
                          orders: _stats['orders'],
                          customers: _stats['customers'],
                          revenue: _stats['revenue'],
                          onCardTap: (cardType) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Dashboard: $cardType')),
                            );
                          },
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

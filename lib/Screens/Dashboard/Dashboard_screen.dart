import 'package:flutter/material.dart';
import '../../Widgets/dashboard_header.dart';
import '../../Widgets/mobile_dashboard_header.dart';
import '../../Widgets/dashboard_stats.dart';
import '../../Widgets/responsive_layout.dart';
import '../../Services/database_service.dart';

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
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadStats,
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
                        onRoleSwitch: (newRole) {
                          setState(() {
                            _currentRole = newRole == 'admin' ? 'Admin' : 'Skladník';
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
                            _currentRole = newRole == 'admin' ? 'Admin' : 'Skladník';
                          });
                        },
                        onProfileTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profil používateľa')),
                          );
                        },
                        onNotificationTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notifikácie')),
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
    );
  }
}


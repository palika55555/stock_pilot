import 'package:flutter/material.dart';
// Uisti sa, že táto cesta zodpovedá tvojej štruktúre priečinkov
import 'package:stock_pilot/Widgets/scan_product.dart';
import 'package:stock_pilot/Widgets/warehouse_supplies.dart';
import 'package:stock_pilot/Widgets/login_page.dart';
import 'package:stock_pilot/Widgets/suppliers_page.dart';
class AppDrawer extends StatelessWidget {
  final String userRole;
  const AppDrawer({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      // Zaoblené rohy na pravej strane drawera
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      // Pridané pre lepší výkon
      elevation: 16.0,
      child: Column(
        children: [
          // Záhlavie menu s informáciami o sklade/firme
          _DrawerHeader(userRole: userRole),
          
          // Položky menu
          Expanded(
            child: _MenuItemsList(userRole: userRole),
          ),
          
          // Spodná časť s odhlásením
          const Divider(),
          _LogoutItem(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// Konštantné widgety pre lepší výkon
class _DrawerHeader extends StatelessWidget {
  final String userRole;
  const _DrawerHeader({required this.userRole});

  @override
  Widget build(BuildContext context) {
    return DrawerHeader(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_rounded, size: 50, color: Colors.white),
            SizedBox(height: 10),
            Text(
              'StockPilot v1.0',
              style: TextStyle(
                color: Colors.white, 
                fontSize: 18, 
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItemsList extends StatelessWidget {
  final String userRole;
  const _MenuItemsList({required this.userRole});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      // Pridané pre lepší scrolling výkon
      cacheExtent: 250.0,
      children: [
        _MenuItem(
          icon: Icons.dashboard_rounded,
          title: 'Prehľad',
          onTap: () => Navigator.pop(context),
        ),
        _MenuItem(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Skenovať tovar',
          onTap: () {
            // 1. Najprv zavrieme Drawer
            Navigator.pop(context);
            // 2. Potom navigujeme na obrazovku skenera
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ScanProductScreen(),
              ),
            );
          },
        ),
          _MenuItem(
          icon: Icons.storage_rounded,
          title: 'Skladové zásoby',
          onTap: () {
           Navigator.pop(context); // Zavrie menu
           Navigator.push(
          context,
        MaterialPageRoute(builder: (context) => WarehouseSuppliesScreen(userRole: userRole)),
    );
  },
),
        
        _MenuItem(
          icon: Icons.swap_horiz_rounded,
          title: 'Pohyby na sklade',
          onTap: () {
            Navigator.pop(context);
            // Tu neskôr pridáš: Navigator.push(...)
          },
        ),
         _MenuItem(
          icon: Icons.swap_horiz_rounded,
          title: 'Dodávatelia',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
          context,
        MaterialPageRoute(builder: (context) => SuppliersPage()),
    );
          },
        ),
        const Divider(),
        _MenuItem(
          icon: Icons.settings_rounded,
          title: 'Nastavenia',
          onTap: () {
            Navigator.pop(context);
            // Tu neskôr pridáš: Navigator.push(...)
          },
        ),
      ],
    );
  }
}

class _LogoutItem extends StatelessWidget {
  const _LogoutItem();

  @override
  Widget build(BuildContext context) {
    return _MenuItem(
      icon: Icons.logout_rounded,
      title: 'Odhlásiť sa',
      color: Colors.redAccent,
      onTap: () {
        // Zavrie drawer a presmeruje na login stránku
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      },
    );
  }
}

// Optimalizovaný menu item widget s lepšími transitionmi
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Pridané pre lepší tap feedback
        splashColor: Colors.blue.withOpacity(0.1),
        highlightColor: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Mierne zväčšený vertical padding pre lepšiu klikateľnosť
          child: Row(
            children: [
              Icon(
                icon, 
                color: color ?? Colors.blue[700],
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: color ?? Colors.black87,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
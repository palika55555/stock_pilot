import 'package:flutter/material.dart';
import 'package:stock_pilot/Screens/Invoices/invoices_screen.dart';
import 'package:stock_pilot/Screens/Notifications/notification_center_screen.dart';
import 'package:stock_pilot/Screens/Transport/transport_calculator_screen.dart';
import 'package:stock_pilot/Screens/inventory/inventory_history_screen.dart';
import 'package:stock_pilot/screens/ProductionOrder/production_order_list_screen.dart';
import 'package:stock_pilot/screens/Recipe/recipe_list_screen.dart';
import 'package:stock_pilot/screens/Reports/reports_list_screen.dart';
import 'package:stock_pilot/screens/Search/search_screen.dart';
import 'package:stock_pilot/screens/Settings/settings_page.dart';
import 'package:stock_pilot/screens/customers/customers_page.dart';
import 'package:stock_pilot/screens/goods_receipt/goods_receipt_screen.dart';
import 'package:stock_pilot/screens/pallet/customers_pallets_screen.dart';
import 'package:stock_pilot/screens/price_quote/price_quotes_list_screen.dart';
import 'package:stock_pilot/screens/production/production_list_screen.dart';
import 'package:stock_pilot/screens/scanner/scan_product.dart';
import 'package:stock_pilot/screens/stock_out/stock_out_screen.dart';
import 'package:stock_pilot/screens/suppliers/suppliers_page.dart';
import 'package:stock_pilot/screens/warehouse/warehouse_movements_screen.dart';
import 'package:stock_pilot/screens/warehouse/warehouse_supplies.dart';
import 'package:stock_pilot/screens/warehouse/warehouses_page.dart';

PageRoute<T> fadeAssistantRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 120),
      reverseTransitionDuration: const Duration(milliseconds: 100),
    );

/// Navigácia podľa `screen` z backend nástroja `navigate` (zhodné s [NAVIGATE_SCREENS] na serveri).
void openAssistantTargetScreen(BuildContext context, String screen, String userRole) {
  switch (screen) {
    case 'home':
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    case 'search':
      Navigator.push(context, fadeAssistantRoute(const SearchScreen()));
      return;
    case 'products':
      Navigator.push(context, fadeAssistantRoute(WarehouseSuppliesScreen(userRole: userRole)));
      return;
    case 'customers':
      Navigator.push(context, fadeAssistantRoute(const CustomersPage()));
      return;
    case 'suppliers':
      Navigator.push(context, fadeAssistantRoute(const SuppliersPage()));
      return;
    case 'production':
      Navigator.push(context, fadeAssistantRoute(const ProductionListScreen()));
      return;
    case 'goods_receipt':
      Navigator.push(context, fadeAssistantRoute(const GoodsReceiptScreen()));
      return;
    case 'stock_out':
      Navigator.push(context, fadeAssistantRoute(StockOutScreen(userRole: userRole)));
      return;
    case 'quotes':
      Navigator.push(context, fadeAssistantRoute(const PriceQuotesListScreen()));
      return;
    case 'reports':
      Navigator.push(context, fadeAssistantRoute(const ReportsListScreen()));
      return;
    case 'settings':
      Navigator.push(context, fadeAssistantRoute(SettingsPage(userRole: userRole)));
      return;
    case 'warehouses':
      Navigator.push(context, fadeAssistantRoute(const WarehousesPage()));
      return;
    case 'warehouse_movements':
      Navigator.push(context, fadeAssistantRoute(WarehouseMovementsScreen(userRole: userRole)));
      return;
    case 'recipes':
      Navigator.push(context, fadeAssistantRoute(RecipeListScreen(userRole: userRole)));
      return;
    case 'production_orders':
      Navigator.push(context, fadeAssistantRoute(ProductionOrderListScreen(userRole: userRole)));
      return;
    case 'pallets':
      Navigator.push(context, fadeAssistantRoute(const CustomersPalletsScreen()));
      return;
    case 'invoices':
      Navigator.push(context, fadeAssistantRoute(const InvoicesScreen()));
      return;
    case 'inventory_history':
      Navigator.push(context, fadeAssistantRoute(InventoryHistoryScreen(userRole: userRole)));
      return;
    case 'transport':
      Navigator.push(context, fadeAssistantRoute(const TransportCalculatorScreen()));
      return;
    case 'scanner':
      Navigator.push(context, fadeAssistantRoute(const ScanProductScreen()));
      return;
    case 'notifications':
      Navigator.push(context, fadeAssistantRoute(const NotificationCenterScreen()));
      return;
    default:
      return;
  }
}

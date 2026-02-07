import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database/database_service.dart';

/// Skript na zobrazenie cesty k databáze
/// Spustiť cez: flutter run -t lib/Scripts/show_db_path.dart
void main() async {
  final prefs = await SharedPreferences.getInstance();
  final String? savedDbPath = prefs.getString('db_path');

  print('=== DATABASE PATH INFO ===');
  print('');

  if (savedDbPath != null) {
    print('Vlastná cesta (z SharedPreferences):');
    print('  $savedDbPath');
    print('');
    print('Plná cesta k súboru:');
    print('  ${join(savedDbPath, 'stock_pilot.db')}');
  } else {
    print('Používa sa predvolená cesta');
    final defaultPath = await getDatabasesPath();
    print('Predvolená cesta:');
    print('  $defaultPath');
    print('');
    print('Plná cesta k súboru:');
    print('  ${join(defaultPath, 'stock_pilot.db')}');
  }

  print('');
  print('=== END ===');

  // Získame aj aktuálnu cestu z DatabaseService
  final dbService = DatabaseService();
  if (savedDbPath != null) {
    await dbService.setCustomPath(savedDbPath);
  }
  final currentPath = await dbService.getDatabasePath();
  print('');
  print('Aktuálna cesta z DatabaseService:');
  print('  $currentPath');
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login/login_page.dart';
import 'screens/first_startup/first_startup_screen.dart';
import 'screens/first_startup/create_first_user_screen.dart';
import 'screens/Home/Home_screen.dart';
import 'services/Database/database_service.dart';
import 'models/user.dart';
import 'services/Shortcuts/app_shortcuts_service.dart';
import 'Providers/theme_locale_provider.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final prefs = await SharedPreferences.getInstance();
  final bool isFirstRun = prefs.getBool('is_first_run') ?? true;
  final String? savedDbPath = prefs.getString('db_path');
  final bool darkMode = prefs.getBool(ThemeLocaleProvider.keyDarkMode) ?? false;
  final String localeCode =
      prefs.getString(ThemeLocaleProvider.keyLocale) ?? 'sk';

  if (savedDbPath != null) {
    await DatabaseService().setCustomPath(savedDbPath);
  }

  final themeProvider = ThemeLocaleProvider(
    initialDarkMode: darkMode,
    initialLocale: localeCode,
  );

  User? initialUser;
  bool hasNoUsers = false;
  if (!isFirstRun) {
    final db = DatabaseService();
    final rememberMe = await db.getRememberMe();
    final savedUsername = await db.getSavedUsername();
    if (rememberMe && savedUsername != null && savedUsername.isNotEmpty) {
      initialUser = await db.getUserByUsername(savedUsername);
    }
    // Ak žiadny používateľ nie je prihlásený, skontrolujeme či v DB vôbec sú používatelia
    if (initialUser == null) {
      hasNoUsers = !(await db.hasAnyUsers());
    }
  }

  final routeObserver = RouteObserver<ModalRoute<void>>();

  runApp(MyApp(
    isFirstRun: isFirstRun,
    themeProvider: themeProvider,
    initialUser: initialUser,
    hasNoUsers: hasNoUsers,
    routeObserver: routeObserver,
  ));
}

class MyApp extends StatelessWidget {
  final bool isFirstRun;
  final ThemeLocaleProvider themeProvider;
  final User? initialUser;
  final bool hasNoUsers;
  final RouteObserver<ModalRoute<void>> routeObserver;

  const MyApp({
    super.key,
    required this.isFirstRun,
    required this.themeProvider,
    this.initialUser,
    required this.hasNoUsers,
    required this.routeObserver,
  });

  static ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    );
  }

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      scaffoldBackgroundColor: const Color(0xFF121212),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: themeProvider,
      child: Consumer<ThemeLocaleProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'StockPilot',
            debugShowCheckedModeBanner: false,
            navigatorObservers: [routeObserver],
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            locale: provider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => AppShortcuts(child: child ?? const SizedBox.shrink()),
            home: isFirstRun
                ? const FirstStartupScreen()
                : (initialUser != null
                    ? HomeScreen(user: initialUser!, routeObserver: routeObserver)
                    : hasNoUsers
                        ? CreateFirstUserScreen(routeObserver: routeObserver)
                        : const LoginPage()),
          );
        },
      ),
    );
  }
}

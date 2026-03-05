import 'dart:ui';
import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../../services/Database/database_service.dart';
import '../../services/api_sync_service.dart';
import '../../services/sync_service.dart';
import '../../models/user.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/Common/change_password_dialog.dart';
import '../../widgets/Common/glassmorphism_container.dart';
import 'create_user_screen.dart';
import '../../widgets/Common/glass_text_field.dart';
import '../../widgets/Common/purple_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isObscured = true;
  bool _isLoading = false;
  String? _syncMessage;
  bool _rememberMe = false;
  final DatabaseService _dbService = DatabaseService();

  // Kontroléry pre vstup
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
  }

  Future<void> _loadSavedLogin() async {
    final rememberMe = await _dbService.getRememberMe();
    final savedUsername = await _dbService.getSavedUsername();
    if (mounted) {
      setState(() {
        _rememberMe = rememberMe;
        if (savedUsername != null && savedUsername.isNotEmpty) {
          _loginController.text = savedUsername;
        }
      });
    }
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Skúsime nájsť používateľa v DB
      User? user = await _dbService.getUserByUsername(_loginController.text);

      if (mounted) {
        if (user == null || user.password != _passwordController.text) {
          setState(() => _isLoading = false);
        }
        if (user != null && user.password == _passwordController.text) {
          if (_rememberMe) {
            await _dbService.setRememberMe(true);
            await _dbService.setSavedUsername(user.username);
          } else {
            await _dbService.clearSavedLogin();
          }
          if (!mounted) return;

          // 1) Backend login – získame accessToken + numerické userId z Postgresu
          final loginResult = await fetchBackendToken(
            user.username,
            user.password,
            rememberMe: _rememberMe,
          );
          final backendUserId = loginResult?.userId;
          final token = loginResult?.accessToken;

          // 2) Nastavíme aktuálneho používateľa podľa backend ID (ak je k dispozícii),
          // inak fallback na lokálne username (offline scenár).
          if (backendUserId != null && backendUserId.isNotEmpty) {
            await DatabaseService().migrateUserIdForCurrentUser(
              oldUserId: user.username,
              newUserId: backendUserId,
            );
            await DatabaseService.setCurrentUser(backendUserId);
            print(
              'DEBUG LoginPage: setCurrentUser called with backend userId = $backendUserId (currentUserId=${DatabaseService.currentUserId})',
            );
          } else {
            await DatabaseService.setCurrentUser(user.username);
            print(
              'DEBUG LoginPage: backend login failed or no userId, setCurrentUser fallback to username = ${user.username} (currentUserId=${DatabaseService.currentUserId})',
            );
          }

          // 3) Po nastavení currentUserId môžeme bezpečne pracovať s lokálnou DB
          await syncUserToBackend(user);
          if (!mounted) return;
          final customers = await _dbService.getCustomers();
          final products = await _dbService.getProducts();

          if (token != null) {
            if (mounted) setState(() => _syncMessage = 'Načítavam vaše dáta...');
            syncCustomersToBackend(customers);
            syncProductsToBackend(products);
            await syncBatchesToBackend();
            // 4) Počiatočný sync z backendu – NEmažeme viac lokálne dáta vopred,
            // aby sme pri chybe neskončili s prázdnou DB. Namiesto toho sa spoliehame
            // na replace/update metódy v DatabaseService.
            final ok = await SyncService.initialSync(DatabaseService.currentUserId ?? (user.id?.toString() ?? '0'), token);
            if (!mounted) return;
            if (!ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dáta z webu sa nenačítali. Skontrolujte sieť. Môžete pokračovať v režime offline.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Zákazníci z webu sa nenačítali. Skontrolujte sieť alebo prihlásenie (rovnaký účet ako na webe).'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
          if (!mounted) return;
          setState(() { _isLoading = false; _syncMessage = null; });
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(user: user),
            ),
          );
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.loggedInAs(user.fullName)),
              backgroundColor: user.role == 'admin' ? Colors.redAccent : Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.loginError),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          // Pozadie s obrázkom
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('lib/assets/back_login.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                // Efekt vonkajšej fialovej žiary pod boxom
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purpleAccent.withOpacity(0.4),
                      blurRadius: 50,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GlassmorphismContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                    child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "SKLADOVÝ SYSTÉM",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Sekcia Username
                        GlassTextField(
                          controller: _loginController,
                          labelText: "Username",
                          hintText: "Enter your Username",
                          validator: (v) => v!.isEmpty ? l10n.loginRequired : null,
                        ),
                        const SizedBox(height: 16),

                        // Sekcia Password
                        GlassTextField(
                          controller: _passwordController,
                          labelText: "Password",
                          hintText: "Enter your password",
                          isPassword: true,
                          obscureText: _isObscured,
                          onToggleVisibility: () => setState(() => _isObscured = !_isObscured),
                          validator: (v) => v!.length < 4 ? l10n.passwordMinLength : null,
                        ),
                        const SizedBox(height: 16),

                        // Remember me & Forgot Password riadok
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (v) =>
                                        setState(() => _rememberMe = v ?? false),
                                    side: const BorderSide(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Zapamätať si",
                                  style: TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () => showChangePasswordDialog(context),
                              child: const Text(
                                "zabudol som heslo",
                                style: TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Login Tlačidlo
                        PurpleButton(
                          text: "Login",
                          isLoading: _isLoading,
                          onPressed: _handleLogin,
                        ),
                        if (_syncMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _syncMessage!,
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreateUserScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Vytvoriť používateľa",
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../../services/Database/database_service.dart';
import '../../services/api_sync_service.dart';
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
        setState(() => _isLoading = false);

        if (user != null && user.password == _passwordController.text) {
          if (_rememberMe) {
            await _dbService.setRememberMe(true);
            await _dbService.setSavedUsername(user.username);
          } else {
            await _dbService.clearSavedLogin();
          }
          // Najprv sync používateľa na backend, aby tam bol pred prihlásením (rovnaké meno/heslo)
          await syncUserToBackend(user);
          final customers = await _dbService.getCustomers();
          syncCustomersToBackend(customers);
          // Stiahnuť z backendu zákazníkov (vrátane tých pridaných na webe) – potrebujeme token
          final token = await fetchBackendToken(user.username, user.password);
          if (token != null) setBackendToken(token);
          final fromBackend = await fetchCustomersFromBackendWithToken(token);
          if (fromBackend != null && fromBackend.isNotEmpty && mounted) {
            await _dbService.replaceCustomersFromBackend(fromBackend);
          } else if (mounted && token == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Zákazníci z webu sa nenačítali. Skontrolujte sieť alebo prihlásenie (rovnaký účet ako na webe).'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
          if (!mounted) return;
          // Navigácia na HomeScreen s reálnymi dátami používateľa
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

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/Database/database_service.dart';
import '../../services/api_sync_service.dart';
import '../../screens/Home/Home_screen.dart';
import '../../services/user_session.dart';
import '../../theme/app_theme.dart';
import '../../widgets/Common/standard_text_field.dart';
import '../../widgets/Common/purple_button.dart';

/// Prihlásenie len cez web účet (backend). Používa sa keď je lokálna DB prázdna –
/// web slúži ako záloha: prihlásenie vytvorí lokálny účet z webu a vstúpi do aplikácie.
class WebLoginScreen extends StatefulWidget {
  final RouteObserver<ModalRoute<void>>? routeObserver;
  /// Po úspešnom prihlásení sa nastaví na false, aby ďalší štart neukázal prvotné nastavenie.
  final bool clearFirstRun;

  const WebLoginScreen({
    super.key,
    this.routeObserver,
    this.clearFirstRun = true,
  });

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  Future<void> _loginWithWeb() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final backendResult = await fetchBackendToken(
      username,
      password,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;
    if (backendResult == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Prihlásenie zlyhalo. Skontrolujte údaje alebo pripojenie k internetu.';
      });
      return;
    }

    final fromBackend = userFromBackendProfile(
      username,
      password,
      backendResult.userProfile,
    );
    final backendUserId = backendResult.userId ?? 'user_$username';

    try {
      final accountPath = await _dbService.getAccountDatabasePath(backendUserId);
      await _dbService.setCustomPath(accountPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('db_path', accountPath);
      if (widget.clearFirstRun) {
        await prefs.setBool('is_first_run', false);
      }

      await _dbService.insertUser(fromBackend);
      await DatabaseService.setCurrentUser(backendUserId);

      final createdUser = await _dbService.getUserByUsername(fromBackend.username);
      if (createdUser == null || !mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Chyba pri vytváraní lokálneho účtu.';
        });
        return;
      }

      UserSession.setUser(
        userId: backendUserId,
        username: createdUser.username,
        role: createdUser.role,
        // Pri čisto web logine nemáme nadriadeného – sub-user sa vytvára cez admina na webe.
        ownerFullName: backendResult.ownerFullName,
        ownerUsername: backendResult.ownerUsername,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            user: createdUser,
            routeObserver: widget.routeObserver,
          ),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vitajte, ${createdUser.fullName}. Prihlásený z web účtu.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Chyba: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_done_rounded,
                        size: 56,
                        color: AppColors.accentGold,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Prihlásenie s web účtom',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Zadajte údaje z app.stockpilot.sk. Vytvorí sa lokálny účet a môžete pracovať aj offline.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade800, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      StandardTextField(
                        controller: _usernameController,
                        labelText: 'Používateľské meno',
                        icon: Icons.person_outline,
                        validator: (v) => v!.trim().isEmpty ? 'Zadajte používateľské meno' : null,
                      ),
                      const SizedBox(height: 16),
                      StandardTextField(
                        controller: _passwordController,
                        labelText: 'Heslo',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        obscureText: true,
                        validator: (v) => v!.length < 4 ? 'Minimálne 4 znaky' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          SizedBox(
                            height: 22,
                            width: 22,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (v) => setState(() => _rememberMe = v ?? false),
                              activeColor: AppColors.accentGold,
                              fillColor: MaterialStateProperty.resolveWith((states) {
                                if (states.contains(MaterialState.selected)) return AppColors.accentGold;
                                return Colors.transparent;
                              }),
                              side: BorderSide(color: Colors.grey.shade600),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Zapamätať si prihlásenie', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      PurpleButton(
                        text: 'PRIHLÁSIŤ SA CEZ WEB',
                        isLoading: _isLoading,
                        onPressed: _loginWithWeb,
                        backgroundColor: AppColors.accentGold,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

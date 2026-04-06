import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/Database/database_service.dart';
import '../../services/user_session.dart';
import '../../services/api_sync_service.dart';
import '../../services/sync/sync_manager.dart';
import '../../services/Auth/hash_service.dart';
import '../../models/user.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/Common/change_password_dialog.dart';
import '../../widgets/welcome/welcome_reveal_screen.dart';
import '../../services/app_update_service.dart';
import 'create_user_screen.dart';

/// Tmavé pozadie s mriežkou a zlatou žiarou zhora. [glowOpacity] pre jemné pulzovanie (0.1–0.2).
class _LoginBackground extends StatelessWidget {
  final double glowOpacity;

  const _LoginBackground({this.glowOpacity = 0.18});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: Color(0xFF0F0F12)),
        CustomPaint(
          size: Size.infinite,
          painter: _GridPainter(),
        ),
        Positioned(
          top: -MediaQuery.of(context).size.height * 0.3,
          left: MediaQuery.of(context).size.width * 0.5 - 200,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accentGold.withOpacity(glowOpacity * 1.4),
                  AppColors.accentGold.withOpacity(glowOpacity * 0.45),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF252530).withOpacity(0.5)
      ..strokeWidth = 0.5;
    const step = 24.0;
    for (double x = 0; x <= size.width + step; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height + step; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isObscured = true;
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _buttonPressed = false;
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late AnimationController _entranceController;
  late AnimationController _glowController;
  late Animation<double> _entranceFade;
  late Animation<double> _entranceScale;

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entranceFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _entranceScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _entranceController.forward();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppUpdateService.maybeShowUpdateBanner(context);
    });
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

      final username = _loginController.text.trim();
      final password = _passwordController.text;
      User? user = await _dbService.getUserByUsername(username);
      if (!mounted) return;

      // Overenie hesla — ak salt chýba (starý záznam), porovnaj plaintext a ihneď zahashuj.
      bool localOk = false;
      if (user != null) {
        final salt = user.passwordSalt;
        if (salt == null || salt.isEmpty) {
          // Starý plaintext záznam — overíme a migrujeme na hash.
          if (user.password == password) {
            localOk = true;
            // Migruj na hash.
            final newSalt = HashService.generateSalt();
            final newHash = HashService.hashPassword(password, newSalt);
            final migratedUser = User(
              id: user.id,
              username: user.username,
              password: newHash,
              passwordSalt: newSalt,
              fullName: user.fullName,
              role: user.role,
              email: user.email,
              phone: user.phone,
              department: user.department,
              avatarUrl: user.avatarUrl,
              joinDate: user.joinDate,
            );
            await _dbService.updateUser(migratedUser);
            user = migratedUser;
          }
        } else {
          localOk = HashService.verifyPassword(password, user.password, salt);
        }
      }

      if (!localOk) {
        // Lokálny účet neexistuje alebo heslo nesedí – skús prihlásenie cez backend (iný PC / webový účet)
        final backendResult = await fetchBackendToken(username, password, rememberMe: _rememberMe);
        if (!mounted) return;
        if (backendResult != null) {
          BackendLoginResult? resolvedBackendResult = backendResult;
          if (backendResult.requires2fa || backendResult.requires2faSetup) {
            resolvedBackendResult = await _resolve2faFlow(backendResult);
          }
          if (!mounted) return;
          if (resolvedBackendResult == null) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('2FA overenie zlyhalo alebo bolo zrušené.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          final fromBackend = userFromBackendProfile(username, password, resolvedBackendResult.userProfile);
          // Pri prihlásení cez backend vždy prepnúť na DB daného účtu, aby sa nezobrazovali
          // sklady/dáta z iného účtu na tomto zariadení. Ak backend nevráti userId, použije sa username.
          final backendUserId = backendResult.userId;
          final accountKey = (backendUserId != null && backendUserId.isNotEmpty)
              ? backendUserId
              : 'user_$username';
          final accountPath = await _dbService.getAccountDatabasePath(accountKey);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('db_path', accountPath);
          await _dbService.setCustomPath(accountPath);
          if (!mounted) return;
          user = await _dbService.getUserByUsername(username);
          if (user != null) {
            final updatedUser = User(
              id: user.id,
              username: fromBackend.username,
              password: fromBackend.password,
              passwordSalt: fromBackend.passwordSalt,
              fullName: fromBackend.fullName,
              role: fromBackend.role,
              email: fromBackend.email,
              phone: fromBackend.phone,
              department: fromBackend.department,
              avatarUrl: fromBackend.avatarUrl,
              joinDate: user.joinDate,
            );
            await _dbService.updateUser(updatedUser);
            user = updatedUser;
          } else {
            // Pri prvom vstupe do účtovej DB odstrániť sklady z predchádzajúceho zmiešania dát.
            await _dbService.clearAllWarehousesForNewAccount();
            await _dbService.insertUser(fromBackend);
            user = await _dbService.getUserByUsername(fromBackend.username);
          }
          if (!mounted) return;
          if (user == null) {
            setState(() => _isLoading = false);
            return;
          }
          await _finishLogin(
            user,
            backendUserId: resolvedBackendResult.userId,
            ownerFullName: resolvedBackendResult.ownerFullName,
            ownerUsername: resolvedBackendResult.ownerUsername,
          );
          return;
        }
        if (mounted) setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.loginError),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (_rememberMe) {
        await _dbService.setRememberMe(true);
        await _dbService.setSavedUsername(user!.username);
      } else {
        await _dbService.clearSavedLogin();
      }
      if (!mounted) return;

      final backendResult = await fetchBackendToken(username, password, rememberMe: _rememberMe);
      if (!mounted) return;

      BackendLoginResult? resolvedBackendResult = backendResult;
      if (backendResult != null && (backendResult.requires2fa || backendResult.requires2faSetup)) {
        resolvedBackendResult = await _resolve2faFlow(backendResult);
        if (!mounted) return;
        if (resolvedBackendResult == null) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('2FA overenie zlyhalo alebo bolo zrušené.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      await _finishLogin(
        user!,
        backendUserId: resolvedBackendResult?.userId,
        ownerFullName: resolvedBackendResult?.ownerFullName,
        ownerUsername: resolvedBackendResult?.ownerUsername,
      );
    }
  }

  Future<String?> _showCodeDialog({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zrušiť')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Potvrdiť'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<BackendLoginResult?> _resolve2faFlow(BackendLoginResult initial) async {
    if (initial.loginChallengeToken == null || initial.loginChallengeToken!.isEmpty) return null;
    var challenge = initial.loginChallengeToken!;

    if (initial.requires2faSetup) {
      final setupPayload = await setup2faWithChallenge(challenge);
      if (setupPayload == null) return null;
      final otpUri = setupPayload['otpauthUri']?.toString() ?? '';
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Nastavenie 2FA'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.network(
                  'https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${Uri.encodeComponent(otpUri)}',
                  width: 220,
                  height: 220,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                SelectableText('Naskenujte v autentifikátore:\n$otpUri'),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
      final setupCode = await _showCodeDialog(title: 'Prvý 2FA kód', hint: '123456');
      if (setupCode == null || setupCode.isEmpty) return null;
      final confirmed = await confirm2faSetup(
        loginChallengeToken: challenge,
        totpCode: setupCode,
      );
      if (confirmed == null) return null;
      return confirmed;
    }

    final code = await _showCodeDialog(title: '2FA overenie', hint: '123456 alebo XXXX-XXXX');
    if (code == null || code.isEmpty) return null;
    return verify2faLogin(
      loginChallengeToken: challenge,
      totpCode: code.contains('-') ? null : code,
      backupCode: code.contains('-') ? code : null,
    );
  }

  Future<void> _finishLogin(
    User user, {
    String? backendUserId,
    String? ownerFullName,
    String? ownerUsername,
  }) async {
    final userId = backendUserId ?? user.id?.toString() ?? user.username;
    UserSession.setUser(
      userId: userId,
      username: user.username,
      role: user.role,
      ownerFullName: ownerFullName,
      ownerUsername: ownerUsername,
    );

    final token = getBackendToken();
    if (token != null && token.isNotEmpty) {
      await SyncManager.instance.initialize(userId, token);
    }

    final ownerDisplay = ownerFullName?.isNotEmpty == true ? ownerFullName : ownerUsername;
    if (ownerDisplay != null && ownerDisplay.isNotEmpty) {
      SharedPreferences.getInstance().then((prefs) =>
          prefs.setString('current_user_owner_name', ownerDisplay));
    } else {
      SharedPreferences.getInstance().then((prefs) =>
          prefs.remove('current_user_owner_name'));
    }
    if (mounted) setState(() => _isLoading = false);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (context) => WelcomeRevealScreen(
          user: user,
          postHomeSnackText: l10n.loggedInAs(user.fullName),
          postHomeSnackColor:
              user.role == 'admin' ? Colors.redAccent : Colors.green,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) => _LoginBackground(
                glowOpacity: 0.12 + 0.08 * _glowController.value,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _entranceFade,
                child: ScaleTransition(
                  scale: _entranceScale,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 420),
                    decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1F),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.accentGold.withOpacity(0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGold.withOpacity(0.12),
                      blurRadius: 40,
                      spreadRadius: 0,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'STOCK',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accentGold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'PILOT',
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Stock management. Under control.',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 32),

                          _LoginLabel(text: 'Používateľské meno'),
                          const SizedBox(height: 8),
                          _LoginTextField(
                            controller: _loginController,
                            hint: 'Zadajte používateľské meno',
                            validator: (v) => v!.isEmpty ? l10n.loginRequired : null,
                          ),
                          const SizedBox(height: 20),

                          _LoginLabel(text: 'Heslo'),
                          const SizedBox(height: 8),
                          _LoginTextField(
                            controller: _passwordController,
                            hint: 'Zadajte heslo',
                            obscureText: _isObscured,
                            suffix: IconButton(
                              icon: Icon(
                                _isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _isObscured = !_isObscured),
                            ),
                            validator: (v) => v!.length < 4 ? l10n.passwordMinLength : null,
                          ),
                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
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
                                      side: BorderSide(color: AppColors.textSecondary.withOpacity(0.6)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Zapamätať si',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              _HoverLink(
                                label: 'zabudol som heslo',
                                onTap: () => showChangePasswordDialog(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          _LoginButton(
                            isLoading: _isLoading,
                            onPressed: _handleLogin,
                            onTapDown: () => setState(() => _buttonPressed = true),
                            onTapUp: () => setState(() => _buttonPressed = false),
                            onTapCancel: () => setState(() => _buttonPressed = false),
                            pressed: _buttonPressed,
                          ),
                          const SizedBox(height: 20),

                          _HoverLink(
                            label: 'Vytvoriť používateľa',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CreateUserScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),

                          Text(
                            'Stock Pilot © ${DateTime.now().year}',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: AppColors.textMuted,
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
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glowController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

/// Tlačidlo s animovaným stlačením (scale) a jemným tieňom
class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;
  final bool pressed;

  const _LoginButton({
    required this.isLoading,
    required this.onPressed,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
    required this.pressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapCancel,
      child: AnimatedScale(
        scale: pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppColors.accentGold,
            boxShadow: [
              BoxShadow(
                color: AppColors.accentGold.withOpacity(pressed ? 0.2 : 0.4),
                blurRadius: pressed ? 12 : 20,
                offset: Offset(0, pressed ? 2 : 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : onPressed,
              borderRadius: BorderRadius.circular(14),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0F0F12),
                        ),
                      )
                    : Text(
                        'Prihlásiť sa',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F0F12),
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

/// Odkaz s hover efektom (zlatá farba + podčiarknutie)
class _HoverLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _HoverLink({required this.label, required this.onTap});

  @override
  State<_HoverLink> createState() => _HoverLinkState();
}

class _HoverLinkState extends State<_HoverLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 180),
          style: GoogleFonts.dmSans(
            fontSize: _hovered ? 14 : 13,
            color: _hovered ? AppColors.accentGold : AppColors.textSecondary,
            decoration: _hovered ? TextDecoration.underline : TextDecoration.none,
            decorationColor: AppColors.accentGold,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class _LoginLabel extends StatelessWidget {
  final String text;

  const _LoginLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _LoginTextField({
    required this.controller,
    required this.hint,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: GoogleFonts.dmSans(
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(
          fontSize: 14,
          color: AppColors.textMuted,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF252830),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1),
        ),
      ),
    );
  }
}

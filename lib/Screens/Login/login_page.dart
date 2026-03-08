import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../home/home_screen.dart';
import '../../services/Database/database_service.dart';
import '../../services/user_session.dart';
import '../../services/api_sync_service.dart';
import '../../models/user.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/Common/change_password_dialog.dart';
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

      User? user = await _dbService.getUserByUsername(_loginController.text);
      if (!mounted) return;

      if (user == null || user.password != _passwordController.text) {
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
        await _dbService.setSavedUsername(user.username);
      } else {
        await _dbService.clearSavedLogin();
      }
      if (!mounted) return;

      final backendResult = await fetchBackendToken(
        _loginController.text,
        _passwordController.text,
        rememberMe: _rememberMe,
      );
      if (!mounted) return;

      final userId = backendResult?.userId ?? user.id?.toString() ?? user.username;
      UserSession.setUser(
        userId: userId,
        username: user.username,
        role: user.role,
      );

      if (mounted) setState(() => _isLoading = false);
      if (!mounted) return;
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
    }
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

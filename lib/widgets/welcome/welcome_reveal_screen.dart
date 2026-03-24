import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user.dart';
import '../../screens/Home/Home_screen.dart';
import '../../theme/app_theme.dart';

/// Krátky privítací moment po prihlásení – animácia pred zobrazením hlavnej obrazovky.
class WelcomeRevealScreen extends StatefulWidget {
  final User user;
  final RouteObserver<ModalRoute<void>>? routeObserver;
  final String? postHomeSnackText;
  final Color? postHomeSnackColor;

  const WelcomeRevealScreen({
    super.key,
    required this.user,
    this.routeObserver,
    this.postHomeSnackText,
    this.postHomeSnackColor,
  });

  @override
  State<WelcomeRevealScreen> createState() => _WelcomeRevealScreenState();
}

class _WelcomeRevealScreenState extends State<WelcomeRevealScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowPulse;
  late Animation<double> _titleOpacity;
  late Animation<double> _titleScale;
  late Animation<double> _nameOpacity;
  late Animation<Offset> _nameSlide;

  static const _holdMs = 2200;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _holdMs + 400),
    );

    _glowPulse = Tween<double>(begin: 0.14, end: 0.26).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.85, curve: Curves.easeInOut),
      ),
    );

    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.28, curve: Curves.easeOut),
    );
    _titleScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.32, curve: Curves.easeOutCubic),
      ),
    );
    _nameOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.42, curve: Curves.easeOut),
    );
    _nameSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.12, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward().then((_) {
      if (mounted) _goHome();
    });
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(
          user: widget.user,
          routeObserver: widget.routeObserver,
          initialSnackBarText: widget.postHomeSnackText,
          initialSnackBarColor: widget.postHomeSnackColor,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 420),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.fullName.trim().isEmpty
        ? widget.user.username
        : widget.user.fullName;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final g = _glowPulse.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _WelcomeGridPainter(),
              ),
              Positioned(
                top: -MediaQuery.of(context).size.height * 0.28,
                left: MediaQuery.of(context).size.width * 0.5 - 220,
                child: Container(
                  width: 440,
                  height: 440,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accentGold.withOpacity(g * 1.35),
                        AppColors.accentGold.withOpacity(g * 0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _titleOpacity,
                      child: ScaleTransition(
                        scale: _titleScale,
                        child: Text(
                          'Vitajte',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _nameOpacity,
                      child: SlideTransition(
                        position: _nameSlide,
                        child: Text(
                          name,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: AppColors.accentGold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: 140,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _controller.value.clamp(0.0, 1.0),
                          backgroundColor: AppColors.borderSubtle,
                          color: AppColors.accentGold.withOpacity(0.9),
                          minHeight: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WelcomeGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF252530).withOpacity(0.45)
      ..strokeWidth = 0.5;
    const step = 28.0;
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/logout_service.dart';
import '../../theme/app_theme.dart';

/// Krátka rozlúčka pred návratom na prihlásenie (manuálne alebo auto-odhlásenie).
class LogoutFarewellScreen extends StatefulWidget {
  final bool idleTimeout;
  final String displayName;

  const LogoutFarewellScreen({
    super.key,
    required this.idleTimeout,
    required this.displayName,
  });

  @override
  State<LogoutFarewellScreen> createState() => _LogoutFarewellScreenState();
}

class _LogoutFarewellScreenState extends State<LogoutFarewellScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowPulse;
  late Animation<double> _titleOpacity;
  late Animation<double> _titleScale;
  late Animation<double> _subtitleOpacity;

  static const _holdMs = 2200;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _holdMs + 400),
    );

    _glowPulse = Tween<double>(begin: 0.12, end: 0.22).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.85, curve: Curves.easeInOut),
      ),
    );

    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
    );
    _titleScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.34, curve: Curves.easeOutCubic),
      ),
    );
    _subtitleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.10, 0.40, curve: Curves.easeOut),
    );

    _controller.forward().then((_) {
      if (mounted) {
        LogoutService.finalizeLogout(context);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = widget.idleTimeout
        ? 'Automatické odhlásenie z dôvodu nečinnosti'
        : 'Ďakujeme za prácu';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final g = _glowPulse.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _LogoutGridPainter()),
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
                        AppColors.danger.withOpacity(g * 0.45),
                        AppColors.danger.withOpacity(g * 0.15),
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
                          'Dovidenia',
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
                      opacity: _subtitleOpacity,
                      child: Text(
                        widget.displayName.isNotEmpty ? widget.displayName : ' ',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _subtitleOpacity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textMuted,
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
                          color: AppColors.danger.withOpacity(0.85),
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

class _LogoutGridPainter extends CustomPainter {
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
